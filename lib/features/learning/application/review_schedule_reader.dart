import 'package:flutter/foundation.dart';

import '../../../core/engine/fsrs6_engine.dart';
import '../../../models/word.dart';

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
}
