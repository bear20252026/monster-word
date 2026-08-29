/// Port: mastered-words mutation (toggle only — reads go via MasteredWordsReader).
/// Presentation states depend on this abstraction, not on
/// `lib/repositories/mastered_repository.dart` directly.
abstract class MasteredWriterPort {
  Future<void> toggleMastered(String word);
}
