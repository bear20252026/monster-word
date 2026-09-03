import 'package:shared_preferences/shared_preferences.dart';

import 'package:word_app/core/utils/swallowed_error_report.dart';

import 'package:word_app/features/learning/data/mastered_repository.dart';

/// 基于 SharedPreferences 的已掌握单词标记仓储。
///
/// 保留既有存储键，确保用户已有的手动掌握标记无需迁移。
class MasteredRepositoryImpl implements MasteredRepository {
  static const _masteredWordsKey = 'mastered_words_v1';

  final Set<String> _masteredWords = {};

  MasteredRepositoryImpl() {
    _loadMasteredWords();
  }

  Future<void> _loadMasteredWords() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getStringList(_masteredWordsKey);
      if (saved != null) {
        _masteredWords.addAll(saved);
      }
    } catch (e, s) {
      // 存储不可用时保留内存中的安全空集合。
      reportSwallowedError('已掌握词表加载失败', e, s);
    }
  }

  Future<void> _saveMasteredWords() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_masteredWordsKey, _masteredWords.toList());
  }

  @override
  Future<Set<String>> getMasteredWords() async {
    if (_masteredWords.isEmpty) {
      await _loadMasteredWords();
    }
    return Set<String>.from(_masteredWords);
  }

  @override
  bool isMastered(String word) => _masteredWords.contains(word);

  @override
  int get masteredCount => _masteredWords.length;

  @override
  Future<void> toggleMastered(String word) async {
    if (_masteredWords.contains(word)) {
      _masteredWords.remove(word);
    } else {
      _masteredWords.add(word);
    }
    await _saveMasteredWords();
  }
}
