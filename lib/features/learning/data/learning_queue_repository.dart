import '../../../data/wordbook_database.dart' show WordBookDatabase;
import '../../../models/book.dart';
import '../../../models/word.dart';
import '../../../repositories/fav_repository.dart';

/// 学习队列所需的词库读取端口。
abstract interface class LearningQueueWordSource {
  Future<List<Word>> getWordsByBook(int bookId, {required int limit, required int offset});

  Future<List<Word>> getWordsByNames(Iterable<String> words);
}

/// 基于既有词库数据库的学习队列词源适配器。
class WordBookLearningQueueWordSource implements LearningQueueWordSource {
  WordBookLearningQueueWordSource({required WordBookDatabase database}) : _database = database;

  final WordBookDatabase _database;

  @override
  Future<List<Word>> getWordsByBook(int bookId, {required int limit, required int offset}) {
    return _database.getWordsByBook(bookId, limit: limit, offset: offset);
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
  LearningQueueRepository({required LearningQueueWordSource wordSource, required FavRepository favRepository})
    : _wordSource = wordSource,
      _favRepository = favRepository;

  final LearningQueueWordSource _wordSource;
  final FavRepository _favRepository;

  Future<List<Word>> loadBook(Book book, {required int limit, required bool shuffle}) async {
    final queue = await _wordSource.getWordsByBook(book.id, limit: limit, offset: 0);
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

  Future<List<Word>> loadWordsByBook(int bookId) {
    return _wordSource.getWordsByBook(bookId, limit: 1000, offset: 0);
  }
}
