// 播放器层（库出口）
//
// 具体实现按职责拆分到同名 part 文件，本文件只保留 import 与 part 声明：
//   - audio_player_listeners.dart  播放回调接口层（MediaPlayStateListener / PlayAudioListener）
//   - audio_player_core.dart       MwAudioPlayer（底层播放封装）
//   - audio_player_download.dart   音频下载（主/备双源）
//   - audio_player_cache.dart      音频缓存目录管理
//   - audio_player_phonetic.dart   PhoneticAudioPlayer（单词发音）
//   - audio_player_sentence.dart   SentenceAudioPlayer（例句播放）
//   - audio_player_text.dart       TextAudioPlayer（TTS 播放）
//
// 注：BaseMediaPlayer / SystemMediaPlayer / ExoMediaPlayer 在 Flutter 中不需要，
//     audioplayers 包统一处理底层播放。

import 'package:word_app/core/utils/debug_log.dart';

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart' as ap;
import 'package:just_audio/just_audio.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'package:word_app/core/audio/system_tts.dart';
import 'package:path/path.dart' as p;
import 'package:word_app/core/utils/swallowed_error_report.dart';

part 'audio_player_listeners.dart';
part 'audio_player_core.dart';
part 'audio_player_download.dart';
part 'audio_player_cache.dart';
part 'audio_player_phonetic.dart';
part 'audio_player_sentence.dart';
part 'audio_player_text.dart';

/// 移动端音频会话初始化（确保手机能正常发音）
Future<void> initMobileAudioSession() async {
  if (Platform.isIOS || Platform.isAndroid) {
    try {
      debugLog('[AudioInit] Initializing mobile audio session for ${Platform.isIOS ? "iOS" : "Android"}');
      final player = AudioPlayer();

      // 确保音频不被系统静音，设置最大音量
      await player.setVolume(1.0);
      debugLog('[AudioInit] Set volume to 1.0');

      // 禁用跳过静音，确保音频完整播放
      await player.setSkipSilenceEnabled(false);
      debugLog('[AudioInit] Disabled skip silence');

      // 设置处理状态监听，便于调试
      final stateSub = player.processingStateStream.listen((state) {
        debugLog('[AudioInit] Processing state: $state');
      });

      // 立即释放临时播放器，避免资源占用（先取消订阅再释放）
      await stateSub.cancel();
      await player.dispose();
      debugLog('[AudioInit] Mobile audio session initialized successfully');
    } catch (e) {
      debugLog('[AudioInit] ERROR initializing mobile audio session: $e');
      debugLog('[AudioInit] Stack trace: ${StackTrace.current}');
    }
  } else {
    debugLog('[AudioInit] Skipping mobile audio init on desktop platform');
  }
}
