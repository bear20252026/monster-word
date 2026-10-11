import 'dart:async';

import 'package:word_app/core/utils/monster_voice.dart';
import 'package:word_app/core/utils/sfx_settings.dart';
import 'package:word_app/core/utils/debug_log.dart';
import 'package:word_app/core/utils/swallowed_error_report.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

import 'package:word_app/app/app_error_widget.dart';
import 'package:word_app/app/service_locator.dart';
import 'package:word_app/core/infrastructure/app_preferences.dart';
import 'package:word_app/core/application/today_progress_store.dart';
import 'package:word_app/core/infrastructure/user_data_backup_service.dart';
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
    debugLog('[Bootstrap] 桌面音频后端初始化失败（降级为无声）: $e');
  }

  // 初始化步骤清单 — 每步完成后回调进度。
  // 体验审计 C1：两个本地 DB 初始化无相互依赖，并行执行（离线词库无需串行等待）
  // MW-07（第六阶段审计）：阶段分级——S1 双库并行（阻塞，首屏数据依赖）→
  // S2 偏好（阻塞，首帧回退防护）→ S3 依赖注册（阻塞）。音频会话初始化移出
  // 阻塞链（S4 异步尽力而为，失败仅上报）；数据备份为 S5 后台任务不阻塞。
  final steps = <Future<void> Function()>[
    () async {
      await WordBookDatabase.ensurePlatform();
      await Future.wait([WordBookDatabase.instance.initialize(), UserDatabase.instance.initialize()]);
    },
    () async {
      // 两套偏好必须在 Provider/页面创建前就绪，防止每日目标首帧回退到默认 10。
      await AppPreferences().init();
      await UserPreferences().init();
      await TodayProgressStore.initializePersistentState();
    },
    () => setupServiceLocator(),
  ];
  final labels = const ['词书与用户数据库（并行）', '偏好设置', '依赖注册'];

  // 蓝图 W3：音效静音/怪兽语音偏好预加载（Sfx 门面读缓存）。
  // 非关键偏好：读失败降级为默认值即可，不能把整个应用送进 bootstrap 兜底页。
  try {
    await SfxSettings.load();
    await MonsterVoiceSettings.load();
  } catch (e, s) {
    reportSwallowedError('音效/语音偏好加载失败，按默认值继续', e, s);
  }
  final total = steps.length;
  for (var i = 0; i < total; i++) {
    await steps[i]();
    debugLog('[Bootstrap] 初始化进度 ${i + 1}/$total: ${labels[i]}');
    onProgress?.call(i + 1, total, labels[i]);
  }

  // MW-07：非关键初始化移出阻塞链——移动端音频会话（iOS AVAudioSession 配置）
  // 异步执行，失败降级为手机端发音不可用，绝不让它拖住首屏。
  unawaited(
    initMobileAudioSession().catchError((Object e, StackTrace s) {
      reportSwallowedError('移动端音频会话初始化失败（降级继续）', e, s);
    }),
  );

  // MW-06：启动后异步触发用户库/复习库一致性备份（24h 节流、不阻塞、
  // 内部吞掉一切异常）。DB 已就绪，VACUUM INTO 在只读连接上执行。
  unawaited(UserDataBackupService.runStartupBackup());
}

void _configureGlobalErrorHandling() {
  // 2026-10-04 审计（10-03 P2-8 落地）：SentryFlutter.init 的 FlutterErrorIntegration /
  // OnErrorIntegration 会捕获事件后回调先前 handler——若这里再 reportSwallowedError，
  // 同一错误在 Sentry 里变成 message 事件 + exception 事件两个 issue（build 错误三个）。
  // 故 Sentry 启用期间三个 handler 只留 debugLog 本地观测，遥测交给 Sentry 自身集成；
  // Sentry 未启用时 reportSwallowedError 本就 no-op，无需补报。
  ErrorWidget.builder = (details) {
    debugLog('[GlobalError] Widget build error: ${details.exception}');
    if (!Sentry.isEnabled) {
      reportSwallowedError('全局构建异常', details.exception, details.stack ?? StackTrace.current);
    }
    return AppBuildErrorPage(exception: details.exception);
  };

  FlutterError.onError = (details) {
    debugLog('[GlobalError] FlutterError: ${details.exception}');
    if (details.stack != null) {
      debugLog('[GlobalError] Stack:\n${details.stack}');
    }
    if (!Sentry.isEnabled) {
      reportSwallowedError('全局 Flutter 异常', details.exception, details.stack ?? StackTrace.current);
    }
    FlutterError.presentError(details);
  };

  WidgetsBinding.instance.platformDispatcher.onError = (error, stack) {
    debugLog('[GlobalError] Uncaught: $error');
    debugLog('[GlobalError] Stack:\n$stack');
    if (!Sentry.isEnabled) {
      reportSwallowedError('全局未捕获异常', error, stack);
    }
    return true;
  };
}
