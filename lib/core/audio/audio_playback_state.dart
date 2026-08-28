import 'package:flutter/foundation.dart';

import '../../services/audio_service.dart';

/// 应用级共享的「单词音频播放」状态（跨功能基础设施）。
///
/// 供所有需要播放单词发音的功能（learning / search / dictionary / word_browse /
/// spell 等）通过依赖注入消费；各功能一律 import 本共享抽象，
/// 而不再互相 import 某个功能域的内部实现。
/// 请求序号保证较早播放请求的异步完成不会覆盖后续停止或新播放命令的状态。
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

  /// 底层服务暂未提供暂停端口，因此保持原有「仅更新 UI 播放标识」的兼容语义。
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
