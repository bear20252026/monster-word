import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../../core/di/service_locator.dart';
import '../../../services/audio_service.dart';
import 'audio_playback_state.dart';

/// 播放器功能域的根 Provider 装配。
///
/// 音频设备服务仍是应用级共享资源，但其展示状态和页面命令只在播放器功能域内暴露。
Widget buildPlayerFeatureScope({required Widget child}) {
  return MultiProvider(
    providers: [
      Provider<AudioService>.value(value: sl<AudioService>()),
      ChangeNotifierProvider(create: (context) => AudioPlaybackState(audioService: context.read<AudioService>())),
    ],
    child: child,
  );
}
