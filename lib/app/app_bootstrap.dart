import 'package:flutter/material.dart';

import 'dart:async';

import 'package:flutter/widgets.dart';

import 'package:word_app/app/app_error_widget.dart';
import 'package:word_app/core/di/service_locator.dart';
import 'package:word_app/core/infrastructure/app_preferences.dart';
import 'package:word_app/core/infrastructure/user_database.dart';
import 'package:word_app/core/infrastructure/wordbook_database.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'package:word_app/core/audio/audio_players.dart';

/// A-3: 冷启动进度回调 — 各初始化阶段完成后回调，用于上报/日志/未来接 UI 进度条。
///
/// 参数为 [当前步骤, 总步骤, 步骤名称]。调用方不可修改 SplashPage 内部，
/// 但可通过此回调对接骨架屏或上报初始化耗时。
typedef BootProgressCallback = void Function(int step, int total, String label);

/// 初始化应用运行所需的基础设施。
///
/// 这里是应用的组合根之一：只负责平台初始化、持久化基础设施、
/// 音频会话和依赖注册，不承载任何页面或业务流程逻辑。
///
/// [onProgress] 可选：冷启动各阶段进度回调，用于日志/监控/未来骨架屏。
/// 注意：bootstrapApp 在 runApp 之前执行，此阶段无 Flutter UI，
/// 品牌骨架由 A-1 的 SplashPage（home）在 runApp 后展示。
Future<void> bootstrapApp({BootProgressCallback? onProgress}) async {
  WidgetsFlutterBinding.ensureInitialized();
  _configureGlobalErrorHandling();
  // 桌面端 just_audio 后端（media_kit/mpv）：Windows/Linux 上 just_audio
  // 无原生实现，缺此行发音完全无声（手机端不受影响）。iOS/Android/macOS/Web 自动跳过。
  // 必须容错：mpv 组件加载失败（缺 VC++ 运行库/DLL 缺失）绝不能拖垮 app 启动，
  // 降级为电脑端无声，其余功能照常。
  try {
    JustAudioMediaKit.ensureInitialized();
  } catch (e) {
    debugPrint('[Bootstrap] 桌面音频后端初始化失败（降级为无声）: $e');
  }

  // 初始化步骤清单 — 每步完成后回调进度。
  final steps = <Future<void> Function()>[
    () => WordBookDatabase.ensurePlatform(),
    () => WordBookDatabase.instance.initialize(),
    () => UserDatabase.instance.initialize(),
    () => AppPreferences().init(),
    () => initMobileAudioSession(),
    () => setupServiceLocator(),
  ];
  final labels = const [
    '词书数据库平台',
    '词书数据库',
    '用户数据库',
    '偏好设置',
    '音频会话',
    '依赖注册',
  ];

  final total = steps.length;
  for (var i = 0; i < total; i++) {
    await steps[i]();
    // ignore: avoid_print
    print('[Bootstrap] 初始化进度 ${i + 1}/$total: ${labels[i]}');
    onProgress?.call(i + 1, total, labels[i]);
  }
}

/// A-2: 用 runZonedGuarded 包裹 runApp — 异步异常不再无兜底崩溃，统一上报/友好兜底。
///
/// 顶层异步异常（Future 错误、Timer 回调等）会被此 zone 捕获，避免直接闪退；
/// 生产环境可将 onZoneError 替换为 Crashlytics/Sentry 上报。
void runAppGuarded(Widget app) {
  runZonedGuarded(
    () => runApp(app),
    (error, stack) {
      debugPrint('[runZonedGuarded] 未捕获异常: $error');
      debugPrint('$stack');
    },
  );
}

void _configureGlobalErrorHandling() {
  ErrorWidget.builder = (details) {
    debugPrint('[GlobalError] Widget build error: ${details.exception}');
    return AppBuildErrorPage(exception: details.exception);
  };

  FlutterError.onError = (details) {
    debugPrint('[GlobalError] FlutterError: ${details.exception}');
    if (details.stack != null) {
      debugPrint('[GlobalError] Stack:\n${details.stack}');
    }
    FlutterError.presentError(details);
  };

  WidgetsBinding.instance.platformDispatcher.onError = (error, stack) {
    debugPrint('[GlobalError] Uncaught: $error');
    debugPrint('[GlobalError] Stack:\n$stack');
    return true;
  };
}
