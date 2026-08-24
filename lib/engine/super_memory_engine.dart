// 由 Claude 团队生成 | Monster Word App

// 由账号4生成
// SuperMemory 复习引擎：翻译自 coreengine/SuperMemoryInMemoryImp.java（v3.2 源码 1:1）
// 复习调度：到期词 + 测试模式（英译中/四选一/拼写/完成）+ 评分等级 0-6

import '../models/bb_word_process.dart';
import 'core_engine.dart';

/// 测试模式（原版 TEST_MODE_* 常量）
enum TestMode {
  enToCh(0), // TEST_MODE_EN_TO_CH 英译中
  multipleChoice(1), // TEST_MODE_MULTIPLE_CHOICE 四选一
  chToEn(2), // TEST_MODE_CH_TO_EN 中译英
  finish(3); // TEST_MODE_FINISH 完成

  const TestMode(this.value);
  final int value;
}

/// 评分等级（原版 RATING_LEVEL_* 常量）
enum RatingLevel {
  level0(0),
  levelA(1),
  levelB(2),
  levelC(3),
  levelD(4),
  levelE(5),
  levelF(6);

  const RatingLevel(this.value);
  final int value;
}

/// 测试结果（原版 TEST_RESULT_* 常量）
enum TestResult {
  default0(0),
  fail(1), // TEST_RESULT_FAIL
  pass(2), // TEST_RESULT_PASS
  bingo(3); // TEST_RESULT_BINGO

  const TestResult(this.value);
  final int value;
}

/// SuperMemory 复习引擎（翻译自 SuperMemoryInMemoryImp.java）
class SuperMemoryEngine extends BBCoreEngine {
  static const int maxDuration = 90; // MAX_DURATION

  List<BBWordProcess> reviewList = []; // 待复习列表
  List<BBWordProcess> tooEasyList = []; // 太简单列表
  List<BBWordProcess> alreadyReviewed = []; // 已复习列表
  int _currentIndex = 0;
  int _totalNum = 0;
  List<WordChoicePair> _choicesRandom = [];

  SuperMemoryEngine({super.eventLabel = 'review'});

  /// 初始化复习列表（原版 arrayForReviewWords 逻辑）
  void init(List<BBWordProcess> dueWords) {
    reviewList = List.from(dueWords);
    tooEasyList = [];
    alreadyReviewed = [];
    _currentIndex = 0;
    _totalNum = reviewList.length;
    // 为每个单词分配测试模式（原版 reviewTestModeForWord）
    for (final w in reviewList) {
      w.testMode = _reviewTestModeForWord(w);
    }
    updateListChoicesRandom();
  }

  /// 为单词分配测试模式（原版 reviewTestModeForWord）
  int _reviewTestModeForWord(BBWordProcess w) {
    // 逻辑 1:1：按等级/次数轮换测试模式
    final rating = w.userRating;
    if (rating <= RatingLevel.levelA.value) {
      return TestMode.enToCh.value;
    } else if (rating == RatingLevel.levelB.value) {
      return TestMode.multipleChoice.value;
    } else if (rating == RatingLevel.levelC.value) {
      return TestMode.chToEn.value;
    }
    return TestMode.enToCh.value;
  }

  @override
  BBWordProcess? currentWord() {
    if (reviewList.isEmpty) return null;
    if (_currentIndex >= reviewList.length) return null;
    final w = reviewList[_currentIndex];
    currentWordProcess = w;
    return w;
  }

  @override
  int finishedNum() => alreadyReviewed.length;

  @override
  DataPreparedState getDataPreparedState() {
    if (reviewList.isEmpty && alreadyReviewed.isEmpty) return DataPreparedState.none;
    if (reviewList.isEmpty) return DataPreparedState.finished;
    return DataPreparedState.part;
  }

  @override
  List<WordChoicePair> getListChoicesRandom() => _choicesRandom;

  /// 更新随机选项池（始终确保4个选项：1个正确 + 3个干扰项）
  @override
  void updateListChoicesRandom() {
    final current = currentWord();
    if (current == null || current.interpret.isEmpty) {
      _choicesRandom = [];
      return;
    }

    // 正确选项
    final correctPair = WordChoicePair(current.word, current.interpret);

    // 构建干扰项池（排除当前单词）
    final seen = <String>{current.word};
    final distractorPool = <WordChoicePair>[];
    for (final w in [...reviewList, ...alreadyReviewed]) {
      if (w.interpret.isNotEmpty && !seen.contains(w.word)) {
        seen.add(w.word);
        distractorPool.add(WordChoicePair(w.word, w.interpret));
      }
    }

    // 随机选取 3 个干扰项
    distractorPool.shuffle();
    final distractors = distractorPool.take(3).toList();

    // 如果干扰项不足3个，用通用释义填充
    while (distractors.length < 3) {
      distractors.add(WordChoicePair(
        'option_${distractors.length}',
        '释义 ${distractors.length + 1}',
      ));
    }

    // 组合4个选项并随机打乱顺序
    final allChoices = [correctPair, ...distractors];
    allChoices.shuffle();
    _choicesRandom = allChoices;
  }

  @override
  int getWordMaxLevel() => 0;

  /// 不认识（原版 iDontKnow → fail）
  @override
  void iDontKnow() {
    final w = currentWord();
    if (w == null) return;
    w.reFail++;
    w.userRating = RatingLevel.level0.value;
    _afterReview(w, TestResult.fail);
  }

  /// 模糊（原版 iMayKnow → pass）
  @override
  void iMayKnow() {
    final w = currentWord();
    if (w == null) return;
    w.reFail++;
    w.userRating = min(RatingLevel.levelC.value, w.userRating + 1);
    _afterReview(w, TestResult.pass);
  }

  /// 认识（原版 iReallyKnow → bingo）
  @override
  void iReallyKnow() {
    final w = currentWord();
    if (w == null) return;
    w.reSuccess++;
    w.userRating = min(RatingLevel.levelF.value, w.userRating + 2);
    _afterReview(w, TestResult.bingo);
  }

  /// 太简单（原版 tooEasy → 移入 tooEasyList）
  @override
  void tooEasy() {
    final w = currentWord();
    if (w == null) return;
    w.reSuccess++;
    w.userRating = RatingLevel.levelF.value;
    tooEasyList.add(w);
    alreadyReviewed.add(w);
    reviewList.removeAt(_currentIndex);
    _afterReview(w, TestResult.bingo, removeFromList: false);
  }

  void _afterReview(BBWordProcess w, TestResult result,
      {bool removeFromList = true}) {
    if (removeFromList) {
      alreadyReviewed.add(w);
      if (_currentIndex < reviewList.length) {
        reviewList.removeAt(_currentIndex);
      }
    }
  }

  /// 全部是否太简单
  @override
  bool isAllTooEasy() => reviewList.every((w) => w.userRating >= RatingLevel.levelE.value);

  /// 复习是否结束
  @override
  bool lessonIsOver() => reviewList.isEmpty;

  @override
  void nextGroup() {
    if (reviewList.isNotEmpty) _currentIndex = 0;
  }

  @override
  BBWordProcess? nextWord() {
    if (_currentIndex < reviewList.length) _currentIndex++;
    return currentWord();
  }

  @override
  int remainWordsNum() => reviewList.length;

  @override
  int unFinishedNum() => reviewList.length - _currentIndex;

  int get totalNum => _totalNum;

  int get reviewedCount => alreadyReviewed.length;

  /// 今日应复习数量（原版 todayReviewCount）
  static int todayReviewCount(List<BBWordProcess> allProcess) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return allProcess
        .where((w) =>
            w.reviewDate.isNotEmpty &&
            DateTime.tryParse(w.reviewDate) != null &&
            !DateTime.parse(w.reviewDate).isBefore(today))
        .length;
  }

  int max(int a, int b) => a > b ? a : b;
  int min(int a, int b) => a < b ? a : b;
}
