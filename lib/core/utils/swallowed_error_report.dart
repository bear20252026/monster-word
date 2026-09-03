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

/// 上报被吞掉的异常：debugPrint 始终输出；Sentry 已初始化时附带上下文上报。
///
/// [context] 描述"什么操作失败了"，与错误一起组成事件 message 便于 Sentry 分组。
void reportSwallowedError(String context, Object error, StackTrace stack) {
  debugPrint('[SwallowedError] $context: $error');
  if (!Sentry.isEnabled) return;
  unawaited(Sentry.captureEvent(SentryEvent(message: SentryMessage('$context: $error')), stackTrace: stack));
}
