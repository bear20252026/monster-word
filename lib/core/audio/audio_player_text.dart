part of 'audio_players.dart';

// TextAudioPlayer TTS 播放
// ============================================================
// TextAudioPlayer
// TTS 音频播放器：请求服务器获取音频 URL，下载后播放
// ============================================================

/// TTS 音频播放器
class TextAudioPlayer {
  static final TextAudioPlayer _instance = TextAudioPlayer._();
  factory TextAudioPlayer() => _instance;
  TextAudioPlayer._() {
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

  /// MEM：释放内部播放器并清空监听。
  Future<void> release() async {
    playStateListener = null;
    await _audioPlayer.release();
  }

  PlayAudioListener? playStateListener;

  /// 获取单例
  static TextAudioPlayer getInstance() => _instance;

  /// 设置监听（setTextPlayListener）
  void setTextPlayListener(PlayAudioListener? listener) {
    playStateListener = listener;
  }

  /// 播放 TTS 音频（playText）
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

  /// 请求 TTS 音频 URL（GetAudioWithTextService.requestAudio）
  Future<String?> _requestTtsAudioUrl(String text) async {
    // 通过 GetAudioWithTextService 向服务器请求音频路径
    // 返回 JSON: {"path": "xxx/xxx.mp3"}
    // 这里简化为使用有道 TTS 接口
    return 'https://dict.youdao.com/dictvoice?audio=${Uri.encodeComponent(text)}&type=2';
  }

  /// 播放本地文件
  void _playFile(File file, double speed) {
    _audioPlayer.playFile(file, speed: speed);
  }

  /// 下载并播放（downLoadTextAudioPlay_internal）
  Future<void> _downloadAndPlay(String audioUrl, String localPath, double speed) async {
    // 错误处理审计 P2：_requestTtsAudioUrl 已返回完整 URL（有道 TTS），
    // 再拼 _baseAudioUrl 会得到 "https://…/https://…" 的畸形地址，
    // 下载永远失败。绝对地址直接用，相对路径才拼主备前缀。
    late final String primaryUrl;
    late final String? fallbackUrl;
    if (audioUrl.startsWith('http://') || audioUrl.startsWith('https://')) {
      primaryUrl = audioUrl;
      fallbackUrl = null;
    } else {
      // 主 URL：audio.beingfine.cn
      primaryUrl = '$_baseAudioUrl$audioUrl';
      // 备用 URL：七牛
      fallbackUrl = '$_qiniuResourceUrl$audioUrl';
    }

    final result = await _AudioDownloader.downloadFile(localPath, primaryUrl, fallbackUrl: fallbackUrl);

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

/// 便捷：播放 TTS 文本
Future<void> playTextAudio(String text, {double speed = 1.0}) {
  return TextAudioPlayer().playText(text, speed: speed);
}
