part of 'audio_players.dart';

// 播放回调接口层
// ============================================================
// 接口层
// ============================================================

/// 播放状态监听（MediaPlayStateListener 接口）
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
  }) : onPlayStartCb = onPlayStart,
       onPlayPauseCb = onPlayPause,
       onPlayCompleteCb = onPlayComplete,
       onPlayErrorCb = onPlayError;

  void onPlayStart(String url) => onPlayStartCb?.call(url);
  void onPlayPause(String url) => onPlayPauseCb?.call(url);
  void onPlayComplete(String url) => onPlayCompleteCb?.call(url);
  void onPlayError(String url) => onPlayErrorCb?.call(url);
}

/// 播放监听（PlayAudioListener，完整 8 个回调）
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
