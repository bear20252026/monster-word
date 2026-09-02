import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import 'package:word_app/core/audio/audio_playback_state.dart';
import 'package:word_app/core/audio/audio_service.dart';

/// 应用级「单词音频播放」能力的共享装配。
///
/// 音频设备服务与播放状态是**跨功能共享基础设施**，在此一次性注入到所有功能域之上
/// （app 根层级），使每个功能（learning / search / dictionary / word_browse / spell…）
/// 都能消费 [AudioPlaybackState]，而不必互相 import 某个功能域的内部实现。
///
/// 正因它是跨功能共享能力，所以放在 `core/` 而非任何 feature 目录；
/// 各页面/功能只依赖这里的共享抽象，禁止直接 import `features/player/**`。
/// [audioService] 由 app 层（组合根）注入，core 不反向依赖 DI 容器。
Widget buildWordAudioScope({required AudioService audioService, required Widget child}) {
  return MultiProvider(
    providers: [
      Provider<AudioService>.value(value: audioService),
      ChangeNotifierProvider<AudioPlaybackState>(create: (_) => AudioPlaybackState(audioService: audioService)),
    ],
    child: child,
  );
}
