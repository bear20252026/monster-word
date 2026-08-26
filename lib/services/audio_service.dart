// 由 Claude 团队生成 | Monster Word App
// AudioService — 音频播放控制

/// 音频播放服务接口
/// 
/// 抽象音频播放功能，UI 层不直接依赖 AudioPlayers 具体实现。
abstract class AudioService {
  /// 播放单词发音
  Future<void> playWordAudio(String word, {String accent = 'us'});

  /// 播放音频 URL
  Future<void> playFromUrl(String url);

  /// 停止播放
  Future<void> stop();

  /// 是否正在播放
  bool get isPlaying;
}
