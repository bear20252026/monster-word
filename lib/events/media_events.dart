// 由 Claude 团队生成 | 移植自 v3.2 events/ 媒体/播放相关事件
// 媒体模块事件：泛听播放状态

// ============================================================
// ExtensivePlayStateEvent — 泛听播放状态事件
// 原版：events/ExtensivePlayStateEvent.java
// 触发源：播放模块 → 监听者：泛听界面
// 状态常量：PLAY_STATE_PAUSE = 1
// ============================================================
class ExtensivePlayStateEvent {
  static const int playStatePause = 1;
  static const int playStatePlaying = 0;
  static const int playStateStop = 2;

  final int newState;
  const ExtensivePlayStateEvent({required this.newState});

  bool get isPaused => newState == playStatePause;
  bool get isPlaying => newState == playStatePlaying;
  bool get isStopped => newState == playStateStop;
}
