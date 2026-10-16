import 'package:word_app/core/infrastructure/wordbook_database.dart' show WordBookDatabase;
import 'package:word_app/models/book.dart';
import 'package:word_app/models/word.dart';
import 'package:word_app/core/repositories/fav_repository.dart';

/// 学习队列所需的词库读取端口。
abstract interface class LearningQueueWordSource {
  Future<List<Word>> getWordsByBook(int bookId, {required int limit, required int offset, bool randomOrder = false});

  /// 随机取样 [limit] 个词（R3-D02：两步式，取代 SQL `ORDER BY RANDOM()`）。
  Future<List<Word>> getRandomWordsByBook(int bookId, {required int limit});

  Future<List<Word>> getWordsByNames(Iterable<String> words);
}

/// 基于既有词库数据库的学习队列词源适配器。
class WordBookLearningQueueWordSource implements LearningQueueWordSource {
  WordBookLearningQueueWordSource({required this._database});

  final WordBookDatabase _database;

  @override
  Future<List<Word>> getWordsByBook(int bookId, {required int limit, required int offset, bool randomOrder = false}) {
    return _database.getWordsByBook(bookId, limit: limit, offset: offset, randomOrder: randomOrder);
  }

  @override
  Future<List<Word>> getRandomWordsByBook(int bookId, {required int limit}) {
    return _database.getRandomWordsByBook(bookId, limit: limit);
  }

  @override
  Future<List<Word>> getWordsByNames(Iterable<String> words) {
    return _database.getWordsByNames(words.toSet());
  }
}

/// 学习会话的队列加载命令。
///
/// 该仓储集中词书读取、收藏词解析、当前队列回退及可选乱序规则；它不保存会话索引，
/// 也不决定 Leitner 或 FSRS 评分行为。
class LearningQueueRepository {
  LearningQueueRepository({required this._wordSource, required this._favRepository});

  final LearningQueueWordSource _wordSource;
  final FavRepository _favRepository;

  Future<List<Word>> loadBook(Book book, {required int limit, required bool shuffle}) async {
    // shuffle=true 时在数据层等概率随机取样（R3-D02：两步式采样，不再用
    // SQL `ORDER BY RANDOM()` 把整本书物化进临时 B-tree）。
    final queue = shuffle
        ? await _wordSource.getRandomWordsByBook(book.id, limit: limit)
        : await _wordSource.getWordsByBook(book.id, limit: limit, offset: 0);
    if (shuffle) queue.shuffle();
    return queue;
  }

  Future<List<Word>> loadFavoriteWords({required Iterable<Word> currentQueue}) async {
    final favorites = await _favRepository.getFavoriteWords();
    if (favorites.isEmpty) return const [];

    final words = await _wordSource.getWordsByNames(favorites);
    if (words.isNotEmpty) return words;
    return currentQueue.where((word) => favorites.contains(word.word)).toList(growable: false);
  }
}
