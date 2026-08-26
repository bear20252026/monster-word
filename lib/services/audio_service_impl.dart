// AudioServiceImpl — 音频播放服务实现

import 'package:flutter/foundation.dart';

import '../../player/audio_players.dart';
import 'audio_service.dart';

/// 音频播放服务实现
///
/// 通过 audio_players 工具类实现具体的音频播放功能。
/// UI 层只依赖 AudioService 接口，不感知底层实现。
class AudioServiceImpl implements AudioService {
  final BBAudioPlayer _bbPlayer = BBAudioPlayer();
  bool _disposed = false;

  @override
  Future<void> playWordAudio(String word, {String accent = 'us'}) async {
    if (_disposed) return;
    try {
      await PhoneticAudioPlayer.playAudio(word, isUK: accent == 'uk');
    } catch (e) {
      debugPrint('[AudioService] Failed to play word audio: $e');
    }
  }

  @override
  Future<void> playFromUrl(String url) async {
    if (_disposed) return;
    try {
      // 使用 SentenceAudioPlayer 播放网络音频
      await SentenceAudioPlayer.playAudio(url);
    } catch (e) {
      debugPrint('[AudioService] Failed to play from URL: $e');
    }
  }

  @override
  Future<void> stop() async {
    if (_disposed) return;
    await _bbPlayer.stop();
  }

  @override
  bool get isPlaying => _disposed ? false : _bbPlayer.isPlaying;

  /// 释放所有音频资源（防止内存泄漏）
  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _bbPlayer.release();
    debugPrint('[AudioService] Disposed all audio resources');
  }
}
