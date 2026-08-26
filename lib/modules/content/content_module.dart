// 内容模块：词书浏览、搜索、收藏
//
// 该模块包含：
// - LibSelectPage（词书选择页面）
// - BookWordsPage（词书内容页面）
// - SearchPage（搜索页面）
// - MyFavPage（收藏页面）
// - MyFavSentencePage（收藏句子页面）
// - DictionaryPage（字典页面）
//
// 依赖：
// - BookRepository（词书数据）
// - WordRepository（单词数据）

/// 内容模块配置
class ContentModule {
  ContentModule._();

  static void register(dynamic sl) {
    // BookRepository、WordRepository 已在 service_locator.dart 中注册
  }
}
