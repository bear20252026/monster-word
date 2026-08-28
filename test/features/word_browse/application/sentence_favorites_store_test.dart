import 'package:flutter_test/flutter_test.dart';
import 'package:word_app/features/word_browse/application/sentence_favorites_store.dart';
import 'package:word_app/models/sentence_models.dart';

/// 模拟 SentenceFavoritesStore 端口行为。
class _MockSentenceFavoritesStore implements SentenceFavoritesStore {
  final Map<String, bool> _favorites = {};
  final List<FavSentenceData> _records = [];

  void seed({required int wordId, required String sentenceId, bool favorite = false}) {
    _favorites['$wordId:$sentenceId'] = favorite;
  }

  void seedRecord(FavSentenceData record) => _records.add(record);

  @override
  Future<bool> isFavorite({required int wordId, required String sentenceId}) async =>
      _favorites['$wordId:$sentenceId'] ?? false;

  @override
  Future<bool> toggle({
    required int wordId,
    required String sentenceId,
    required String english,
    required String chinese,
    String source = '',
  }) async {
    final key = '$wordId:$sentenceId';
    final current = _favorites[key] ?? false;
    _favorites[key] = !current;
    return !current;
  }

  @override
  Future<List<FavSentenceData>> list() async => List.of(_records);

  @override
  Future<bool> remove({required int wordId, required String sentenceId}) async {
    final key = '$wordId:$sentenceId';
    final existed = _favorites.remove(key);
    return existed != null;
  }
}

void main() {
  group('SentenceFavoritesStore port contract', () {
    late _MockSentenceFavoritesStore store;

    setUp(() {
      store = _MockSentenceFavoritesStore();
    });

    test('isFavorite 在未收藏时返回 false', () async {
      expect(await store.isFavorite(wordId: 1, sentenceId: 's1'), isFalse);
    });

    test('toggle 切换收藏状态并返回新状态', () async {
      store.seed(wordId: 1, sentenceId: 's1', favorite: false);
      final result = await store.toggle(
        wordId: 1,
        sentenceId: 's1',
        english: 'Hello world',
        chinese: '你好世界',
      );
      expect(result, isTrue);
      expect(await store.isFavorite(wordId: 1, sentenceId: 's1'), isTrue);
    });

    test('toggle 连续调用两次恢复原状', () async {
      store.seed(wordId: 1, sentenceId: 's1', favorite: false);
      await store.toggle(wordId: 1, sentenceId: 's1', english: 'a', chinese: 'b');
      final second = await store.toggle(wordId: 1, sentenceId: 's1', english: 'a', chinese: 'b');
      expect(second, isFalse);
      expect(await store.isFavorite(wordId: 1, sentenceId: 's1'), isFalse);
    });

    test('remove 存在收藏时返回 true 并清除', () async {
      store.seed(wordId: 1, sentenceId: 's1', favorite: true);
      final result = await store.remove(wordId: 1, sentenceId: 's1');
      expect(result, isTrue);
      expect(await store.isFavorite(wordId: 1, sentenceId: 's1'), isFalse);
    });

    test('remove 不存在的收藏返回 false', () async {
      final result = await store.remove(wordId: 99, sentenceId: 'no-such');
      expect(result, isFalse);
    });

    test('list 返回全部收藏', () async {
      store.seedRecord(FavSentenceData(
        word: 'test',
        wordId: 1,
        sentenceId: 's1',
        sentenceData: SentenceData(sid: 's1', e: 'Test sentence', c: '测试句'),
        wordUsage: 'usage',
        updateTime: '20260828',
      ));
      store.seedRecord(FavSentenceData(
        word: 'test',
        wordId: 1,
        sentenceId: 's2',
        sentenceData: SentenceData(sid: 's2', e: 'Another sentence', c: '另一句'),
        wordUsage: 'usage',
        updateTime: '20260829',
      ));
      final records = await store.list();
      expect(records, hasLength(2));
      expect(records[0].sentenceId, 's1');
      expect(records[1].sentenceId, 's2');
    });
  });
}
