// 播放状态 ViewModel — 播放状态管理
import 'package:flutter/foundation.dart';

import '../services/audio_service.dart';

/// 播放状态 ViewModel
///
/// 负责管理音频播放状态、播放控制。
/// 通过 AudioService 访问音频播放业务逻辑。
class PlayerState extends ChangeNotifier {
  final AudioService _audioService;

  PlayerState({required AudioService audioService})
      : _audioService = audioService;

  bool _isPlaying = false;
  bool _isLoading = false;
  String _currentWord = '';

  bool get isPlaying => _isPlaying;
  bool get isLoading => _isLoading;
  String get currentWord => _currentWord;

  /// 播放单词发音
  /// ✅ 修复：优先使用第三方服务器提供的 audioUrl
  Future<void> playWord(String word, {String? audioUrl}) async {
    if (word.isEmpty) return;
    _currentWord = word;
    _isLoading = true;
    notifyListeners();

    try {
      await _audioService.playWordAudio(word, audioUrl: audioUrl);
      _isPlaying = true;
    } catch (e) {
      debugPrint('[PlayerState] play error: $e');
      _isPlaying = false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 停止播放
  Future<void> stop() async {
    await _audioService.stop();
    _isPlaying = false;
    _isLoading = false;
    notifyListeners();
  }

  /// 暂停播放
  Future<void> pause() async {
    _isPlaying = false;
    notifyListeners();
  }

  /// 恢复播放
  Future<void> resume() async {
    if (_currentWord.isNotEmpty) {
      await playWord(_currentWord);
    }
  }
}
