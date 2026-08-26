// 复习状态 ViewModel — 复习队列、SRS 评分
import 'package:flutter/foundation.dart';

import '../engine/core_engine.dart' show WordChoicePair;
import '../models/bb_word_process.dart';
import '../models/word.dart';
import '../services/review_service.dart';

/// 复习状态 ViewModel
///
/// 负责管理复习队列、SRS 评分、复习进度。
/// 通过 ReviewService 访问复习业务逻辑。
class ReviewState extends ChangeNotifier {
  final ReviewService _reviewService;

  ReviewState({required ReviewService reviewService})
      : _reviewService = reviewService;

  List<String> _words = [];
  int _currentIndex = 0;
  bool _showAnswer = false;
  bool _initialized = false;

  List<String> get words => _words;
  int get currentIndex => _currentIndex;
  int get total => _words.length;
  bool get showAnswer => _showAnswer;
  bool get initialized => _initialized;
  bool get isFinished => _currentIndex >= _words.length;

  String? get currentWord =>
      _words.isEmpty ? null : _words[_currentIndex.clamp(0, _words.length - 1)];

  (int current, int total) get progress => (_currentIndex + 1, _words.length);

  /// 初始化复习队列
  Future<void> init(List<String> wordStrings) async {
    _words = wordStrings;
    _currentIndex = 0;
    _showAnswer = false;
    _initialized = true;
    final processes = wordStrings.map((w) => BBWordProcess(word: w)).toList();
    _reviewService.init(processes);
    notifyListeners();
  }

  /// 显示答案
  void revealAnswer() {
    _showAnswer = true;
    notifyListeners();
  }

  /// 标记为不认识
  void iDontKnow() {
    _reviewService.iDontKnow();
    _currentIndex++;
    _showAnswer = false;
    notifyListeners();
  }

  /// 标记为可能认识
  void iMayKnow() {
    _reviewService.iMayKnow();
    _currentIndex++;
    _showAnswer = false;
    notifyListeners();
  }

  /// 标记为认识
  void iReallyKnow() {
    _reviewService.iReallyKnow();
    _currentIndex++;
    _showAnswer = false;
    notifyListeners();
  }

  /// 标记为太简单
  void tooEasy() {
    _reviewService.tooEasy();
    _currentIndex++;
    _showAnswer = false;
    notifyListeners();
  }

  /// 获取干扰项
  List<WordChoicePair> getConfuseItems(Word word) {
    return _reviewService.confuseItemsForChoice(word);
  }

  /// 重置复习
  void reset() {
    _currentIndex = 0;
    _showAnswer = false;
    notifyListeners();
  }
}
