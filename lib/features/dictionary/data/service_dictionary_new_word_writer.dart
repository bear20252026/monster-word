import 'package:word_app/core/repositories/new_word_id_cache.dart';
import 'package:word_app/core/repositories/new_word_repository.dart';
import 'package:word_app/models/word.dart';
import 'package:word_app/features/dictionary/application/dictionary_new_word_writer.dart';

/// 基于 NewWordRepository 的生词本操作适配器。
///
/// 实现 [DictionaryNewWordWriter] 端口，封装生词添加/移除逻辑。
/// 依赖共享仓储 [NewWordRepository]，不引入其他 feature 内部依赖。
///
/// 审计 I34：同步 [isNewWord] 的 ID 缓存收敛到共享单例
/// [NewWordIdCache]（学习域写入路径同源维护），不再自持私有缓存——
/// 此前学习域移除生词后本域星标陈旧到重启。
///
/// 第四轮审计 M2（2026-11-17）：仓储实例由组合根注入 DI 单例，不再自建
/// `NewWordRepositoryImpl(userDatabase)`——此前本适配器与 sl 单例是**两个
/// 实例**，实例级 _toggleQueue 串行闸互不互斥，词典域与学习域并发 toggle
/// 同一词时 check-then-act 竞态复活（I34 只收敛了读缓存，写闸仍双轨）。
class ServiceDictionaryNewWordWriter implements DictionaryNewWordWriter {
  ServiceDictionaryNewWordWriter({required NewWordRepository repository}) : _repo = repository;

  final NewWordRepository _repo;

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
