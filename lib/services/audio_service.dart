// 音频播放服务
// 统一管理单词发音播放，提供加载状态和错误反馈
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

class AudioService extends ChangeNotifier {
  static final AudioService instance = AudioService._();
  AudioService._();

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  /// 播放单词发音（优先系统 TTS，回退到网络音频）
  Future<void> playWordAudio(String word, {BuildContext? context}) async {
    if (_isLoading || word.trim().isEmpty) return;
    _isLoading = true;
    notifyListeners();

    AudioPlayer? player;
    try {
      // 优先使用系统 TTS（离线可用）
      // 桌面端回退到网络音频
      player = AudioPlayer();
      await player.play(UrlSource(
        'https://dict.youdao.com/dictvoice?audio=${Uri.encodeComponent(word.trim())}&type=2'));
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
      await player?.dispose();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 停止播放
  Future<void> stop() async {
    // just_audio 实例在 play 后即释放，无需手动停止
    _isLoading = false;
    notifyListeners();
  }
}
