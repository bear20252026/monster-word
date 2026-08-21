// 由账号4生成
// 播放器层：翻译自 player/（v3.2 源码 1:1）
// 文件：BBAudioPlayer（音频播放封装）+ PhoneticAudioPlayer（单词发音单例）
//      + SentenceAudioPlayer（例句播放）

import 'package:audioplayers/audioplayers.dart';

/// 播放状态监听（原版 MediaPlayStateListener 接口，Dart 用回调实现）
class MediaPlayStateListener {
  void Function(String url)? onPlayStartCb;
  void Function(String url)? onPlayPauseCb;
  void Function(String url)? onPlayCompleteCb;
  void Function(String url)? onPlayErrorCb;

  MediaPlayStateListener({
    void Function(String url)? onPlayStart,
    void Function(String url)? onPlayPause,
    void Function(String url)? onPlayComplete,
    void Function(String url)? onPlayError,
  })  : onPlayStartCb = onPlayStart,
        onPlayPauseCb = onPlayPause,
        onPlayCompleteCb = onPlayComplete,
        onPlayErrorCb = onPlayError;

  void onPlayStart(String url) => onPlayStartCb?.call(url);
  void onPlayPause(String url) => onPlayPauseCb?.call(url);
  void onPlayComplete(String url) => onPlayCompleteCb?.call(url);
  void onPlayError(String url) => onPlayErrorCb?.call(url);
}

/// 音频播放封装（翻译自 BBAudioPlayer.java）
class BBAudioPlayer {
  final AudioPlayer _player = AudioPlayer();
  MediaPlayStateListener? playStateListener;
  String _currentUrl = '';

  BBAudioPlayer() {
    _player.onPlayerStateChanged.listen((state) {
      if (_currentUrl.isEmpty) return;
      switch (state) {
        case PlayerState.playing:
          playStateListener?.onPlayStart(_currentUrl);
        case PlayerState.paused:
          playStateListener?.onPlayPause(_currentUrl);
        case PlayerState.completed:
          playStateListener?.onPlayComplete(_currentUrl);
        case PlayerState.stopped:
          playStateListener?.onPlayPause(_currentUrl);
        case PlayerState.disposed:
          break;
      }
    });
    _player.onPlayerComplete.listen((_) {
      playStateListener?.onPlayComplete(_currentUrl);
    });
  }

  /// 播放 URL（原版 play）
  Future<void> play(String url) async {
    _currentUrl = url;
    playStateListener?.onPlayStart(url);
    await _player.play(UrlSource(url));
  }

  /// 停止（原版 stop）
  Future<void> stop() async {
    await _player.stop();
  }

  /// 释放（原版 release）
  Future<void> release() async {
    await _player.dispose();
  }

  /// 是否正在播放
  bool get isPlaying => _player.state == PlayerState.playing;
}

/// 单词发音播放器（翻译自 PhoneticAudioPlayer.java：单例）
class PhoneticAudioPlayer {
  static final PhoneticAudioPlayer _instance = PhoneticAudioPlayer._();
  factory PhoneticAudioPlayer() => _instance;
  PhoneticAudioPlayer._();

  final BBAudioPlayer _audioPlayer = BBAudioPlayer();
  PlayAudioListener? playStateListener;
  bool _isPronounceUK = false;

  /// 播放单词发音（原版 playAudio 静态方法）
  static Future<void> playAudio(String word, {bool? isUK}) async {
    await _instance._playPhoneticAudio(word, isUK ?? _instance._isPronounceUK);
  }

  /// 内部播放（原版 playPhoneticAudio）
  Future<void> _playPhoneticAudio(String word, bool isUK) async {
    _isPronounceUK = isUK;
    if (word.isEmpty) return;
    final url = _buildAudioUrl(word, isUK);
    _audioPlayer.playStateListener = _internalListener();
    await _audioPlayer.play(url);
  }

  /// 音频 URL（原版按词典发音接口）
  String _buildAudioUrl(String word, bool isUK) {
    final type = isUK ? '1' : '2'; // 1=英音 2=美音
    return 'http://dict.youdao.com/dictvoice?audio=${Uri.encodeComponent(word)}&type=$type';
  }

  MediaPlayStateListener _internalListener() => MediaPlayStateListener(
        onPlayStart: (url) => playStateListener?.onPlayStart(),
        onPlayPause: (url) => playStateListener?.onPlayPause(),
        onPlayComplete: (url) => playStateListener?.onPlayComplete(),
        onPlayError: (url) => playStateListener?.onPlayError(),
      );

  /// 设置是否使用英音（原版 setPronounceUK）
  static void setPronounceUK(bool isUK) {
    _instance._isPronounceUK = isUK;
  }
}

/// 播放监听（原版 PlayAudioListener）
abstract class PlayAudioListener {
  void onPlayStart();
  void onPlayPause();
  void onPlayComplete();
  void onPlayError();
}

/// 例句播放器（翻译自 SentenceAudioPlayer.java）
class SentenceAudioPlayer {
  static final SentenceAudioPlayer _instance = SentenceAudioPlayer._();
  factory SentenceAudioPlayer() => _instance;
  SentenceAudioPlayer._();

  final BBAudioPlayer _audioPlayer = BBAudioPlayer();
  PlayAudioListener? playStateListener;

  /// 播放例句音频（原版 play）
  Future<void> play(String audioUrl) async {
    if (audioUrl.isEmpty) return;
    final fullUrl = audioUrl.startsWith('http')
        ? audioUrl
        : 'http://audio.beingfine.cn$audioUrl';
    _audioPlayer.playStateListener = MediaPlayStateListener(
      onPlayStart: (url) => playStateListener?.onPlayStart(),
      onPlayPause: (url) => playStateListener?.onPlayPause(),
      onPlayComplete: (url) => playStateListener?.onPlayComplete(),
      onPlayError: (url) => playStateListener?.onPlayError(),
    );
    await _audioPlayer.play(fullUrl);
  }

  /// 停止
  Future<void> stop() => _audioPlayer.stop();
}

/// 便捷：播放单词发音（全局函数，原版 PhoneticAudioPlayer.playAudio）
Future<void> playWordAudio(String word, {bool isUK = false}) {
  return PhoneticAudioPlayer.playAudio(word, isUK: isUK);
}

/// 便捷：播放例句
Future<void> playSentenceAudio(String url) {
  return SentenceAudioPlayer().play(url);
}
