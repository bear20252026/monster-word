part of 'audio_players.dart';

// SentenceAudioPlayer 例句播放
// ============================================================
// SentenceAudioPlayer
// 例句播放器：支持下载缓存、播放速度控制
// ============================================================

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
          playStateListener?.onPlayComplete();
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
    await _audioPlayer.release();
  }

  PlayAudioListener? playStateListener;
  String _currentUrl = '';

  /// 播放例句音频（playAudio 静态方法）
  Future<void> playAudio(String url, {double speed = 1.0}) async {
    if (url.isNotEmpty) {
      await _playSentenceAudio(url, speed);
    }
  }

  /// 内部播放逻辑
  Future<void> _playSentenceAudio(String url, double speed) async {
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
    _audioPlayer.stop();
    _audioPlayer.playFile(file, speed: speed);
  }

  /// 下载并播放（downloadAudioAndPlay_internal）
  Future<void> _downloadAndPlay(String fullUrl, String localPath, double speed) async {
    playStateListener?.onLoadStart(fullUrl);

    final result = await AudioDownloader.downloadFile(
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
