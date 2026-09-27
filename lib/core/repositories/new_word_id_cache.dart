// 由 Claude 团队生成 | Monster Word App

// 生词本 ID 共享缓存（审计 I34）：词典域的同步 isNewWord（星标即时亮灭）
// 与学习域的生词写入此前各自维护状态、互不通知——学习域移除生词后，
// 词典页星标保持陈旧直到重启。本单例是两域共同的缓存真相：
// 任何写路径（词典 toggle / 学习 toggle / remove）都必须经 mark() 维护。
import 'package:word_app/core/repositories/new_word_repository.dart';
import 'package:word_app/core/utils/swallowed_error_report.dart';

class NewWordIdCache {
  NewWordIdCache._();
  static final NewWordIdCache instance = NewWordIdCache._();

  final Set<int> _ids = <int>{};
  Future<void>? _loading;

  /// 预热（幂等；并发调用共享同一次加载——修复词典域旧实现
  /// "加载完成前置位 _initialized，并发首查拿到空缓存"的缺陷）。
  Future<void> ensureLoaded(NewWordRepository repo) => _loading ??= _loadInner(repo);

  Future<void> _loadInner(NewWordRepository repo) async {
    try {
      final words = await repo.getNewWords();
      _ids
        ..clear()
        ..addAll(words.map((r) => r.wordId));
    } catch (e, s) {
      // M9：缓存加载失败可降级，但必须可观测（生词同步查询可能失真）。
      reportSwallowedError('new-word id cache load', e, s);
      _loading = null; // 失败允许下次访问重试
    }
  }

  /// 同步判重（仅供缓存预热后的即时读；冷启动首查前为空集合语义）。
  bool contains(int wordId) => _ids.contains(wordId);

  /// 写后维护：学习域与词典域的任何生词写路径都必须调用，
  /// 保证两域同步读一致（DB 是事实来源，预热重载会覆盖任何 mark）。
  void mark(int wordId, {required bool added}) => added ? _ids.add(wordId) : _ids.remove(wordId);
}
