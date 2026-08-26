// 播放器模块：音频播放、沉浸刷词、听写、拼写
//
// 该模块包含：
// - ListeningPlayerPage（听音播放页面）
// - DictationSessionPage（听写练习页面）
// - QuickSpellPage（快速拼写页面）
// - ImmersiveSwipePage（沉浸刷词页面）
// - AudioService（音频播放服务）
//
// 依赖：
// - AudioService（全局音频服务）

/// 播放器模块配置
class PlayerModule {
  PlayerModule._();

  static void register(dynamic sl) {
    // AudioService 已在 service_locator.dart 中注册
  }
}
