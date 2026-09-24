import 'package:flutter/foundation.dart';

import 'package:word_app/core/engine/fsrs6_engine.dart';
import 'package:word_app/models/word.dart';

/// 正式复习 FSRS 展示信息的只读端口。
///
/// 该端口只提供页面展示记忆状态所需的数据，并保留通知能力以响应
/// 正式复习排程状态变化；评分写入仍由 [ReviewRatingWriter] 负责。
abstract class ReviewScheduleReader extends ChangeNotifier {
  FsrsCard? cardFor(String word);

  String getStatusText(FsrsCard card);

  String getDifficultyText(FsrsCard card);

  int get todayLearnCount;

  int get todayReviewCount;

  int get dueCount;

  int get activeDateCount;

  Map<String, int> get memoryStats;

  List<Word> dueWordsFor(Iterable<Word> words);

  /// MEM/异步化：按词批量取卡（DB 直查，未命中词值为 null）。
  ///
  /// 词表分类、详情页记忆预测等【需要确定性答案】的场景请用本方法，
  /// 不受同步缓存 [cardFor] 的 LRU 淘汰/读穿窗口影响。
  /// 默认实现由同步 [cardFor] 派生（测试替身可用；生产适配器覆写为 SQL 批查）。
  Future<Map<String, FsrsCard?>> cardsForWords(Iterable<String> wordTexts) async {
    final result = <String, FsrsCard?>{};
    for (final text in wordTexts) {
      result[text] = cardFor(text);
    }
    return result;
  }

  /// MEM/异步化：到期词过滤的 SQL 真相版，保持入参顺序。
  ///
  /// 默认实现委托同步 [dueWordsFor]（测试替身可用；生产适配器覆写为 SQL 查询）。
  Future<List<Word>> dueWordsForAsync(Iterable<Word> words) async => dueWordsFor(words);
}
