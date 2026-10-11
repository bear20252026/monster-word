part of 'audio_players.dart';

// 音频下载（主/备双源）
// ============================================================
// 公共下载工具（DownloadHttpClient 的简化替代）
// ============================================================

/// 下载结果（公开给测试断言；字段只读）。
class DownloadResult {
  final File? file;
  final bool success;
  final int statusCode;

  DownloadResult({this.file, this.success = false, this.statusCode = 0});
}

/// 简化的下载客户端（替代 DownloadHttpClient）
///
/// MW-49/50/52：
/// - **流式下载**：改 `http.get`（整包进内存）为 `Client.send` + 逐块落盘，
///   边收边累计大小——恶意/异常服务器返回超大响应时在超限那一刻中断，
///   不再先把整包读进内存再判断（原实现的内存上限形同虚设）。
/// - **magic bytes 校验**：落盘后校验文件头，CDN 返回 HTML 错误页 / 半截
///   内容时判为损坏并丢弃，避免坏文件永久占据缓存位（此后每次都命中坏缓存）。
/// - **原子改名**：仍先写 `.tmp` 再改名，下载中断不会留下半写文件。
class AudioDownloader {
  static const int _connectTimeout = 5;
  static const int _readTimeout = 10;

  /// 安全审计 S4：下载内容上限 10MB（音频文件实际 <1MB）。
  static const int maxBytes = 10 * 1024 * 1024;

  /// 测试注入缝（REG-AUDIT-005 守护）：替代 http.get，可注入失败/慢响应。
  /// 非 null 时 [_tryDownload] 直走替身（整包 Response 语义）；生产恒为 null。
  static Future<http.Response> Function(Uri url)? fetchOverride;

  /// 下载文件到本地路径，支持主/备 URL 切换
  static Future<DownloadResult> downloadFile(String localPath, String primaryUrl, {String? fallbackUrl}) async {
    // 确保目录存在
    final dir = Directory(p.dirname(localPath));
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }

    // 尝试主 URL
    var result = await _tryDownload(localPath, primaryUrl);
    if (result.success) return result;

    // 主 URL 失败且有备选 URL 时重试
    if (fallbackUrl != null && result.statusCode != 10005) {
      result = await _tryDownload(localPath, fallbackUrl);
    }
    return result;
  }

  static Future<DownloadResult> _tryDownload(String localPath, String url) async {
    final fetch = fetchOverride;
    // 注入替身走整包语义（测试可注入失败/慢响应/超限包），生产走流式。
    if (fetch != null) return _tryDownloadWholeBody(localPath, url, fetch);
    return _tryDownloadStreamed(localPath, url);
  }

  /// 流式下载：逐块写盘，超限即时中断。
  static Future<DownloadResult> _tryDownloadStreamed(String localPath, String url) async {
    final client = http.Client();
    final tmp = File('$localPath.tmp');
    IOSink? sink;
    try {
      final response = await client
          .send(http.Request('GET', Uri.parse(url)))
          .timeout(const Duration(seconds: _connectTimeout));
      if (response.statusCode != 200) {
        return DownloadResult(statusCode: response.statusCode);
      }
      // 声明长度即超限：直接拒绝，不落盘
      final declared = response.contentLength;
      if (declared != null && declared > maxBytes) {
        return DownloadResult(statusCode: 413);
      }

      // 用不可空局部量持有 sink：sink 本身需在循环内被置空（供 catch 判断是否已关闭），
      // 而循环内对 sink 的赋值会让类型提升失效，故读写走 out、清理走 sink。
      final out = tmp.openWrite();
      sink = out;
      var received = 0;
      await for (final chunk in response.stream.timeout(const Duration(seconds: _readTimeout))) {
        received += chunk.length;
        if (received > maxBytes) {
          await out.close();
          sink = null;
          _deleteQuietly(tmp);
          return DownloadResult(statusCode: 413);
        }
        out.add(chunk);
      }
      await out.flush();
      await out.close();
      sink = null;

      if (!await _hasAudioMagic(tmp)) {
        _deleteQuietly(tmp);
        return DownloadResult(statusCode: 415);
      }
      return DownloadResult(file: await _promote(tmp, localPath), success: true, statusCode: 200);
    } catch (e, s) {
      // 错误处理审计 P3：网络层故障不可观测。此处为单次尝试（主或备），
      // 「主备均失败」的汇总上报由 downloadFile 调用方口径负责。
      reportSwallowedError('音频下载尝试失败（主/备单次·流式）', e, s);
      try {
        await sink?.close();
      } catch (_) {
        // 关闭失败可忽略：临时文件即将删除
      }
      _deleteQuietly(tmp);
      return DownloadResult(statusCode: -1);
    } finally {
      client.close();
    }
  }

  /// 整包下载（测试注入缝路径，语义与迁移前一致，额外补 magic bytes 校验）。
  static Future<DownloadResult> _tryDownloadWholeBody(
    String localPath,
    String url,
    Future<http.Response> Function(Uri url) fetch,
  ) async {
    final tmp = File('$localPath.tmp');
    try {
      final response = await fetch(Uri.parse(url)).timeout(const Duration(seconds: _connectTimeout + _readTimeout));
      if (response.statusCode == 200) {
        if (response.bodyBytes.length > maxBytes) {
          return DownloadResult(statusCode: 413);
        }
        await tmp.writeAsBytes(response.bodyBytes, flush: true);
        if (!await _hasAudioMagic(tmp)) {
          _deleteQuietly(tmp);
          return DownloadResult(statusCode: 415);
        }
        return DownloadResult(file: await _promote(tmp, localPath), success: true, statusCode: 200);
      }
      return DownloadResult(statusCode: response.statusCode);
    } catch (e, s) {
      reportSwallowedError('音频下载尝试失败（主/备单次）', e, s);
      _deleteQuietly(tmp);
      return DownloadResult(statusCode: -1);
    }
  }

  /// tmp → 目标路径的原子改名。
  ///
  /// 数据完整性：先写 tmp 再原子改名。直写最终路径时下载中断会留下半写 mp3
  /// 永久占位，此后该词每次都命中坏缓存并静默播不出。
  static Future<File> _promote(File tmp, String localPath) async {
    final file = File(localPath);
    try {
      await tmp.rename(file.path);
    } catch (_) {
      // C 级豁免：个别平台 rename 覆盖已存在文件受限，回退删除后重命名
      if (file.existsSync()) file.deleteSync();
      await tmp.rename(file.path);
    }
    return file;
  }

  /// MW-50：音频文件头校验（magic bytes）。
  ///
  /// 覆盖实际会遇到的容器：MP3（ID3v2 标签 / MPEG 帧同步）、WAV（RIFF）、
  /// Ogg、FLAC。CDN 在文件缺失时常见返回 HTML 错误页（200 + `<!DOCTYPE`），
  /// 若不校验就会被当作音频缓存下来并永久命中。
  static Future<bool> _hasAudioMagic(File file) async {
    RandomAccessFile? raf;
    try {
      if (await file.length() < 4) return false;
      raf = await file.open();
      final head = await raf.read(4);
      if (head.length < 4) return false;
      const id3 = [0x49, 0x44, 0x33]; // 'ID3'
      if (head[0] == id3[0] && head[1] == id3[1] && head[2] == id3[2]) return true;
      // MPEG 音频帧同步：11 个连续 1 位
      if (head[0] == 0xFF && (head[1] & 0xE0) == 0xE0) return true;
      if (head[0] == 0x52 && head[1] == 0x49 && head[2] == 0x46 && head[3] == 0x46) return true; // 'RIFF'
      if (head[0] == 0x4F && head[1] == 0x67 && head[2] == 0x67 && head[3] == 0x53) return true; // 'OggS'
      if (head[0] == 0x66 && head[1] == 0x4C && head[2] == 0x61 && head[3] == 0x43) return true; // 'fLaC'
      return false;
    } catch (e, s) {
      reportSwallowedError('音频文件头校验失败（按损坏处理）', e, s);
      return false;
    } finally {
      try {
        await raf?.close();
      } catch (_) {
        // 关闭失败可忽略：句柄即将被丢弃
      }
    }
  }

  static void _deleteQuietly(File file) {
    try {
      if (file.existsSync()) file.deleteSync();
    } catch (_) {
      // 删除失败可忽略：下次下载会覆盖，LRU 也会回收
    }
  }
}
