import '../../../data/user_database.dart';
import '../../../models/word.dart';
import '../../../repositories/new_word_repository_impl.dart';
import '../application/dictionary_new_word_writer.dart';

/// 基于 NewWordRepository 的生词本操作适配器。
///
/// 实现 [DictionaryNewWordWriter] 端口，封装生词添加/移除逻辑。
/// 依赖共享仓储 [NewWordRepositoryImpl]，不引入其他 feature 内部依赖。
///
/// 为支持同步的 [isNewWord] 查询，内部维护一个 ID 缓存，
/// 在 [toggleNewWord] 操作后自动更新。
class ServiceDictionaryNewWordWriter implements DictionaryNewWordWriter {
  ServiceDictionaryNewWordWriter({this._userDatabase});

  final UserDatabase? _userDatabase;

  UserDatabase get _db => _userDatabase ?? UserDatabase.instance;

  /// 生词 ID 缓存，用于同步查询。
  final Set<int> _newWordIdCache = {};

  /// 是否已完成首次加载。
  bool _initialized = false;

  /// 确保缓存已加载（幂等）。
  Future<void> _ensureLoaded() async {
    if (_initialized) return;
    _initialized = true;
    try {
      final repo = NewWordRepositoryImpl(_db);
      final words = await repo.getNewWords();
      _newWordIdCache
        ..clear()
        ..addAll(words.map((r) => r.wordId));
    } catch (_) {
      // 缓存加载失败不影响核心功能
    }
  }

  @override
  Future<bool> toggleNewWord(Word word, {String source = 'dictionary'}) async {
    await _ensureLoaded();
    final repo = NewWordRepositoryImpl(_db);
    final result = await repo.toggleNewWord(word, source: source);
    if (result) {
      _newWordIdCache.add(word.id);
    } else {
      _newWordIdCache.remove(word.id);
    }
    return result;
  }

  @override
  bool isNewWord(int wordId) {
    return _newWordIdCache.contains(wordId);
  }
}
