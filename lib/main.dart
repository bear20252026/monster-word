import 'package:word_app/core/utils/debug_log.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'package:word_app/app/app.dart';
import 'package:word_app/app/app_bootstrap.dart';
import 'package:word_app/core/infrastructure/sentry_bootstrap.dart';
import 'package:word_app/tokens/design_tokens.dart';

Future<void> main() async {
  // Zone 契约：runZonedGuarded 必须包住 bootstrapApp + runApp 的全部流程。
  // WidgetsFlutterBinding.ensureInitialized()（bootstrapApp 内）与 runApp 一旦
  // 落在不同 zone，Flutter 每次冷启动都会打 Zone mismatch 告警。
  // 守卫：test/regression/regression_zone001_boot_zone_test.dart。
  runZonedGuarded(() => unawaited(_bootstrapAndRun()), (error, stack) {
    debugLog('[runZonedGuarded] 未捕获异常: $error');
    debugLog('$stack');
    // 转发到 Sentry（未启用时为 no-op）
    Sentry.captureException(error, stackTrace: stack);
  });
}

Future<void> _bootstrapAndRun() async {
  // 审计 I89：启动耗时打点——Sentry 在 bootstrap 之后才初始化，
  // 此处只采集，待 runAppWithSentry 完成后补记 breadcrumb（先加会被丢弃）。
  final sw = Stopwatch()..start();
  final stepTimings = <String>[];
  try {
    await bootstrapApp(
      onProgress: (step, total, label) {
        stepTimings.add('$label:${sw.elapsedMilliseconds}ms');
      },
    );
  } catch (error, stack) {
    // 审计 I104：bootstrap 阶段失败（数据库/路径/偏好初始化等）此前会让
    // runApp 永不执行——用户面对无窗口/白屏死应用。改为渲染最小兜底页提供
    // 「重试」入口。Sentry 未初始化时 captureException 为 no-op；此场景下
    // 兜底页的可见性与可恢复性是第一目标，遥测为尽力而为。
    debugLog('[Bootstrap] 启动失败(${sw.elapsedMilliseconds}ms): $error');
    await Sentry.captureException(error, stackTrace: stack);
    runApp(_BootstrapRecoveryApp(error: error));
    return;
  }
  // A-2: 异步异常不再无兜底崩溃；Sentry 接管后未捕获异常同时上报后台（DSN 走 --dart-define）。
  await runAppWithSentry(() {
    runApp(const WordApp()); // 字面必须含这一行，app_structure_test 靠它
  });
  final totalMs = sw.elapsedMilliseconds;
  unawaited(
    Sentry.addBreadcrumb(
      Breadcrumb(
        message: '冷启动 bootstrap 完成：${totalMs}ms',
        category: 'boot',
        data: {'totalMs': totalMs, 'steps': stepTimings.join(' | ')},
      ),
    ),
  );
}

/// bootstrap 失败的兜底根：重试成功后原地切换为正式应用
/// （同一根内 setState 替换，规避二次 runApp 的语义歧义）。
class _BootstrapRecoveryApp extends StatefulWidget {
  const _BootstrapRecoveryApp({required this.error});

  final Object error;

  @override
  State<_BootstrapRecoveryApp> createState() => _BootstrapRecoveryAppState();
}

class _BootstrapRecoveryAppState extends State<_BootstrapRecoveryApp> {
  bool _retrying = false;
  Object? _retryError;
  bool _recovered = false;

  Future<void> _retry() async {
    setState(() {
      _retrying = true;
      _retryError = null;
    });
    try {
      // bootstrapApp 各步骤幂等（DB completer 守卫 / SL isRegistered 检查），
      // 失败现场可直接重跑。
      await bootstrapApp();
      if (!mounted) return;
      setState(() => _recovered = true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _retrying = false;
        _retryError = e;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_recovered) return const WordApp();
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFFFBF7F0),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 56, color: Color(0xFFB08968)),
                const SizedBox(height: 16),
                const Text(
                  'Monster Word 启动失败',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF3E2D22)),
                ),
                const SizedBox(height: 8),
                Text(
                  '初始化遇到问题${_retryError == null ? '' : '，重试仍失败'}：\n'
                  '${_retryError ?? widget.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, color: Color(0xFF6B5B4D)),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _retrying ? null : _retry,
                  icon: _retrying
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.white100),
                        )
                      : const Icon(Icons.refresh, size: 18),
                  label: Text(_retrying ? '正在重试…' : '重试启动'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
