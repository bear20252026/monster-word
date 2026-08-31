// lib/core/infrastructure/sentry_bootstrap.dart
// Sentry 崩溃上报引导 — 商业级线上监控
//
// DSN 通过编译参数注入，不写死在代码里：
//   flutter build windows --dart-define=SENTRY_DSN=https://xxx.ingest.de.sentry.io/xxx
// 未提供 DSN（本地开发/测试）时完全静默跳过，零依赖零网络请求。
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// 编译参数里的 DSN（build 时 --dart-define=SENTRY_DSN=... 传入）。
const String _kSentryDsn = String.fromEnvironment('SENTRY_DSN');

/// 是否启用了 Sentry（DSN 非空）。
bool get sentryEnabled => _kSentryDsn.isNotEmpty;

/// 用 Sentry 包裹 app 启动。
///
/// [appRunner] 必须同步调用 runApp（Sentry 要求在其中初始化错误捕获）。
/// DSN 未配置时直接执行 [appRunner]，行为与接入前完全一致。
Future<void> runAppWithSentry(FutureOr<void> Function() appRunner) async {
  if (!sentryEnabled) {
    await appRunner();
    return;
  }
  await SentryFlutter.init((options) {
    options.dsn = _kSentryDsn;
    options.tracesSampleRate = 0.2; // 性能追踪采样 20%（免费档省额度）
    options.environment = kReleaseMode ? 'production' : 'development';
    options.sendDefaultPii = false; // 不上报个人信息（隐私底线）
    options.attachScreenshot = false; // 崩溃截图可能含学习数据，默认关
    options.release = 'monster-word@1.0.0';
  }, appRunner: appRunner);
}
