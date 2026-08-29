import '../../../core/di/service_locator.dart';
import '../../../models/word_note.dart';
import 'package:word_app/core/repositories/note_repository.dart';
import '../application/word_notes_store.dart';

/// 基于既有笔记仓储的词条浏览笔记适配器。
///
/// 适配器不缓存或复制笔记数据，确保 [NoteRepository] 继续是唯一持久化事实来源。
class RepositoryWordNotesStore implements WordNotesStore {
  /// 从 service_locator 自动解析依赖。
  factory RepositoryWordNotesStore.fromServiceLocator() =>
      RepositoryWordNotesStore._(sl<NoteRepository>());

  RepositoryWordNotesStore._(this._repository);

  /// 显式注入（供测试覆盖）。
  RepositoryWordNotesStore(NoteRepository repository)
      : _repository = repository;

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
