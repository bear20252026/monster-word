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
        final file = File(localPath);
        await file.writeAsBytes(response.bodyBytes);
        return _DownloadResult(file: file, success: true, statusCode: 200);
      }
      return _DownloadResult(statusCode: response.statusCode);
    } catch (e, s) {
      // 错误处理审计 P3：此前连 debugPrint 都没有，网络层故障完全不可观测
      reportSwallowedError('音频下载失败（主备 URL 均失败）', e, s);
      return _DownloadResult(statusCode: -1);
    }
  }
}
