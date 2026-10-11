/// Port: mastered-words mutation (toggle only — reads go via MasteredWordsReader).
/// Presentation states depend on this abstraction, not on
/// `lib/core/repositories/` 下的实现 directly（历史路径 lib/repositories/ 已不存在，2026-10 审计修注）
abstract class MasteredWriterPort {
  Future<void> toggleMastered(String word);
}
