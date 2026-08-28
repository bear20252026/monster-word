import '../../../models/word_note.dart';
import '../../../repositories/note_repository.dart';
import '../application/word_notes_store.dart';

/// 基于既有笔记仓储的词条浏览笔记适配器。
///
/// 适配器不缓存或复制笔记数据，确保 [NoteRepository] 继续是唯一持久化事实来源。
class RepositoryWordNotesStore implements WordNotesStore {
  RepositoryWordNotesStore({required this._repository});

  final NoteRepository _repository;

  @override
  Future<List<WordNote>> listForWord(int wordId) => _repository.getNotesByWord(wordId);

  @override
  Future<void> add(WordNote note) async {
    await _repository.insertNote(note);
  }

  @override
  Future<void> update(WordNote note) async {
    await _repository.updateNote(note);
  }

  @override
  Future<void> deleteById(int noteId) async {
    await _repository.deleteNote(noteId);
  }
}
