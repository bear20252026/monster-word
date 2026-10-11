import 'package:shared_preferences/shared_preferences.dart';

import 'package:word_app/core/utils/swallowed_error_report.dart';

import 'package:word_app/features/learning/data/mastered_repository.dart';

/// 基于 SharedPreferences 的已掌握单词标记仓储。
///
/// 保留既有存储键，确保用户已有的手动掌握标记无需迁移。
class MasteredRepositoryImpl implements MasteredRepository {
  static const _masteredWordsKey = 'mastered_words_v1';

  final Set<String> _masteredWords = {};

  /// 审计 I30：持有加载 Future——此前 toggle 不等待加载完成即全量覆写 SP，
  /// 启动早期触发会用残缺集合覆盖全部已掌握标记（不可逆）。
  Future<void>? _loadFuture;

  /// MW-58：首次读取失败 ≠ 数据为空。置位后禁止全量覆写保存——
  /// 否则一次瞬态读失败 + 用户一次 toggle 就会用空集合覆盖全部历史掌握记录。
  bool _loadFailed = false;
  bool get debugLoadFailed => _loadFailed;

  MasteredRepositoryImpl() {
    _loadFuture = _loadMasteredWords();
  }

  Future<void> _loadMasteredWords() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getStringList(_masteredWordsKey);
      if (saved != null) {
        _masteredWords.addAll(saved);
      }
      _loadFailed = false;
    } catch (e, s) {
      // 存储不可用时保留内存中的安全空集合，但标记为「未知」而非「空」。
      _loadFailed = true;
      reportSwallowedError('已掌握词表加载失败（禁止覆写保存直至读取成功）', e, s);
    }
  }

  Future<void> _saveMasteredWords() async {
    if (_loadFailed) {
      // 事实来源读取失败期间的破坏性全量覆写守卫（MW-58）。
      reportSwallowedError(
        '已掌握词表读取失败期间拒绝覆写保存（防止空集合覆盖历史数据）',
        StateError('mastered save blocked: load failed'),
        StackTrace.current,
      );
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final ok = await prefs.setStringList(_masteredWordsKey, _masteredWords.toList());
    if (!ok) {
      reportSwallowedError(
        '已掌握词表保存返回 false（内存保留，下次 toggle 重试）',
        StateError('setStringList(mastered_words_v1) returned false'),
        StackTrace.current,
      );
    }
  }

  @override
  Future<Set<String>> getMasteredWords() async {
    await _loadFuture;
    return Set<String>.from(_masteredWords);
  }

  @override
  bool isMastered(String word) => _masteredWords.contains(word);

  @override
  int get masteredCount => _masteredWords.length;

  @override
  Future<void> toggleMastered(String word) async {
    await _loadFuture;
    if (_masteredWords.contains(word)) {
      _masteredWords.remove(word);
    } else {
      _masteredWords.add(word);
    }
    await _saveMasteredWords();
  }
}
