import 'package:flutter/material.dart';

import '../core/di/service_locator.dart';
import '../data/app_preferences.dart';
import '../data/user_database.dart';
import '../data/wordbook_database.dart';
import '../player/audio_players.dart';

/// 初始化应用运行所需的基础设施。
///
/// 这里是应用的组合根之一：只负责平台初始化、持久化基础设施、
/// 音频会话和依赖注册，不承载任何页面或业务流程逻辑。
Future<void> bootstrapApp() async {
  WidgetsFlutterBinding.ensureInitialized();
  _configureGlobalErrorHandling();

  await WordBookDatabase.ensurePlatform();
  await WordBookDatabase.instance.initialize();
  await UserDatabase.instance.initialize();
  await AppPreferences().init();
  await initMobileAudioSession();
  await setupServiceLocator();
}

void _configureGlobalErrorHandling() {
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
