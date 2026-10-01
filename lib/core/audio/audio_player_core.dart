part of 'audio_players.dart';

// MwAudioPlayer 底层播放封装
// ============================================================
// MwAudioPlayer
// 根据 Android API 选择 SystemMediaPlayer / ExoMediaPlayer，
// Flutter 中统一使用 audioplayers。
// ============================================================

/// 音频播放封装
class MwAudioPlayer {
  final AudioPlayer _player = AudioPlayer();
  StreamSubscription? _playerStateSub;
  StreamSubscription? _processingStateSub;
  MediaPlayStateListener? playStateListener;
  String _currentFileName = '';
  bool _lock = false;

  /// Windows/Linux 桌面端：just_audio 无原生实现（历史无声根因），
  /// 改用 audioplayers（有 Windows 原生插件，随安装包分发）。
  /// 移动端保持 just_audio（锁屏控制等既有能力不变）。
  final bool _useAudioPlayersDesktop = Platform.isWindows || Platform.isLinux;
  ap.AudioPlayer? _apPlayerInstance;

  /// 惰性创建：纯 Dart 测试环境无 audioplayers 插件，构造期创建会抛
  ap.AudioPlayer get _apPlayer => _apPlayerInstance ??= ap.AudioPlayer();

  MwAudioPlayer() {
    debugLog('[MwAudioPlayer] Created new player instance');
    // 监听播放状态变化
    _playerStateSub = _player.playerStateStream.listen((playerState) {
      if (_currentFileName.isEmpty) return;
      debugLog('[MwAudioPlayer] Player state: playing=${playerState.playing}, fileName=$_currentFileName');
      if (playerState.playing) {
        playStateListener?.onPlayStart(_currentFileName);
      } else {
        playStateListener?.onPlayPause(_currentFileName);
      }
    });
    // 监听播放完成
    _processingStateSub = _player.processingStateStream.listen((state) {
      debugLog('[MwAudioPlayer] Processing state: $state for $_currentFileName');
      if (state == ProcessingState.completed) {
        playStateListener?.onPlayComplete(_currentFileName);
      }
    });
  }

  /// 播放 URL（play）- 带移动端错误处理
  Future<void> play(String url) async {
    if (_lock) {
      debugLog('[MwAudioPlayer] play() skipped - player locked');
      return;
    }
    _currentFileName = url;
    debugLog('[MwAudioPlayer] play() URL: $url');
    playStateListener?.onPlayStart(url);
    if (_useAudioPlayersDesktop) {
      try {
        await _apPlayer.stop();
        await _apPlayer.play(ap.UrlSource(url));
        debugLog('[MwAudioPlayer] desktop play() started successfully');
      } catch (e) {
        debugLog('[MwAudioPlayer] ERROR in desktop play(): $e');
        playStateListener?.onPlayError(url);
      }
      return;
    }
    try {
      await _player.stop(); // 先停止当前播放
      await _player.setUrl(url);
      await _player.play();
      debugLog('[MwAudioPlayer] play() started successfully');
    } catch (e) {
      debugLog('[MwAudioPlayer] ERROR in play(): $e');
      debugLog('[MwAudioPlayer] URL: $url');
      debugLog('[MwAudioPlayer] Stack trace: ${StackTrace.current}');
      playStateListener?.onPlayError(url);
    }
  }

  /// 播放本地文件（play(File, float)）- 带移动端错误处理
  Future<void> playFile(File file, {double speed = 1.0}) async {
    if (_lock) {
      debugLog('[MwAudioPlayer] playFile() skipped - player locked');
      return;
    }
    _currentFileName = p.basename(file.path);
    debugLog('[MwAudioPlayer] playFile() path: ${file.path}, speed: $speed');
    playStateListener?.onPlayStart(_currentFileName);
    if (_useAudioPlayersDesktop) {
      try {
        await _apPlayer.stop();
        if (speed != 1.0) await _apPlayer.setPlaybackRate(speed);
        await _apPlayer.play(ap.DeviceFileSource(file.path));
        debugLog('[MwAudioPlayer] desktop playFile() started successfully');
      } catch (e) {
        debugLog('[MwAudioPlayer] ERROR in desktop playFile(): $e');
        playStateListener?.onPlayError(_currentFileName);
      }
      return;
    }
    try {
      await _player.stop();
      await _player.setSpeed(speed);
      await _player.setFilePath(file.path);
      await _player.play();
      debugLog('[MwAudioPlayer] playFile() started successfully');
    } catch (e) {
      debugLog('[MwAudioPlayer] ERROR in playFile(): $e');
      debugLog('[MwAudioPlayer] File path: ${file.path}');
      debugLog('[MwAudioPlayer] Stack trace: ${StackTrace.current}');
      playStateListener?.onPlayError(_currentFileName);
    }
  }

  /// 播放本地文件路径
  Future<void> playFilePath(String filePath, {double speed = 1.0}) async {
    await playFile(File(filePath), speed: speed);
  }

  /// 停止（stop）
  Future<void> stop() async {
    try {
      await _player.stop();
    } catch (e) {
      debugLog('[MwAudioPlayer] stop() error (player may be disposed): $e');
    }
  }

  /// 暂停（pause）
  Future<void> pause() async {
    try {
      await _player.pause();
    } catch (e) {
      debugLog('[MwAudioPlayer] pause() error (player may be disposed): $e');
    }
    if (_currentFileName.isNotEmpty) {
      playStateListener?.onPlayPause(_currentFileName);
    }
  }

  /// 释放（release）—— 取消所有流订阅并释放播放器，防止内存泄漏
  Future<void> release() async {
    await _playerStateSub?.cancel();
    _playerStateSub = null;
    await _processingStateSub?.cancel();
    _processingStateSub = null;
    playStateListener = null;
    // MEM/C7：桌面端 audioplayers 实例持有 mpv/原生句柄，必须同步释放，
    // 否则任务管理器外堆常驻。先 stop 再 dispose，失败只打日志不抛。
    final apInstance = _apPlayerInstance;
    _apPlayerInstance = null;
    if (apInstance != null) {
      try {
        await apInstance.stop().timeout(const Duration(seconds: 2));
      } catch (e) {
        debugLog('[MwAudioPlayer] release() desktop stop error: $e');
      }
      try {
        await apInstance.dispose().timeout(const Duration(seconds: 2));
      } catch (e) {
        debugLog('[MwAudioPlayer] release() desktop dispose error: $e');
      }
    }
    try {
      // MEM：无平台插件时 just_audio dispose 可能挂起，限时以免卡死退出/测试。
      await _player.dispose().timeout(const Duration(seconds: 2));
    } catch (e) {
      debugLog('[MwAudioPlayer] release() dispose error: $e');
    }
  }

  /// 是否正在播放
  bool get isPlaying => _player.playerState.playing;

  /// 锁定播放（setLock）
  void setLock(bool lock) {
    _lock = lock;
  }

  /// 设置监听（setPlayStateListener）
  void setPlayStateListener(MediaPlayStateListener? listener) {
    playStateListener = listener;
  }
}
