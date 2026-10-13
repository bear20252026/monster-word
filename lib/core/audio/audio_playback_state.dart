import 'dart:async';

import 'package:word_app/core/utils/debug_log.dart';
import 'package:flutter/foundation.dart';

import 'package:word_app/core/audio/audio_service.dart';

/// 应用级共享的「单词音频播放」状态（跨功能基础设施）。
///
/// 供所有需要播放单词发音的功能（learning / search / dictionary / word_browse /
/// spell 等）通过依赖注入消费；各功能一律 import 本共享抽象，
/// 而不再互相 import 某个功能域的内部实现。
/// 请求序号保证较早播放请求的异步完成不会覆盖后续停止或新播放命令的状态。
class AudioPlaybackState extends ChangeNotifier {
  AudioPlaybackState({required this._audioService});

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
      debugLog('Audio playback error: $error');
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

  /// 播放例句/句子音频（URL 已为完整可播地址，如 audio.beingfine.cn 的 mp3）。
  Future<void> playSentence(String audioUrl) async {
    if (audioUrl.isEmpty) return;
    final request = ++_requestSequence;
    _currentWord = '';
    _currentAudioUrl = audioUrl;
    _isLoading = true;
    _isPlaying = false;
    notifyListeners();

    try {
      await _audioService.playFromUrl(audioUrl);
      if (request == _requestSequence) {
        _isPlaying = true;
      }
    } catch (error) {
      debugLog('Sentence audio playback error: $error');
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

  /// 暂停播放。
  ///
  /// R2-14：此前只把 `_isPlaying` 置 false（「底层服务暂未提供暂停端口」），
  /// 结果 UI 显示已暂停而扬声器继续出声。现在端口已补（[AudioService.pause]），
  /// 真实暂停底层播放。保持 `void` 签名以兼容既有回调用法——暂停是「立即停声」
  /// 操作，等待完成没有语义价值；失败由 AudioService 内部降级并上报。
  void pause() {
    unawaited(_audioService.pause());
    _isPlaying = false;
    notifyListeners();
  }

  Future<void> resume() async {
    if (_currentWord.isNotEmpty) {
      await playWord(_currentWord, audioUrl: _currentAudioUrl);
    }
  }
}
