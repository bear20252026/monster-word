/// 随身听（泛听）播放模式：从词书单词中按所选模式生成听音序列。
///
/// 由 book 功能域「扩展模式选择页」与 learning 功能域「随身听页面」共享，并被
/// app/router 的 listening_player 路由用于解析 modeIndex。作为纯值类型放置在
/// core/ 下，避免跨功能 (book -> learning) 的 R4 依赖，同时保持各功能只依赖契约。
enum ListeningMode {
  wordOnly, // 仅单词
  wordMeaning, // 单词+释义
  meaningWord, // 释义+单词
  wordExample, // 单词+例句
}
