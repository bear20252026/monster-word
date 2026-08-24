// 由 Claude 团队生成 | Monster Word App

// 翻译自 util/NetworkUtils.dart
// 网络工具

import 'dart:io';

/// 网络工具（翻译自 NetworkUtils.dart）
class NetworkUtils {
  /// 检查是否有网络连接
  static Future<bool> isConnected() async {
    try {
      final result = await InternetAddress.lookup('baidu.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// 检查是否有网络连接（带超时）
  static Future<bool> isConnectedWithTimeout({Duration timeout = const Duration(seconds: 5)}) async {
    try {
      final result = await InternetAddress.lookup('baidu.com').timeout(timeout);
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }
}
