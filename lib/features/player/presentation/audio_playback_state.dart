import 'package:flutter/foundation.dart';

import '../../../services/audio_service.dart';

/// 播放器功能域的可订阅播放状态。
///
/// 页面只通过该状态触发单词发音，不再直接持有全局播放器状态。请求序号保证较早播放
/// 请求的异步完成不会覆盖后续停止或新播放命令的状态。
class AudioPlaybackState extends ChangeNotifier {
  AudioPlaybackState({required AudioService audioService}) : _audioService = audioService;

  final AudioService _audioService;

  bool _isPlaying = false;
  bool _isLoading = false;
  String _currentWord = '';
  String? _currentAudioUrl;
  int _requestSequence = 0;

  bool get isPlaying => _isPlaying;
  bool get isLoading => _isLoading;
  String get currentWord => _currentWord;

  Future<void> playWord(String word, {String? audioUrl}) async {
    if (word.isEmpty) return;
    final request = ++_requestSequence;
    _currentWord = word;
    _currentAudioUrl = audioUrl;
    _isLoading = true;
    _isPlaying = false;
    notifyListeners();

    try {
      await _audioService.playWordAudio(word, audioUrl: audioUrl);
      if (request == _requestSequence) {
        _isPlaying = true;
      }
    } catch (error) {
      debugPrint('Audio playback error: $error');
      if (request == _requestSequence) {
        _isPlaying = false;
      }
    } finally {
      if (request == _requestSequence) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> stop() async {
    ++_requestSequence;
    await _audioService.stop();
    _isPlaying = false;
    _isLoading = false;
    notifyListeners();
  }

  /// 底层服务暂未提供暂停端口，因此保持原有“仅更新 UI 播放标识”的兼容语义。
  void pause() {
    _isPlaying = false;
    notifyListeners();
  }

  Future<void> resume() async {
    if (_currentWord.isNotEmpty) {
      await playWord(_currentWord, audioUrl: _currentAudioUrl);
    }
  }
}
