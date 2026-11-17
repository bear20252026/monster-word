// 由 Claude 团队生成 | Monster Word App

// 吞错上报工具（审计跟进批次 C / REG-OBS-001）
//
// 背景：全库曾有 56 处 `catch (_)` 空捕获，数据路径的异常对 Sentry 完全不可见
//（典型：收藏加载失败后用户收藏静默"消失"）。分级治理规则：
//   A 级（用户数据丢失 / 持久化失败）：catch (e, s) 后必须调用 reportSwallowedError；
//   B 级（词条数据解析降级）：保留降级返回，补注释说明（量大不上报，防刷屏）；
//   C 级（合理降级 / 控制流 / 已有用户反馈）：注释豁免即可。
// 守卫：test/architecture/swallowed_error_guard_test.dart 锁定 A 级文件必须调用本函数。
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// 审计 R3（2026-11-16）：异常描述脱敏——FormatException.toString 会携带
/// source（jsonDecode 失败时=用户笔记/例句/学习记录/会话原文），直接字符串化
/// 上报与隐私声明「崩溃诊断不包含学习内容」冲突。此收口覆盖全部 A 级上报路径
/// （note/fav_sentence/sp_codec/migration 等），不必逐点修。
///
/// 第三轮 T16：网络异常（SocketException/HttpException/ClientException 等）的
/// toString 含完整 URL——有道发音/词典 URL 带单词查询参，用户学习词随崩溃事件
/// 离开本机。统一剥离 URL（保留异常类型与主机无关的描述骨架）。
String sanitizeErrorForReport(Object error) {
  if (error is FormatException) {
    return 'FormatException(${error.message})［source 已脱敏］';
  }
  var text = '$error';
  // URL 整体替换为占位（含 scheme://host/path?query；查询词在 path/query 里）。
  // 匹配到空白或常见分隔符为止，覆盖 SocketException/HttpException 的 message 形态。
  text = text.replaceAll(RegExp(r'''https?://[^\s,;)\]}>'"]+'''), '［URL 已脱敏］');
  return text;
}

/// 上报被吞掉的异常：debug 下 debugPrint 输出；Sentry 已初始化时附带上下文上报。
///
/// [context] 描述"什么操作失败了"，与错误一起组成事件 message 便于 Sentry 分组。
void reportSwallowedError(String context, Object error, StackTrace stack) {
  // 隐私审计：debugPrint 在 release 仍写平台日志（Android logcat 可读），
  // 错误原文可能携带用户数据（如解析失败的用户信息 JSON 含手机号）。
  // release 的可见性交给 Sentry（sendDefaultPii=false 已裁剪），本地不再落日志。
  final safe = sanitizeErrorForReport(error);
  if (kDebugMode) {
    debugPrint('[SwallowedError] $context: $safe');
  }
  if (!Sentry.isEnabled) return;
  unawaited(Sentry.captureEvent(SentryEvent(message: SentryMessage('$context: $safe')), stackTrace: stack));
}
