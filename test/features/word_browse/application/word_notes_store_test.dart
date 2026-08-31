import 'package:flutter_test/flutter_test.dart';
import 'package:word_app/features/word_browse/application/word_notes_store.dart';
import 'package:word_app/models/word_note.dart';

/// 模拟 WordNotesStore 端口行为。
class _MockWordNotesStore implements WordNotesStore {
  final List<WordNote> _notes = [];
  int _nextId = 1;

  @override
  Future<List<WordNote>> listForWord(int wordId) async => _notes.where((n) => n.wordId == wordId).toList();

  @override
  Future<void> add(WordNote note) async {
    _notes.add(note.copyWith(id: _nextId++));
  }

  @override
  Future<void> update(WordNote note) async {
    final index = _notes.indexWhere((n) => n.id == note.id);
    if (index != -1) _notes[index] = note;
  }

  @override
  Future<void> deleteById(int noteId) async {
    _notes.removeWhere((n) => n.id == noteId);
  }
}

void main() {
  group('WordNotesStore port contract', () {
    late _MockWordNotesStore store;

    setUp(() {
      store = _MockWordNotesStore();
    });

    test('listForWord 仅返回该词的笔记', () async {
      await store.add(WordNote(wordId: 1, word: 'hello', content: '你好'));
      await store.add(WordNote(wordId: 1, word: 'hello', content: '招呼'));
      await store.add(WordNote(wordId: 2, word: 'world', content: '世界'));

      final notes = await store.listForWord(1);
      expect(notes, hasLength(2));
      expect(notes.every((n) => n.wordId == 1), isTrue);
    });

    test('add 插入并分配 id', () async {
      final note = WordNote(wordId: 1, word: 'hello', content: '你好');
      await store.add(note);
      final notes = await store.listForWord(1);
      expect(notes, hasLength(1));
      expect(notes.first.id, isNotNull);
    });

    test('update 修改内容', () async {
      await store.add(WordNote(wordId: 1, word: 'hello', content: '你好'));
      final notes = await store.listForWord(1);
      final updated = notes.first.copyWith(content: '你好！更新版');
      await store.update(updated);
      final result = await store.listForWord(1);
      expect(result.first.content, '你好！更新版');
    });

    test('deleteById 移除指定笔记', () async {
      await store.add(WordNote(wordId: 1, word: 'hello', content: '你好'));
      await store.add(WordNote(wordId: 1, word: 'hello', content: '第二个'));
      final notes = await store.listForWord(1);
      await store.deleteById(notes.first.id!);
      final remaining = await store.listForWord(1);
      expect(remaining, hasLength(1));
    });

    test('deleteById 不存在的 id 不影响其他', () async {
      await store.add(WordNote(wordId: 1, word: 'hello', content: '你好'));
      await store.deleteById(999);
      final notes = await store.listForWord(1);
      expect(notes, hasLength(1));
    });

    test('listForWord 无笔记时返回空列表', () async {
      final notes = await store.listForWord(42);
      expect(notes, isEmpty);
    });
  });
}
