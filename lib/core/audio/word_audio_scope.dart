import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../di/service_locator.dart';
import 'audio_playback_state.dart';
import 'audio_service.dart';

/// 应用级「单词音频播放」能力的共享装配。
///
/// 音频设备服务与播放状态是**跨功能共享基础设施**，在此一次性注入到所有功能域之上
/// （app 根层级），使每个功能（learning / search / dictionary / word_browse / spell…）
/// 都能消费 [AudioPlaybackState]，而不必互相 import 某个功能域的内部实现。
///
/// 正因它是跨功能共享能力，所以放在 `core/` 而非任何 feature 目录；
/// 各页面/功能只依赖这里的共享抽象，禁止直接 import `features/player/**`。
Widget buildWordAudioScope({required Widget child}) {
  return MultiProvider(
    providers: [
      Provider<AudioService>.value(value: sl<AudioService>()),
      ChangeNotifierProvider<AudioPlaybackState>(
        create: (_) => AudioPlaybackState(audioService: sl<AudioService>()),
      ),
    ],
    child: child,
  );
}
