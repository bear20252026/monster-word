import 'package:flutter_test/flutter_test.dart';
import 'package:word_app/core/parsers/example_parser.dart';
import 'package:word_app/features/dictionary/application/dictionary_content_reader.dart';
import 'package:word_app/features/dictionary/application/dictionary_favorite_writer.dart';
import 'package:word_app/features/dictionary/application/dictionary_new_word_writer.dart';
import 'package:word_app/features/dictionary/application/dictionary_search_reader.dart';
import 'package:word_app/features/dictionary/presentation/dictionary_detail_state.dart';
import 'package:word_app/models/word.dart';

// ── Mock 实现 ──────────────────────────────────────────────

class _FakeSearchReader implements DictionarySearchReader {
  _FakeSearchReader({this.results = const []});
  final List<Word> results;

  @override
  Future<List<Word>> searchByPrefix(String prefix) async => results;

  @override
  Future<List<Word>> searchFuzzy(String query) async => results;

  @override
  Future<List<Word>> searchSmart(String query) async => results;
}

class _FakeContentReader implements DictionaryContentReader {
  _FakeContentReader({
    this.derived = const [],
    this.synonyms = const [],
    this.examples = const [],
    this.realExamSentences = const [],
  });

  final List<Word> derived;
  final List<Word> synonyms;
  final List<ExampleSentence> examples;
  final List<Map<String, String>> realExamSentences;

  @override
  Future<List<Word>> getDerivedWords(String word) async => derived;

  @override
  Future<List<Word>> getSynonyms(String word) async => synonyms;

  @override
  Future<List<ExampleSentence>> getExamExamples(String word) async => examples;

  @override
  Future<List<Map<String, String>>> getRealExamSentences(String word) async => realExamSentences;

  @override
  Future<List<CollinsSense>> getCollinsSenses(String word) async => const [];
}

class _FakeFavoriteWriter implements DictionaryFavoriteWriter {
  final Set<String> _favorites = {};

  @override
  Future<bool> toggleFavorite(String word) async {
    if (_favorites.contains(word)) {
      _favorites.remove(word);
      return false;
    } else {
      _favorites.add(word);
      return true;
    }
  }

  @override
  bool isFavorite(String word) => _favorites.contains(word);

  @override
  Future<Set<String>> getFavoriteWords() async => Set.from(_favorites);
}

class _FakeNewWordWriter implements DictionaryNewWordWriter {
  final Set<int> _newWords = {};

  @override
  Future<bool> toggleNewWord(Word word, {String source = 'dictionary'}) async {
    if (_newWords.contains(word.id)) {
      _newWords.remove(word.id);
      return false;
    } else {
      _newWords.add(word.id);
      return true;
    }
  }

  @override
  bool isNewWord(int wordId) => _newWords.contains(wordId);
}

// ── 测试 ──────────────────────────────────────────────────

void main() {
  Word makeTestWord({
    int id = 1,
    String word = 'example',
    String usPron = '/ɪɡˈzæmpəl/',
    String ukPron = '/ɪɡˈzɑːmpəl/',
    String audioUrls = 'uk:uk.mp3,us:us.mp3',
    String? interpretOverride,
  }) {
    return Word(
      id: id,
      word: word,
      interpret: interpretOverride ?? '[{"t":"n.","def":[{"cn":"例子"},{"cn":"范例"}]}]',
      usPron: usPron,
      ukPron: ukPron,
      audioUrls: audioUrls,
    );
  }

  DictionaryDetailState makeTestState({
    List<Word> searchResults = const [],
    List<Word> derived = const [],
    List<Word> synonyms = const [],
    List<ExampleSentence> examples = const [],
    List<Map<String, String>> realExamSentences = const [],
  }) {
    return DictionaryDetailState(
      searchReader: _FakeSearchReader(results: searchResults),
      contentReader: _FakeContentReader(
        derived: derived,
        synonyms: synonyms,
        examples: examples,
        realExamSentences: realExamSentences,
      ),
      favoriteWriter: _FakeFavoriteWriter(),
      newWordWriter: _FakeNewWordWriter(),
    );
  }

  group('DictionaryDetailState', () {
    test('loadWord 正确加载单词并解析音标与释义', () async {
      final state = makeTestState();
      final word = makeTestWord();

      await state.loadWord(word);

      expect(state.word, word);
      expect(state.loading, isFalse);
      expect(state.error, isNull);
      expect(state.phonetic, isNotNull);
      expect(state.phonetic!.english, '/ɪɡˈzɑːmpəl/');
      expect(state.phonetic!.american, '/ɪɡˈzæmpəl/');
      expect(state.phonetic!.ukAudio, 'uk.mp3');
      expect(state.phonetic!.usAudio, 'us.mp3');
      expect(state.definitions, hasLength(1));
      expect(state.definitions[0].partOfSpeech, 'n.');
      expect(state.definitions[0].definitions, ['例子', '范例']);
    });

    test('loadWord 异步加载派生词与近义词', () async {
      final derived = [makeTestWord(id: 2, word: 'examine')];
      final synonyms = [makeTestWord(id: 3, word: 'instance')];
      final state = makeTestState(derived: derived, synonyms: synonyms);
      final word = makeTestWord();

      await state.loadWord(word);

      expect(state.derivedWords, hasLength(1));
      expect(state.derivedWords.first.word, 'examine');
      expect(state.synonyms, hasLength(1));
      expect(state.synonyms.first.word, 'instance');
    });

    test('toggleFavorite 切换收藏状态', () async {
      final state = makeTestState();
      await state.loadWord(makeTestWord());

      expect(state.isFavorite, isFalse);

      await state.toggleFavorite();
      expect(state.isFavorite, isTrue);

      await state.toggleFavorite();
      expect(state.isFavorite, isFalse);
    });

    test('toggleNewWord 切换生词状态', () async {
      final state = makeTestState();
      await state.loadWord(makeTestWord(id: 100));

      expect(state.isNewWord, isFalse);

      await state.toggleNewWord();
      expect(state.isNewWord, isTrue);

      await state.toggleNewWord();
      expect(state.isNewWord, isFalse);
    });

    test('loadWord 在无音频字符串时回退到音标字段', () async {
      final state = makeTestState();
      final word = makeTestWord(audioUrls: '');

      await state.loadWord(word);

      expect(state.phonetic, isNotNull);
      expect(state.phonetic!.english, '/ɪɡˈzɑːmpəl/');
      expect(state.phonetic!.ukAudio, isNull);
    });

    test('loadWord 在无音标和音频时 phonetic 为 null', () async {
      final state = makeTestState();
      final word = makeTestWord(usPron: '', ukPron: '', audioUrls: '');

      await state.loadWord(word);

      expect(state.phonetic, isNull);
    });

    test('search 缓存搜索结果', () async {
      final results = [makeTestWord(id: 10, word: 'test')];
      final state = makeTestState(searchResults: results);

      await state.search('test');

      expect(state.searchResults, hasLength(1));
      expect(state.searchResults.first.word, 'test');
      expect(state.searching, isFalse);
    });
  });
}
