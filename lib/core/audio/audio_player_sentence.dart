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

    // MW-52：缓存自愈——坏缓存（半写文件 / CDN HTML 错误页）会被删除并走下载路径
    final localPath = await _AudioCacheDir.sentenceAudioPath(fullUrl);
    if (await _AudioCacheDir.isUsable(localPath)) {
      _playFile(File(localPath), speed);
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
      // MW-52：缓存回收（超上限时按最旧淘汰），不阻塞播放
      unawaited(_AudioCacheDir.enforceLimit());
    } else {
      playStateListener?.onLoadError(fullUrl);
      // 注意：此层拿不到句子文本（URL 文件名可能是哈希），不做 TTS 兜底，
      // 避免念出乱码；句子文本兜底应由调用方（持有例句文本）负责。
    }
  }

  /// MW-46：公开停止能力（原实现 stop 不可达，AudioServiceImpl 无法停它）。
  Future<void> stop() => _audioPlayer.stop();

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
