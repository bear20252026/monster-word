// FSRS-5 间隔重复算法引擎（Free Spaced Repetition Scheduler v5）
// 参考: https://github.com/open-spaced-repetition/fsrs4anki/blob/main/fsrs4anki_scheduler.js
// FSRS-5 核心公式: stability, difficulty, retrievability
import 'dart:math';

/// FSRS-5 评分等级
enum FsrsRating {
  again(1, '不认识'),   // 完全忘记
  hard(2, '模糊'),      // 勉强想起
  good(3, '认识'),      // 正常记忆
  easy(4, '熟练');      // 非常熟练

  const FsrsRating(this.value, this.label);
  final int value;
  final String label;
}

/// FSRS-5 卡片状态
class FsrsCard {
  final String word;
  double stability;      // 记忆稳定性（天）
  double difficulty;     // 难度 (1-10)
  int elapsedDays;       // 距上次复习的天数
  int scheduledDays;     // 计划间隔天数
  DateTime lastReview;   // 上次复习日期
  DateTime dueDate;      // 下次复习日期
  int repetitions;       // 连续答对次数
  int reviewCount;       // 复习总次数
  bool isNew;            // 是否新词

  FsrsCard({
    required this.word,
    this.stability = 0,
    this.difficulty = 0,
    this.elapsedDays = 0,
    this.scheduledDays = 0,
    required this.lastReview,
    required this.dueDate,
    this.repetitions = 0,
    this.reviewCount = 0,
    this.isNew = true,
  });

  bool get isDue => !isNew && dueDate.isBefore(DateTime.now());

  Map<String, dynamic> toJson() => {
        'word': word,
        'stability': stability,
        'difficulty': difficulty,
        'elapsedDays': elapsedDays,
        'scheduledDays': scheduledDays,
        'lastReview': lastReview.toIso8601String(),
        'dueDate': dueDate.toIso8601String(),
        'repetitions': repetitions,
        'reviewCount': reviewCount,
        'isNew': isNew,
      };

  factory FsrsCard.fromJson(Map<String, dynamic> json) => FsrsCard(
        word: json['word'] as String,
        stability: (json['stability'] as num?)?.toDouble() ?? 0,
        difficulty: (json['difficulty'] as num?)?.toDouble() ?? 0,
        elapsedDays: (json['elapsedDays'] as num?)?.toInt() ?? 0,
        scheduledDays: (json['scheduledDays'] as num?)?.toInt() ?? 0,
        lastReview: DateTime.parse(
            json['lastReview'] as String? ?? DateTime.now().toIso8601String()),
        dueDate: DateTime.parse(
            json['dueDate'] as String? ?? DateTime.now().toIso8601String()),
        repetitions: (json['repetitions'] as num?)?.toInt() ?? 0,
        reviewCount: (json['reviewCount'] as num?)?.toInt() ?? 0,
        isNew: (json['isNew'] as bool?) ?? true,
      );

  FsrsCard copy() => FsrsCard.fromJson(toJson());
}

/// FSRS-5 算法引擎
class Fsrs5Engine {
  // FSRS-5 默认参数（17 个权重）
  static const List<double> _defaultWeights = [
    0.40255, 1.18385, 3.173, 15.69105, 7.1949,
    0.5345, 1.4604, 0.0046, 1.54575, 0.1192,
    1.01925, 1.9395, 0.11, 0.29605, 2.2698,
    0.2315, 2.9898,
  ];

  // 参数
  final List<double> weights;
  final double decay;        // 遗忘衰减因子 (-0.5)
  final double factor;       // 稳定性增长因子 (1 / (9 * (1 - decay)))

  Fsrs5Engine({
    List<double>? weights,
    this.decay = -0.5,
  })  : weights = weights ?? _defaultWeights,
        factor = 1.0 / (9.0 * (1.0 - (-0.5)));

  /// 计算 retrievability（记忆提取概率）
  double _retrievability(int elapsedDays, double stability) {
    if (stability <= 0 || elapsedDays <= 0) return 1.0;
    return pow(1.0 + factor * elapsedDays / stability, decay).toDouble();
  }

  /// 计算新的稳定性
  double _nextStability(double stability, double difficulty, double retrievability, FsrsRating rating) {
    final hardPenalty = rating == FsrsRating.hard ? 0.8 : 1.0;
    final easyBonus = rating == FsrsRating.easy ? 1.3 : 1.0;

    if (rating == FsrsRating.again) {
      // 忘记：稳定性下降
      return stability *
          (1.0 + exp(3.45) *
              pow(stability, -0.1) *
              (exp((1 - retrievability) * 2.95) - 1) *
              0.85);
    }

    // Good/Hard/Easy：稳定性增长
    final growth = exp(weights[8]) *
        (11 - difficulty) *
        pow(stability, -weights[9]) *
        (exp((1 - retrievability) * weights[10]) - 1) *
        hardPenalty *
        easyBonus;

    return stability + growth;
  }

  /// 计算新的难度
  /// 计算新的难度
  double _nextDifficulty(double difficulty, FsrsRating rating) {
    final meanReversion = weights[4] * (weights[5] - difficulty);
    final delta = rating == FsrsRating.again
        ? weights[6]
        : rating == FsrsRating.hard
            ? weights[7]
            : rating == FsrsRating.good
                ? 0
                : -weights[7];

    return (difficulty + meanReversion + delta).clamp(1.0, 10.0);
  }

  /// 计算下次间隔天数
  double _nextInterval(double stability, double requestRetention) {
    return (stability / 0.9 * (pow(requestRetention, 1.0 / decay) - 1))
        .clamp(1.0, 365.0);
  }

  /// 评分一个卡片，返回更新后的卡片
  FsrsCard review(FsrsCard card, FsrsRating rating, {double requestRetention = 0.9}) {
    final updated = card.copy();
    final now = DateTime.now();

    // 计算距上次复习的天数
    final elapsed = now.difference(card.lastReview).inDays;
    updated.elapsedDays = elapsed;

    // 计算当前 retrievability
    final retrievability = _retrievability(elapsed, card.stability);

    if (card.isNew) {
      // 新卡片初始化
      updated.difficulty = _initDifficulty(rating);
      updated.stability = _initStability(rating);
    } else {
      // 复习卡片更新
      updated.difficulty = _nextDifficulty(card.difficulty, rating);
      updated.stability = _nextStability(card.stability, card.difficulty, retrievability, rating);
    }

    // 计算下次间隔
    updated.scheduledDays = _nextInterval(updated.stability, requestRetention).round();
    updated.dueDate = now.add(Duration(days: updated.scheduledDays));
    updated.lastReview = now;
    updated.isNew = false;
    updated.reviewCount++;

    if (rating == FsrsRating.again) {
      updated.repetitions = 0;
    } else {
      updated.repetitions++;
    }

    return updated;
  }

  /// 首次学习一个单词
  FsrsCard learn(String word, FsrsRating rating, {double requestRetention = 0.9}) {
    final card = FsrsCard(
      word: word,
      lastReview: DateTime.now(),
      dueDate: DateTime.now(),
    );
    return review(card, rating, requestRetention: requestRetention);
  }

  /// 获取到期的卡片
  List<FsrsCard> getDueCards(List<FsrsCard> cards) {
    final now = DateTime.now();
    return cards.where((c) => !c.isNew && !c.dueDate.isAfter(now)).toList();
  }

  /// 初始稳定性（基于评分）
  double _initStability(FsrsRating rating) {
    switch (rating) {
      case FsrsRating.again:
        return weights[0];
      case FsrsRating.hard:
        return weights[1];
      case FsrsRating.good:
        return weights[2];
      case FsrsRating.easy:
        return weights[3];
    }
  }

  /// 初始难度（基于评分）
  double _initDifficulty(FsrsRating rating) {
    switch (rating) {
      case FsrsRating.again:
        return weights[4] + 2.0;
      case FsrsRating.hard:
        return weights[4] + 1.0;
      case FsrsRating.good:
        return weights[4];
      case FsrsRating.easy:
        return weights[4] - 1.0;
    }
  }

  /// 获取记忆提取概率
  double getRetrievability(FsrsCard card) {
    if (card.isNew || card.stability <= 0) return 1.0;
    final elapsed = DateTime.now().difference(card.lastReview).inDays;
    return _retrievability(elapsed, card.stability);
  }

  /// 获取记忆状态描述
  String getStatusText(FsrsCard card) {
    if (card.isNew) return '新词';
    final r = getRetrievability(card);
    if (r < 0.3) return '即将遗忘';
    if (r < 0.6) return '模糊';
    if (r < 0.8) return '一般';
    return '牢固';
  }
}
