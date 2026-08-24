// 播放器层：翻译自 player/（v3.2 源码 9 个类）
// 文件：完整移植 MediaPlayStateListener / PlayAudioListener
//      + BBAudioPlayer（音频播放封装）+ PhoneticAudioPlayer（单词发音）
//      + SentenceAudioPlayer（例句播放）+ TextAudioPlayer（TTS 播放）
//
// 注：BaseMediaPlayer / SystemMediaPlayer / ExoMediaPlayer 在 Flutter 中不需要，
//     audioplayers 包统一处理底层播放。

import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

// ============================================================
// 接口层（翻译自 MediaPlayStateListener.java + PlayAudioListener.java）
// ============================================================

/// 播放状态监听（原版 MediaPlayStateListener 接口）
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

/// 播放监听（原版 PlayAudioListener，完整 8 个回调）
abstract class PlayAudioListener {
  void onLoadStart(String url);
  void onLoadSuc(String url);
  void onLoadError(String url);
  void onPlayFileChanged(String url);
  void onPlayStart();
  void onPlayPause();
  void onPlayComplete();
  void onPlayError();
}

/// 带默认空实现的 PlayAudioListener（方便只关心部分回调的场景）
class PlayAudioListenerAdapter implements PlayAudioListener {
  @override
  void onLoadStart(String url) {}
  @override
  void onLoadSuc(String url) {}
  @override
  void onLoadError(String url) {}
  @override
  void onPlayFileChanged(String url) {}
  @override
  void onPlayStart() {}
  @override
  void onPlayPause() {}
  @override
  void onPlayComplete() {}
  @override
  void onPlayError() {}
}

// ============================================================
// BBAudioPlayer（翻译自 BBAudioPlayer.java）
// 原版根据 Android API 选择 SystemMediaPlayer / ExoMediaPlayer，
// Flutter 中统一使用 audioplayers。
// ============================================================

/// 音频播放封装
class BBAudioPlayer {
  final AudioPlayer _player = AudioPlayer();
  MediaPlayStateListener? playStateListener;
  String _currentUrl = '';
  String _currentFileName = '';
  bool _lock = false;

  BBAudioPlayer() {
    _player.onPlayerStateChanged.listen((state) {
      if (_currentFileName.isEmpty) return;
      switch (state) {
        case PlayerState.playing:
          playStateListener?.onPlayStart(_currentFileName);
        case PlayerState.paused:
          playStateListener?.onPlayPause(_currentFileName);
        case PlayerState.completed:
          playStateListener?.onPlayComplete(_currentFileName);
        case PlayerState.stopped:
          playStateListener?.onPlayPause(_currentFileName);
        case PlayerState.disposed:
          break;
      }
    });
    _player.onPlayerComplete.listen((_) {
      playStateListener?.onPlayComplete(_currentFileName);
    });
  }

  /// 播放 URL（原版 play）
  Future<void> play(String url) async {
    if (_lock) return;
    _currentUrl = url;
    _currentFileName = url;
    playStateListener?.onPlayStart(url);
    await _player.play(UrlSource(url));
  }

  /// 播放本地文件（原版 play(File, float)）
  Future<void> playFile(File file, {double speed = 1.0}) async {
    if (_lock) return;
    _currentFileName = p.basename(file.path);
    playStateListener?.onPlayStart(_currentFileName);
    await _player.setPlaybackRate(speed);
    await _player.play(DeviceFileSource(file.path));
  }

  /// 播放本地文件路径
  Future<void> playFilePath(String filePath, {double speed = 1.0}) async {
    await playFile(File(filePath), speed: speed);
  }

  /// 停止（原版 stop）
  Future<void> stop() async {
    await _player.stop();
  }

  /// 暂停（原版 pause）
  Future<void> pause() async {
    await _player.pause();
    if (_currentFileName.isNotEmpty) {
      playStateListener?.onPlayPause(_currentFileName);
    }
  }

  /// 释放（原版 release）
  Future<void> release() async {
    await _player.dispose();
  }

  /// 是否正在播放
  bool get isPlaying => _player.state == PlayerState.playing;

  /// 锁定播放（原版 setLock）
  void setLock(bool lock) {
    _lock = lock;
  }

  /// 设置监听（原版 setPlayStateListener）
  void setPlayStateListener(MediaPlayStateListener? listener) {
    playStateListener = listener;
  }
}

// ============================================================
// 公共下载工具（原版 DownloadHttpClient 的简化替代）
// ============================================================

/// 下载结果
class _DownloadResult {
  final File? file;
  final bool success;
  final int statusCode;

  _DownloadResult({this.file, this.success = false, this.statusCode = 0});
}

/// 简化的下载客户端（替代原版 DownloadHttpClient）
class _AudioDownloader {
  static const int _connectTimeout = 5;
  static const int _readTimeout = 10;

  /// 下载文件到本地路径，支持主/备 URL 切换
  static Future<_DownloadResult> downloadFile(
    String localPath,
    String primaryUrl, {
    String? fallbackUrl,
  }) async {
    // 确保目录存在
    final dir = Directory(p.dirname(localPath));
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }

    // 尝试主 URL
    var result = await _tryDownload(localPath, primaryUrl);
    if (result.success) return result;

    // 主 URL 失败且有备选 URL 时重试
    if (fallbackUrl != null && result.statusCode != 10005) {
      result = await _tryDownload(localPath, fallbackUrl);
    }
    return result;
  }

  static Future<_DownloadResult> _tryDownload(
      String localPath, String url) async {
    try {
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: _connectTimeout + _readTimeout));
      if (response.statusCode == 200) {
        final file = File(localPath);
        await file.writeAsBytes(response.bodyBytes);
        return _DownloadResult(file: file, success: true, statusCode: 200);
      }
      return _DownloadResult(statusCode: response.statusCode);
    } catch (e) {
      return _DownloadResult(statusCode: -1);
    }
  }
}

// ============================================================
// 缓存目录工具（原版 LexisFileSystem / FileUtils 的简化替代）
// ============================================================

/// 音频缓存目录管理
class _AudioCacheDir {
  static String? _cachePath;

  /// 获取音频缓存根目录
  static Future<String> getCachePath() async {
    if (_cachePath != null) return _cachePath!;
    final appDir = await getApplicationDocumentsDirectory();
    _cachePath = p.join(appDir.path, 'audio_cache');
    final dir = Directory(_cachePath!);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    return _cachePath!;
  }

  /// 单词发音缓存路径（美音）
  static Future<String> wordUsSpeechPath(String word) async {
    final base = await getCachePath();
    return p.join(base, 'phonetic', 'us', '${word.toLowerCase()}.mp3');
  }

  /// 单词发音缓存路径（英音）
  static Future<String> wordUkSpeechPath(String word) async {
    final base = await getCachePath();
    return p.join(base, 'phonetic', 'uk', '${word.toLowerCase()}.mp3');
  }

  /// 例句音频缓存路径
  static Future<String> sentenceAudioPath(String url) async {
    final base = await getCachePath();
    // 从 URL 中提取文件名
    final fileName = _getFileName(url);
    return p.join(base, 'sentence', fileName);
  }

  /// TTS 音频缓存路径
  static Future<String> ttsAudioPath(String url) async {
    final base = await getCachePath();
    final fileName = _getFileName(url);
    return p.join(base, 'tts', fileName);
  }

  /// 从 URL/路径中提取文件名
  static String _getFileName(String path) {
    final uri = Uri.tryParse(path);
    if (uri != null && uri.pathSegments.isNotEmpty) {
      return uri.pathSegments.last;
    }
    return path.split('/').last;
  }
}

// ============================================================
// 有道词典发音 URL 构建（原版 PronounceUtils / LexisFileSystem）
// ============================================================

/// 有道词典发音 URL
String _buildYoudaoUrl(String word, {bool isUK = false}) {
  final type = isUK ? '1' : '2'; // 1=英音 2=美音
  return 'http://dict.youdao.com/dictvoice?audio=${Uri.encodeComponent(word)}&type=$type';
}

/// beingfine 音频服务器 URL（原版 PublicConstants.BASE_AUDIO_URL）
const String _baseAudioUrl = 'http://audio.beingfine.cn/';

/// 七牛 CDN URL（原版 PublicConstants.QINIU_RESOURCE_URL，下载备用）
const String _qiniuResourceUrl = 'http://7ncdn.beingfine.cn/';

// ============================================================
// PhoneticAudioPlayer（翻译自 PhoneticAudioPlayer.java）
// 单词发音播放器：先查本地缓存，没有则下载后播放
// ============================================================

/// 单词发音播放器（翻译自 PhoneticAudioPlayer.java：单例）
class PhoneticAudioPlayer {
  static final PhoneticAudioPlayer _instance = PhoneticAudioPlayer._();
  factory PhoneticAudioPlayer() => _instance;
  PhoneticAudioPlayer._() {
    _audioPlayer.setPlayStateListener(MediaPlayStateListener(
      onPlayStart: (url) => playStateListener?.onPlayStart(),
      onPlayPause: (url) => playStateListener?.onPlayPause(),
      onPlayComplete: (url) => playStateListener?.onPlayComplete(),
      onPlayError: (url) => playStateListener?.onPlayError(),
    ));
  }

  final BBAudioPlayer _audioPlayer = BBAudioPlayer();
  PlayAudioListener? playStateListener;
  bool _isPronounceUK = false;
  bool _needPlay = false;

  /// 播放单词发音（原版 playAudio 静态方法）
  static Future<void> playAudio(String word, {bool? isUK}) async {
    await _instance._playPhoneticAudio(word, isUK ?? _instance._isPronounceUK);
  }

  /// 内部播放（原版 playPhoneticAudio）
  Future<void> _playPhoneticAudio(String word, bool isUK) async {
    _isPronounceUK = isUK;
    if (word.isEmpty) return;

    // 如果正在播放，先暂停
    if (_audioPlayer.isPlaying) {
      _audioPlayer.pause();
    }

    // 检查本地缓存
    final localPath = isUK
        ? await _AudioCacheDir.wordUkSpeechPath(word)
        : await _AudioCacheDir.wordUsSpeechPath(word);

    final file = File(localPath);
    if (file.existsSync()) {
      // 直接播放本地文件
      _playFile(file);
    } else {
      // 下载后播放
      await _downloadAndPlay(word, localPath);
    }
  }

  /// 播放本地文件
  void _playFile(File file) {
    if (!_needPlay) return;
    _audioPlayer.stop();
    playStateListener?.onPlayFileChanged(file.path);
    _audioPlayer.playFile(file);
  }

  /// 下载并播放（原版 downloadAudioAndPlay_internal）
  Future<void> _downloadAndPlay(String word, String localPath) async {
    playStateListener?.onLoadStart(localPath);

    // 主 URL：有道词典
    final primaryUrl = _buildYoudaoUrl(word, isUK: _isPronounceUK);

    final result = await _AudioDownloader.downloadFile(localPath, primaryUrl);

    if (result.success && result.file != null) {
      playStateListener?.onLoadSuc(primaryUrl);
      _playFile(result.file!);
    } else {
      playStateListener?.onLoadError(primaryUrl);
    }
  }

  /// 设置是否使用英音（原版 setPronounceUK）
  static void setPronounceUK(bool isUK) {
    _instance._isPronounceUK = isUK;
  }

  /// 设置是否需要播放（原版 setNeedPlay）
  static void setNeedPlay(bool need) {
    _instance._needPlay = need;
  }

  /// 暂停（原版 pause）
  static void pause() {
    _instance._audioPlayer.pause();
  }

  /// 设置监听（原版 setPhoneticAudioPlayListener）
  void setPhoneticAudioPlayListener(PlayAudioListener? listener) {
    playStateListener = listener;
  }
}

// ============================================================
// SentenceAudioPlayer（翻译自 SentenceAudioPlayer.java）
// 例句播放器：支持下载缓存、播放速度控制
// ============================================================

/// 例句播放监听（原版 SentencePlayListener）
abstract class SentencePlayListener {
  bool checkWhetherPlay(String url);
  void onPlayComplete(String url);
}

/// 例句播放器（翻译自 SentenceAudioPlayer.java：单例）
class SentenceAudioPlayer {
  static final SentenceAudioPlayer _instance = SentenceAudioPlayer._();
  factory SentenceAudioPlayer() => _instance;
  SentenceAudioPlayer._() {
    _audioPlayer.setPlayStateListener(MediaPlayStateListener(
      onPlayStart: (url) {
        final fullUrl = _getCompleteAudioUrl(url);
        playStateListener?.onPlayStart();
      },
      onPlayPause: (url) {
        playStateListener?.onPlayPause();
      },
      onPlayComplete: (url) {
        final fullUrl = _getCompleteAudioUrl(url);
        playStateListener?.onPlayComplete();
        _sentenceListener?.onPlayComplete(fullUrl);
      },
      onPlayError: (url) {
        playStateListener?.onPlayError();
      },
    ));
  }

  final BBAudioPlayer _audioPlayer = BBAudioPlayer();
  PlayAudioListener? playStateListener;
  SentencePlayListener? _sentenceListener;
  String _currentUrl = '';
  String _oldUrl = '';
  double _playSpeed = 1.0;
  bool _needPlay = false;

  /// 获取完整的音频 URL
  String _getCompleteAudioUrl(String url) {
    if (url.isEmpty) return '';
    if (_currentUrl.isNotEmpty && _currentUrl.contains(url)) {
      return _currentUrl;
    }
    if (_oldUrl.isNotEmpty && _oldUrl.contains(url)) {
      return _oldUrl;
    }
    return '';
  }

  /// 播放例句音频（原版 playAudio 静态方法）
  static Future<void> playAudio(String url, {double speed = 1.0}) async {
    if (url.isNotEmpty) {
      await getInstance()._playSentenceAudio(url, speed);
    }
  }

  /// 内部播放逻辑
  Future<void> _playSentenceAudio(String url, double speed) async {
    _oldUrl = _currentUrl;
    _currentUrl = url;
    playStateListener?.onPlayFileChanged(_currentUrl);

    // 构建完整 URL
    final fullUrl = url.startsWith('http') ? url : '$_baseAudioUrl$url';

    // 暂停之前的播放
    _audioPlayer.pause();
    _playSpeed = speed;

    // 检查本地缓存
    final localPath = await _AudioCacheDir.sentenceAudioPath(fullUrl);
    final file = File(localPath);

    if (file.existsSync()) {
      _playFile(file, speed);
    } else {
      // 下载后播放
      await _downloadAndPlay(fullUrl, localPath, speed);
    }
  }

  /// 播放本地文件
  void _playFile(File file, double speed) {
    if (!_needPlay) {
      // 如果没有 sentenceListener，直接播放
      if (_sentenceListener == null) {
        _audioPlayer.stop();
        _audioPlayer.playFile(file, speed: speed);
        return;
      }
      // 有 listener 时检查是否应该播放
      if (_sentenceListener!.checkWhetherPlay(_currentUrl)) {
        _audioPlayer.stop();
        _audioPlayer.playFile(file, speed: speed);
      }
      return;
    }
    _audioPlayer.stop();
    _audioPlayer.playFile(file, speed: speed);
  }

  /// 下载并播放（原版 downloadAudioAndPlay_internal）
  Future<void> _downloadAndPlay(
      String fullUrl, String localPath, double speed) async {
    playStateListener?.onLoadStart(fullUrl);

    final result = await _AudioDownloader.downloadFile(
      localPath,
      fullUrl,
      fallbackUrl: fullUrl.replaceFirst(_baseAudioUrl, _qiniuResourceUrl),
    );

    if (result.success && result.file != null) {
      playStateListener?.onLoadSuc(fullUrl);
      _playFile(result.file!, speed);
    } else {
      playStateListener?.onLoadError(fullUrl);
    }
  }

  /// 获取单例
  static SentenceAudioPlayer getInstance() => _instance;

  /// 获取监听（原版 getListener）
  static SentencePlayListener? getListener() =>
      getInstance()._sentenceListener;

  /// 设置监听（原版 setListener）
  static void setListener(SentencePlayListener? listener) {
    getInstance()._sentenceListener = listener;
  }

  /// 设置是否需要播放（原版 setNeedPlay）
  static void setNeedPlay(bool need) {
    getInstance()._needPlay = need;
  }

  /// 暂停（原版 pause）
  static void pause() {
    getInstance()._audioPlayer.pause();
  }

  /// 是否正在播放（原版 isPlaying）
  static bool isPlaying() => getInstance()._audioPlayer.isPlaying;

  /// 设置播放状态监听（原版 setSentencePlayStateListener）
  void setSentencePlayStateListener(PlayAudioListener? listener) {
    playStateListener = listener;
  }
}

// ============================================================
// TextAudioPlayer（翻译自 TextAudioPlayer.java）
// TTS 音频播放器：请求服务器获取音频 URL，下载后播放
// ============================================================

/// TTS 音频播放器（翻译自 TextAudioPlayer.java：单例）
class TextAudioPlayer {
  static final TextAudioPlayer _instance = TextAudioPlayer._();
  factory TextAudioPlayer() => _instance;
  TextAudioPlayer._() {
    _audioPlayer.setPlayStateListener(MediaPlayStateListener(
      onPlayStart: (url) => playStateListener?.onPlayStart(),
      onPlayPause: (url) => playStateListener?.onPlayPause(),
      onPlayComplete: (url) => playStateListener?.onPlayComplete(),
      onPlayError: (url) => playStateListener?.onPlayError(),
    ));
  }

  final BBAudioPlayer _audioPlayer = BBAudioPlayer();
  PlayAudioListener? playStateListener;
  bool _isFirstDownload = true;

  /// 获取单例
  static TextAudioPlayer getInstance() => _instance;

  /// 设置监听（原版 setTextPlayListener）
  void setTextPlayListener(PlayAudioListener? listener) {
    playStateListener = listener;
  }

  /// 播放 TTS 音频（原版 playText）
  Future<void> playText(String text, {double speed = 1.0}) async {
    if (text.isEmpty) return;

    // 检查本地缓存（通过 TTS 音频 URL 缓存）
    final localPath = await _AudioCacheDir.ttsAudioPath(text);
    final file = File(localPath);

    if (file.existsSync()) {
      _playFile(file, speed);
      return;
    }

    // 请求服务器获取音频 URL
    playStateListener?.onLoadStart(text);

    try {
      final audioUrl = await _requestTtsAudioUrl(text);
      if (audioUrl != null && audioUrl.isNotEmpty) {
        await _downloadAndPlay(audioUrl, localPath, speed);
      } else {
        playStateListener?.onLoadError(text);
      }
    } catch (e) {
      playStateListener?.onLoadError(text);
    }
  }

  /// 请求 TTS 音频 URL（原版 GetAudioWithTextService.requestAudio）
  Future<String?> _requestTtsAudioUrl(String text) async {
    // 原版通过 GetAudioWithTextService 向服务器请求音频路径
    // 返回 JSON: {"path": "xxx/xxx.mp3"}
    // 这里简化为使用有道 TTS 接口
    return 'http://dict.youdao.com/dictvoice?audio=${Uri.encodeComponent(text)}&type=2';
  }

  /// 播放本地文件
  void _playFile(File file, double speed) {
    _audioPlayer.playFile(file, speed: speed);
  }

  /// 下载并播放（原版 downLoadTextAudioPlay_internal）
  Future<void> _downloadAndPlay(
      String audioUrl, String localPath, double speed) async {
    _isFirstDownload = true;

    // 主 URL：beingfine
    final primaryUrl = '$_baseAudioUrl$audioUrl';
    // 备用 URL：七牛
    final fallbackUrl = '$_qiniuResourceUrl$audioUrl';

    final result = await _AudioDownloader.downloadFile(
      localPath,
      primaryUrl,
      fallbackUrl: fallbackUrl,
    );

    if (result.success && result.file != null) {
      playStateListener?.onLoadSuc(audioUrl);
      _playFile(result.file!, speed);
    } else {
      playStateListener?.onLoadError(audioUrl);
    }
  }

  /// 暂停
  void pause() {
    _audioPlayer.pause();
  }

  /// 是否正在播放
  bool get isPlaying => _audioPlayer.isPlaying;
}

// ============================================================
// 便捷全局函数
// ============================================================

/// 便捷：播放单词发音（原版 PhoneticAudioPlayer.playAudio）
Future<void> playWordAudio(String word, {bool isUK = false}) {
  return PhoneticAudioPlayer.playAudio(word, isUK: isUK);
}

/// 便捷：播放例句
Future<void> playSentenceAudio(String url, {double speed = 1.0}) {
  return SentenceAudioPlayer.playAudio(url, speed: speed);
}

/// 便捷：播放 TTS 文本
Future<void> playTextAudio(String text, {double speed = 1.0}) {
  return TextAudioPlayer().playText(text, speed: speed);
}
