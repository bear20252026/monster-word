import 'package:flutter_test/flutter_test.dart';
import 'package:word_app/features/word_browse/data/repository_sentence_favorites_store.dart';
import 'package:word_app/models/sentence_models.dart';
import 'package:word_app/features/word_browse/data/repository_word_notes_store.dart';
import 'package:word_app/models/word_note.dart';
import 'package:word_app/repositories/fav_repository.dart';
import 'package:word_app/repositories/note_repository.dart';

void main() {
  group('RepositoryWordNotesStore', () {
    test('reads and writes through the existing note repository', () async {
      final note = WordNote(id: 9, wordId: 7, word: 'learn', content: '记忆提示');
      final repository = _FakeNoteRepository(notes: [note]);
      final store = RepositoryWordNotesStore(repository: repository);

      expect(await store.listForWord(7), same(repository.notes));

      await store.add(note);
      await store.update(note.copyWith(content: '已更新'));
      await store.deleteById(9);

      expect(repository.inserted, same(note));
      expect(repository.updated?.content, '已更新');
      expect(repository.deletedId, 9);
    });
  });

  group('RepositorySentenceFavoritesStore', () {
    test('preserves sentence identity and payload when delegating', () async {
      final repository = _FakeFavRepository();
      final store = RepositorySentenceFavoritesStore(repository: repository);

      repository.favorite = true;
      expect(await store.isFavorite(wordId: 7, sentenceId: 'sentence-1'), isTrue);

      await store.toggle(
        wordId: 7,
        sentenceId: 'sentence-1',
        english: 'Learn every day.',
        chinese: '每天学习。',
        source: 'example',
      );

      expect(repository.lastToggle, {
        'wordId': 7,
        'sentenceId': 'sentence-1',
        'english': 'Learn every day.',
        'chinese': '每天学习。',
        'source': 'example',
      });
    });

    test('maps persisted sentence data and delegates removal', () async {
      final repository = _FakeFavRepository()
        ..records = [
          {
            'word': 'learn',
            'wordId': 7,
            'sentenceId': 'sentence-1',
            'sentenceData': SentenceData(sid: 'sentence-1', e: 'Learn every day.', c: '每天学习。'),
            'wordUsage': 'study',
            'updateTime': '20260828010101',
            'type': 0,
          },
        ];
      final store = RepositorySentenceFavoritesStore(repository: repository);

      final sentences = await store.list();
      expect(sentences.single.word, 'learn');
      expect(sentences.single.sentenceData?.e, 'Learn every day.');
      expect(await store.remove(wordId: 7, sentenceId: 'sentence-1'), isTrue);
      expect(repository.removed, {'wordId': 7, 'sentenceId': 'sentence-1'});
    });
  });
}

class _FakeNoteRepository implements NoteRepository {
  _FakeNoteRepository({required this.notes});

  final List<WordNote> notes;
  WordNote? inserted;
  WordNote? updated;
  int? deletedId;

  @override
  Future<int> addFavorite(int wordId) async => wordId;

  @override
  Future<int> addNote(int wordId, String content, {String word = ''}) async => wordId;

  @override
  Future<int> deleteNote(int noteId) async {
    deletedId = noteId;
    return 1;
  }

  @override
  Future<List<Map<String, dynamic>>> getFavorites() async => const [];

  @override
  Future<List<WordNote>> getNotesByWord(int wordId) async => notes;

  @override
  Future<int> insertNote(WordNote note) async {
    inserted = note;
    return note.id ?? 1;
  }

  @override
  Future<bool> isFavorite(int wordId) async => false;

  @override
  Future<int> removeFavorite(int wordId) async => wordId;

  @override
  Future<int> updateNote(WordNote note) async {
    updated = note;
    return note.id ?? 1;
  }
}

class _FakeFavRepository implements FavRepository {
  bool favorite = false;
  Map<String, Object>? lastToggle;
  List<Map<String, dynamic>> records = [];
  Map<String, Object>? removed;

  @override
  int get favoriteCount => 0;

  @override
  int get favoriteSentenceCount => favorite ? 1 : 0;

  @override
  Future<void> addFavorite(String word) async {}

  @override
  Future<bool> addFavoriteSentence({
    required int wordId,
    required String sentenceId,
    required String english,
    required String chinese,
    String source = '',
  }) async => true;

  @override
  Future<Set<String>> getFavoriteWords() async => const {};

  @override
  Future<List<Map<String, dynamic>>> getFavoriteSentences() async => records;

  @override
  bool isFavorite(String word) => false;

  @override
  Future<bool> isFavoriteSentence(int wordId, String sentenceId) async => favorite;

  @override
  Future<void> removeFavorite(String word) async {}

  @override
  Future<bool> removeFavoriteSentence(int wordId, String sentenceId) async {
    removed = {'wordId': wordId, 'sentenceId': sentenceId};
    return true;
  }

  @override
  Future<void> toggleFavorite(String word) async {}

  @override
  Future<bool> toggleFavoriteSentence({
    required int wordId,
    required String sentenceId,
    required String english,
    required String chinese,
    String source = '',
  }) async {
    lastToggle = {'wordId': wordId, 'sentenceId': sentenceId, 'english': english, 'chinese': chinese, 'source': source};
    favorite = !favorite;
    return favorite;
  }
}
