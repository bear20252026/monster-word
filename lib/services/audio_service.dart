// 音频播放服务
// 统一管理单词发音播放，提供加载状态和错误反馈
import 'package:flutter/material.dart';

import '../player/audio_players.dart' as audio_players;

class AudioService extends ChangeNotifier {
  static final AudioService instance = AudioService._();
  AudioService._();

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  /// 播放单词发音（使用 PhoneticAudioPlayer，带缓存）
  Future<void> playWordAudio(String word, {BuildContext? context}) async {
    if (_isLoading || word.trim().isEmpty) return;
    _isLoading = true;
    notifyListeners();

    try {
      await audio_players.playWordAudio(word);
    } catch (e) {
      debugPrint('[AudioService] playback error: $e');
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('发音加载失败，请检查网络'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 停止播放
  Future<void> stop() async {
    _isLoading = false;
    notifyListeners();
  }
}
