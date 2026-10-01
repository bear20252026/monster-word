import 'package:word_app/core/infrastructure/user_database.dart';
import 'package:word_app/core/repositories/new_word_id_cache.dart';
import 'package:word_app/core/repositories/new_word_repository_impl.dart';
import 'package:word_app/models/word.dart';
import 'package:word_app/features/dictionary/application/dictionary_new_word_writer.dart';

/// 基于 NewWordRepository 的生词本操作适配器。
///
/// 实现 [DictionaryNewWordWriter] 端口，封装生词添加/移除逻辑。
/// 依赖共享仓储 [NewWordRepositoryImpl]，不引入其他 feature 内部依赖。
///
/// 审计 I34：同步 [isNewWord] 的 ID 缓存收敛到共享单例
/// [NewWordIdCache]（学习域写入路径同源维护），不再自持私有缓存——
/// 此前学习域移除生词后本域星标陈旧到重启。
class ServiceDictionaryNewWordWriter implements DictionaryNewWordWriter {
  ServiceDictionaryNewWordWriter({required this.userDatabase});

  final UserDatabase userDatabase;

  NewWordRepositoryImpl get _repo => NewWordRepositoryImpl(userDatabase);

  @override
  Future<bool> toggleNewWord(Word word, {String source = 'dictionary'}) async {
    await NewWordIdCache.instance.ensureLoaded(_repo);
    final result = await _repo.toggleNewWord(word, source: source);
    NewWordIdCache.instance.mark(word.id, added: result);
    return result;
  }

  @override
  bool isNewWord(int wordId) {
    return NewWordIdCache.instance.contains(wordId);
  }
}
