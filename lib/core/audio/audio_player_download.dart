part of 'audio_players.dart';

// 音频下载（主/备双源）
// ============================================================
// 公共下载工具（DownloadHttpClient 的简化替代）
// ============================================================

/// 下载结果
class _DownloadResult {
  final File? file;
  final bool success;
  final int statusCode;

  _DownloadResult({this.file, this.success = false, this.statusCode = 0});
}

/// 简化的下载客户端（替代 DownloadHttpClient）
class _AudioDownloader {
  static const int _connectTimeout = 5;
  static const int _readTimeout = 10;

  /// 下载文件到本地路径，支持主/备 URL 切换
  static Future<_DownloadResult> downloadFile(String localPath, String primaryUrl, {String? fallbackUrl}) async {
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

  static Future<_DownloadResult> _tryDownload(String localPath, String url) async {
    try {
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: _connectTimeout + _readTimeout));
      if (response.statusCode == 200) {
        // 安全审计 S4：下载内容上限 10MB（音频文件实际 <1MB），防恶意服务器撑爆磁盘/内存
        if (response.bodyBytes.length > 10 * 1024 * 1024) {
          return _DownloadResult(statusCode: 413);
        }
        // 数据完整性：先写 tmp 再原子改名。直写最终路径时下载中断会留下
        // 半写 mp3 永久占位，此后该词每次都命中坏缓存并静默播不出。
        final tmp = File('$localPath.tmp');
        await tmp.writeAsBytes(response.bodyBytes, flush: true);
        final file = File(localPath);
        try {
          await tmp.rename(file.path);
        } catch (_) {
          // C 级豁免：个别平台 rename 覆盖已存在文件受限，回退删除后重命名
          if (file.existsSync()) file.deleteSync();
          await tmp.rename(file.path);
        }
        return _DownloadResult(file: file, success: true, statusCode: 200);
      }
      return _DownloadResult(statusCode: response.statusCode);
    } catch (e, s) {
      // 错误处理审计 P3：网络层故障不可观测。此处为单次尝试（主或备），
      // 「主备均失败」的汇总上报由 downloadFile 调用方口径负责。
      reportSwallowedError('音频下载尝试失败（主/备单次）', e, s);
      return _DownloadResult(statusCode: -1);
    }
  }
}
