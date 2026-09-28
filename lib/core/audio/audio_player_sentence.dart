part of 'audio_players.dart';

// SentenceAudioPlayer 例句播放
// ============================================================
// SentenceAudioPlayer
// 例句播放器：支持下载缓存、播放速度控制
// ============================================================

/// 例句播放监听（SentencePlayListener）
abstract class SentencePlayListener {
  bool checkWhetherPlay(String url);
  void onPlayComplete(String url);
}

/// 例句播放器
class SentenceAudioPlayer {
  static final SentenceAudioPlayer _instance = SentenceAudioPlayer._();
  factory SentenceAudioPlayer() => _instance;
  SentenceAudioPlayer._() {
    _audioPlayer.setPlayStateListener(
      MediaPlayStateListener(
        onPlayStart: (url) {
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
      ),
    );
  }

  final MwAudioPlayer _audioPlayer = MwAudioPlayer();

  /// MEM：释放内部播放器并清空监听。
  Future<void> release() async {
    playStateListener = null;
    _sentenceListener = null;
    await _audioPlayer.release();
  }

  PlayAudioListener? playStateListener;
  SentencePlayListener? _sentenceListener;
  String _currentUrl = '';
  String _oldUrl = '';
  final bool _needPlay = false;

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

  /// 播放例句音频（playAudio 静态方法）
  Future<void> playAudio(String url, {double speed = 1.0}) async {
    if (url.isNotEmpty) {
      await _playSentenceAudio(url, speed);
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
    unawaited(_audioPlayer.pause());

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
      if (_sentenceListener?.checkWhetherPlay(_currentUrl) ?? true) {
        // null 时默认播放（原行为）
        _audioPlayer.stop();
        _audioPlayer.playFile(file, speed: speed);
      }
      return;
    }
    _audioPlayer.stop();
    _audioPlayer.playFile(file, speed: speed);
  }

  /// 下载并播放（downloadAudioAndPlay_internal）
  Future<void> _downloadAndPlay(String fullUrl, String localPath, double speed) async {
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
      // 注意：此层拿不到句子文本（URL 文件名可能是哈希），不做 TTS 兜底，
      // 避免念出乱码；句子文本兜底应由调用方（持有例句文本）负责。
    }
  }

  /// 获取监听（getListener）
  SentencePlayListener? getListener() => _sentenceListener;

  /// 设置监听（setListener）
  void setListener(SentencePlayListener? listener) {
    _sentenceListener = listener;
  }

  /// 暂停（pause）
  void pause() {
    _audioPlayer.pause();
  }

  /// 是否正在播放（isPlaying）
  bool isPlaying() => _audioPlayer.isPlaying;

  /// 设置播放状态监听（setSentencePlayStateListener）
  void setSentencePlayStateListener(PlayAudioListener? listener) {
    playStateListener = listener;
  }
}
