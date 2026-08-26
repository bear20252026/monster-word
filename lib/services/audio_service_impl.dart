// AudioServiceImpl — 音频播放服务实现

import 'package:flutter/foundation.dart';

import '../../player/audio_players.dart';
import 'audio_service.dart';

/// 音频播放服务实现
///
/// 通过 audio_players 工具类实现具体的音频播放功能。
/// UI 层只依赖 AudioService 接口，不感知底层实现。
class AudioServiceImpl implements AudioService {
  final PhoneticAudioPlayer _phoneticPlayer = PhoneticAudioPlayer();
  final BBAudioPlayer _bbPlayer = BBAudioPlayer();

  @override
  Future<void> playWordAudio(String word, {String accent = 'us'}) async {
    try {
      await PhoneticAudioPlayer.playAudio(word, isUK: accent == 'uk');
    } catch (e) {
      debugPrint('[AudioService] Failed to play word audio: $e');
    }
  }

  @override
  Future<void> playFromUrl(String url) async {
    try {
      // 使用 SentenceAudioPlayer 播放网络音频
      await SentenceAudioPlayer.playAudio(url);
    } catch (e) {
      debugPrint('[AudioService] Failed to play from URL: $e');
    }
  }

  @override
  Future<void> stop() async {
    await _bbPlayer.stop();
  }

  @override
  bool get isPlaying => _bbPlayer.isPlaying;
}
