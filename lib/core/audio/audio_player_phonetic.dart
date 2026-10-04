part of 'audio_players.dart';

// PhoneticAudioPlayer 单词发音
// ============================================================
// 有道词典发音 URL 构建（PronounceUtils / LexisFileSystem）
// ============================================================

/// 有道词典发音 URL
String _buildYoudaoUrl(String word, {bool isUK = false}) {
  final type = isUK ? '1' : '2'; // 1=英音 2=美音
  return 'https://dict.youdao.com/dictvoice?audio=${Uri.encodeComponent(word)}&type=$type';
}

/// 音频服务器 URL（audio.beingfine.cn，词库内置音频地址）
const String _baseAudioUrl = 'https://audio.beingfine.cn/';

/// 七牛 CDN URL（PublicConstants.QINIU_RESOURCE_URL，下载备用）
const String _qiniuResourceUrl = 'https://7ncdn.beingfine.cn/';

// ============================================================
// PhoneticAudioPlayer
// 单词发音播放器：先查本地缓存，没有则下载后播放
// ============================================================

/// 单词发音播放器
class PhoneticAudioPlayer {
  static final PhoneticAudioPlayer _instance = PhoneticAudioPlayer._();
  factory PhoneticAudioPlayer() => _instance;
  PhoneticAudioPlayer._() {
    _audioPlayer.setPlayStateListener(
      MediaPlayStateListener(
        onPlayStart: (url) => playStateListener?.onPlayStart(),
        onPlayPause: (url) => playStateListener?.onPlayPause(),
        onPlayComplete: (url) => playStateListener?.onPlayComplete(),
        onPlayError: (url) => playStateListener?.onPlayError(),
      ),
    );
  }

  final MwAudioPlayer _audioPlayer = MwAudioPlayer();
  PlayAudioListener? playStateListener;
  bool _isPronounceUK = false;

  /// MEM：释放内部播放器并清空监听（退出/销毁时由 AudioServiceImpl 调用）。
  Future<void> release() async {
    playStateListener = null;
    await _audioPlayer.release();
  }

  /// 默认允许播放。原默认 false 且全仓库无 setNeedPlay(true) 调用点，
  /// 导致 _playFile 的 if (!_needPlay) return 把所有单词发音静默丢弃
  /// （症状：例句响、单词不响）。
  final bool _needPlay = true;

  /// 播放单词发音（playAudio；DI 化后由 AudioServiceImpl 注入调用）
  Future<void> playAudio(String word, {bool? isUK}) async {
    await _playPhoneticAudio(word, isUK ?? _isPronounceUK);
  }

  /// 内部播放（playPhoneticAudio）
  Future<void> _playPhoneticAudio(String word, bool isUK) async {
    _isPronounceUK = isUK;
    if (word.isEmpty) return;

    // 如果正在播放，先暂停
    if (_audioPlayer.isPlaying) {
      unawaited(_audioPlayer.pause());
    }

    // 检查本地缓存
    final localPath = isUK ? await _AudioCacheDir.wordUkSpeechPath(word) : await _AudioCacheDir.wordUsSpeechPath(word);

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

  /// 下载并播放（downloadAudioAndPlay_internal）
  Future<void> _downloadAndPlay(String word, String localPath) async {
    playStateListener?.onLoadStart(localPath);

    // 主 URL：有道词典
    final primaryUrl = _buildYoudaoUrl(word, isUK: _isPronounceUK);

    final result = await AudioDownloader.downloadFile(localPath, primaryUrl);

    if (result.success && result.file != null) {
      playStateListener?.onLoadSuc(primaryUrl);
      _playFile(result.file!);
    } else {
      playStateListener?.onLoadError(primaryUrl);
      // 兜底：网络音频不可用时改用系统 TTS 念出单词（离线可用，不再静默）
      await SystemTts().speakEnglish(word);
    }
  }

  /// 仅供回归测试观察播放开关默认值（REG-AUDIO-001）。
  @visibleForTesting
  bool get needPlayForTest => _needPlay;

  /// 暂停（pause）
  void pause() {
    _audioPlayer.pause();
  }

  /// 设置监听（setPhoneticAudioPlayListener）
  void setPhoneticAudioPlayListener(PlayAudioListener? listener) {
    playStateListener = listener;
  }
}
