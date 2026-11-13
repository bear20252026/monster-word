// P2-14（架构审计 2026-11-12）：DictionaryDetailState 边界分支补测。
// 原 dictionary_detail_state_test 只测正常路径；此处补：
// loadByWordString 空结果/命中、search 代际防护（MW-37）与纯空白清空、
// loadWord 端口抛错时置 error 且复位 loading 不崩溃。
import 'package:flutter_test/flutter_test.dart';
import 'package:word_app/core/parsers/example_parser.dart';
import 'package:word_app/features/dictionary/application/dictionary_content_reader.dart';
import 'package:word_app/features/dictionary/application/dictionary_favorite_writer.dart';
import 'package:word_app/features/dictionary/application/dictionary_new_word_writer.dart';
import 'package:word_app/features/dictionary/application/dictionary_search_reader.dart';
import 'package:word_app/features/dictionary/presentation/dictionary_detail_state.dart';
import 'package:word_app/models/word.dart';

/// 可控搜索 fake：按查询返回不同结果，支持延迟与抛错，用于代际防护测试。
class _ControllableSearchReader implements DictionarySearchReader {
  _ControllableSearchReader();

  final Map<String, List<Word>> byQuery = {};
  final Map<String, Duration> delays = {};
  final Set<String> throwOn = {};
  final List<String> calls = [];

  @override
  Future<List<Word>> searchSmart(String query) async {
    calls.add(query);
    final delay = delays[query];
    if (delay != null) await Future<void>.delayed(delay);
    if (throwOn.contains(query)) throw StateError('search boom: $query');
    return byQuery[query] ?? const [];
  }

  @override
  Future<List<Word>> searchByPrefix(String prefix) async => byQuery[prefix] ?? const [];

  @override
  Future<List<Word>> searchFuzzy(String query) async => byQuery[query] ?? const [];
}

class _EmptyContentReader implements DictionaryContentReader {
  @override
  Future<List<Word>> getDerivedWords(String word) async => const [];
  @override
  Future<List<Word>> getSynonyms(String word) async => const [];
  @override
  Future<List<ExampleSentence>> getExamExamples(String word) async => const [];
  @override
  Future<List<Map<String, String>>> getRealExamSentences(String word) async => const [];
  @override
  Future<List<CollinsSense>> getCollinsSenses(String word) async => const [];
}

/// 收藏状态读取即抛错的 fake，用于 loadWord 错误分支。
class _ThrowingFavoriteWriter implements DictionaryFavoriteWriter {
  @override
  bool isFavorite(String word) => throw StateError('favorite boom');
  @override
  Future<bool> toggleFavorite(String word) async => false;
  @override
  Future<Set<String>> getFavoriteWords() async => const {};
}

class _NoopFavoriteWriter implements DictionaryFavoriteWriter {
  @override
  bool isFavorite(String word) => false;
  @override
  Future<bool> toggleFavorite(String word) async => false;
  @override
  Future<Set<String>> getFavoriteWords() async => const {};
}

class _NoopNewWordWriter implements DictionaryNewWordWriter {
  @override
  bool isNewWord(int wordId) => false;
  @override
  Future<bool> toggleNewWord(Word word, {String source = 'dictionary'}) async => false;
}

Word _word(int id, String text) => Word(id: id, word: text, interpret: '[{"t":"n.","def":[{"cn":"释义"}]}]');

DictionaryDetailState _state(_ControllableSearchReader search, {DictionaryFavoriteWriter? fav}) {
  return DictionaryDetailState(
    searchReader: search,
    contentReader: _EmptyContentReader(),
    favoriteWriter: fav ?? _NoopFavoriteWriter(),
    newWordWriter: _NoopNewWordWriter(),
  );
}

void main() {
  group('loadByWordString', () {
    test('搜索空结果返回 false 且复位 searching', () async {
      final search = _ControllableSearchReader();
      final state = _state(search);

      final ok = await state.loadByWordString('missing');

      expect(ok, isFalse);
      expect(state.searching, isFalse);
      expect(state.word, isNull);
    });

    test('命中首个结果并加载详情，返回 true', () async {
      final search = _ControllableSearchReader()..byQuery['apple'] = [_word(1, 'apple'), _word(2, 'applet')];
      final state = _state(search);

      final ok = await state.loadByWordString('apple');

      expect(ok, isTrue);
      expect(state.word?.word, 'apple');
      expect(state.searching, isFalse);
      expect(state.loading, isFalse);
    });
  });

  group('search 代际防护（MW-37）', () {
    test('迟到的旧响应被丢弃，不覆盖新结果', () async {
      final search = _ControllableSearchReader()
        ..byQuery['old'] = [_word(1, 'old')]
        ..byQuery['new'] = [_word(2, 'new')]
        ..delays['old'] = const Duration(milliseconds: 60);
      final state = _state(search);

      // 先发旧查询（慢），再发新查询（快）；旧响应迟到时须被整体丢弃。
      final oldFuture = state.search('old');
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await state.search('new');
      await oldFuture;

      expect(state.searchResults.map((w) => w.word), ['new']);
      expect(state.searching, isFalse);
    });

    test('纯空白输入清空结果且不复位 searching 标志外的状态', () async {
      final search = _ControllableSearchReader()..byQuery['x'] = [_word(1, 'x')];
      final state = _state(search);
      await state.search('x');
      expect(state.searchResults, hasLength(1));

      await state.search('   ');

      expect(state.searchResults, isEmpty);
      expect(state.searching, isFalse);
      expect(search.calls, ['x'], reason: '纯空白不发起搜索请求');
    });

    test('搜索抛错时复位 searching（异常外抛由调用方接住）', () async {
      final search = _ControllableSearchReader()..throwOn.add('boom');
      final state = _state(search);

      // search 无 catch：异常外抛，但 finally 保证 searching 复位（不卡在搜索中）。
      await expectLater(state.search('boom'), throwsA(isA<StateError>()));
      expect(state.searching, isFalse);
    });
  });

  group('loadWord 错误分支', () {
    test('端口抛错时置 error、复位 loading，不崩溃', () async {
      final search = _ControllableSearchReader();
      final state = _state(search, fav: _ThrowingFavoriteWriter());

      await state.loadWord(_word(1, 'apple'));

      expect(state.error, isNotNull);
      expect(state.error, contains('favorite boom'));
      expect(state.loading, isFalse);
    });
  });
}
