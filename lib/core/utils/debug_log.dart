// P1-C（审计 I51）：调试日志统一出口。
//
// debugPrint 在 release 构建仍会输出到平台日志（它只是节流版 print，
// 不受 kDebugMode 门控），且无任何远程观测——调试日志一律走本出口：
// kDebugMode 门控，release 零输出。
// 错误路径不要用本函数：用 reportSwallowedError（分级上报 + Sentry）。
import 'package:flutter/foundation.dart';

void debugLog(String message) {
  if (kDebugMode) {
    debugPrint(message);
  }
}
