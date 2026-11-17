// 会话四选一「额外干扰词池」共享编排（结构修复步骤3，2026-11-16）。
//
// 背景：LearningSessionState 与 ReviewSessionState 各自有一份逐行同构的
// _ensureExtraChoicePool（词库随机取 24 真实词扩充候选池，首题异步加载、就绪后
// 再生一次、其后复用；换局重置）。架构评审指出这是 presentation 层重复编排，
// 抽到 application 共享，State 只保留 notifyListeners 投影。
//
// 行为与原实现完全一致：repository 为空或已在加载则跳过；取样失败静默降级
// （宁少勿假，退化为仅会话队列候选）；就绪回调由 State 接「再生+通知」。
import 'package:word_app/core/application/word_lookup_reader.dart';
import 'package:word_app/models/word.dart';

class ExtraChoicePool {
  ExtraChoicePool(this._onReady, {required this.repository});

  /// 词库只读端口（可选）：为空时不扩充候选（宁少勿假）。
  final WordLookupReader? repository;
  final void Function() _onReady;

  List<Word> _words = const [];
  Future<void>? _load;

  /// 第三轮 T28：世代号——reset 置 _load=null 但旧 Future 的 then 仍会执行，
  /// 旧响应迟到可覆盖新 load 结果（换书后干扰词短暂用旧批次）。每次 reset
  /// 递增世代，then 回调比对世代不符即丢弃（与速刷 _loadSeq 同型守卫）。
  int _generation = 0;

  /// 当前已就绪的额外候选词（未就绪时为空）。
  List<Word> get words => _words;

  /// 换书/换收藏/换局时重置：下一题重新随机取样（原 _replaceQueue 口径）。
  void reset() {
    _words = const [];
    _load = null;
    _generation++;
  }

  /// 确保池已加载（幂等）：首次触发异步取样，就绪后回调 onReady。
  void ensureLoaded() {
    final repository = this.repository;
    if (repository == null || _load != null) return;
    final generation = _generation;
    _load = repository
        .getRandomWords(24)
        .then((words) {
          if (generation != _generation) return; // 过期响应丢弃（reset 已换世代）
          _words = words;
          _onReady();
        })
        .catchError((Object _) {
          // 词库取样失败不阻塞答题：退化为仅会话队列候选（宁少勿假）。
        });
  }
}
