// 学习模块：整合学习相关的页面、服务和状态
//
// 该模块包含：
// - LearnPage（4选1测验页面）
// - LearnSession（学习会话页面）
// - WordDetailPage（单词详情页面）
// - LearnService（学习业务逻辑）
// - LearnState（学习状态管理）
//
// 依赖：
// - BookRepository（词书数据）
// - WordRepository（单词数据）
// - AudioService（音频播放）

/// 学习模块配置
///
/// 在 App 启动时通过 ServiceLocator 注册：
/// ```dart
/// LearnModule.register(sl);
/// ```
class LearnModule {
  LearnModule._();

  /// 注册学习模块的所有服务到 DI 容器
  static void register(dynamic sl) {
    // LearnService 已在 service_locator.dart 中注册
    // 此处可扩展：注册学习模块特有的工厂/作用域
  }
}
