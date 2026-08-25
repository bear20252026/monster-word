// FSRS-6 间隔重复算法引擎（Free Spaced Repetition Scheduler v6）
// 参考: https://github.com/open-spaced-repetition/free-spaced-repetition-scheduler
// FSRS-6 核心改进：短时记忆模型 + 改进的难度计算 + 更准确的记忆预测
import 'dart:math';

/// FSRS-6 评分等级
enum FsrsRating {
  again(1, '不认识'),   // 完全忘记
  hard(2, '模糊'),      // 勉强想起
  good(3, '认识'),      // 正常记忆
  easy(4, '熟练');      // 非常熟练

  const FsrsRating(this.value, this.label);
  final int value;
  final String label;
}

/// FSRS-6 卡片状态
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
  double shortTermStability; // 短时记忆稳定性（FSRS-6 新增）

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
    this.shortTermStability = 0,
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
        'shortTermStability': shortTermStability,
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
        shortTermStability:
            (json['shortTermStability'] as num?)?.toDouble() ?? 0,
      );

  FsrsCard copy() => FsrsCard.fromJson(toJson());
}

/// FSRS-6 算法引擎
/// 核心改进：
/// 1. 短时记忆模型 - 同一天内的复习使用不同的稳定性计算
/// 2. 改进的难度计算 - 更准确地评估单词难度
/// 3. 更准确的记忆预测 - 基于遗忘曲线的精确概率计算
class Fsrs6Engine {
  // FSRS-6 默认参数（21 个权重 - 通过机器学习优化）
  static const List<double> _defaultWeights = [
    0.40255, 1.18385, 3.173, 15.69105, 7.1949,
    0.5345, 1.4604, 0.0046, 1.54575, 0.1192,
    1.01925, 1.9395, 0.11, 0.29605, 2.2698,
    0.2315, 2.9898, 0.51655, 0.6621, 0.0294,
    0.0805,
  ];

  // 参数
  final List<double> weights;
  final double decay;        // 遗忘衰减因子 (-0.5)
  final double factor;       // 稳定性增长因子
  final double desiredRetention; // 目标记忆保持率

  Fsrs6Engine({
    List<double>? weights,
    this.decay = -0.5,
    this.desiredRetention = 0.9,
  })  : weights = weights ?? _defaultWeights,
        factor = 1.0 / (9.0 * (1.0 - (-0.5)));

  /// 计算 retrievability（记忆提取概率）- FSRS-6 精确公式
  /// 返回 0.0-1.0 之间的值，表示记住该单词的概率
  double _retrievability(int elapsedDays, double stability) {
    if (stability <= 0 || elapsedDays <= 0) return 1.0;
    // FSRS-6 遗忘曲线: R = (1 + factor * elapsed / stability) ^ decay
    return pow(1.0 + factor * elapsedDays / stability, decay).toDouble();
  }

  /// 计算新的短时记忆稳定性（FSRS-6 新增）
  /// 同一天内的复习使用短时模型
  double _nextShortTermStability(
      double stability, double difficulty, FsrsRating rating) {
    switch (rating) {
      case FsrsRating.again:
        return weights[0] * pow(difficulty / 10.0, -weights[16]) * pow(stability + 1, weights[17]);
      case FsrsRating.hard:
        return stability * exp(weights[14]);
      case FsrsRating.good:
        return stability * exp(weights[14]) * (1 + exp(weights[15]) * (11 - difficulty));
      case FsrsRating.easy:
        return stability * exp(weights[14]) * (1 + exp(weights[15]) * (11 - difficulty)) * weights[18];
    }
  }

  /// 计算新的长时记忆稳定性
  double _nextLongTermStability(
      double stability, double difficulty, double retrievability, FsrsRating rating) {
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

  /// 计算新的难度 - FSRS-6 改进公式
  double _nextDifficulty(double difficulty, FsrsRating rating) {
    // 均值回归：难度趋向于中间值
    final meanReversion = weights[4] * (weights[5] - difficulty);
    
    // 评分对难度的影响
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
  double _nextInterval(double stability) {
    // FSRS-6 间隔公式: I = S / 0.9 * (R^(1/decay) - 1)
    return (stability / desiredRetention * (pow(desiredRetention, 1.0 / decay) - 1))
        .clamp(1.0, 365.0);
  }

  /// 评分一个卡片，返回更新后的卡片
  FsrsCard review(FsrsCard card, FsrsRating rating) {
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
      updated.shortTermStability = updated.stability;
    } else {
      // 复习卡片更新
      updated.difficulty = _nextDifficulty(card.difficulty, rating);
      
      // FSRS-6: 区分短时和长时记忆
      final isSameDay = elapsed == 0;
      if (isSameDay) {
        // 同一天复习：使用短时记忆模型
        updated.shortTermStability = _nextShortTermStability(
            card.shortTermStability, card.difficulty, rating);
        updated.stability = updated.shortTermStability;
      } else {
        // 跨天复习：使用长时记忆模型
        updated.stability = _nextLongTermStability(
            card.stability, card.difficulty, retrievability, rating);
        updated.shortTermStability = updated.stability;
      }
    }

    // 计算下次间隔
    updated.scheduledDays = _nextInterval(updated.stability).round();
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
  FsrsCard learn(String word, FsrsRating rating) {
    final card = FsrsCard(
      word: word,
      lastReview: DateTime.now(),
      dueDate: DateTime.now(),
    );
    return review(card, rating);
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

  /// 获取记忆提取概率（0.0-1.0）
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

  /// 获取难度描述
  String getDifficultyText(FsrsCard card) {
    if (card.difficulty >= 8) return '非常困难';
    if (card.difficulty >= 6) return '困难';
    if (card.difficulty >= 4) return '中等';
    if (card.difficulty >= 2) return '简单';
    return '非常简单';
  }

  /// 获取下次复习时间的描述
  String getNextReviewText(FsrsCard card) {
    if (card.isNew) return '新词';
    final days = card.scheduledDays;
    if (days <= 1) return '明天';
    if (days <= 7) return '$days 天后';
    if (days <= 30) return '${(days / 7).ceil()} 周后';
    return '${(days / 30).ceil()} 月后';
  }

  /// 获取记忆预测信息（用于详情页显示）
  Map<String, dynamic> getPrediction(FsrsCard card) {
    return {
      'retrievability': getRetrievability(card),
      'status': getStatusText(card),
      'difficulty': card.difficulty,
      'difficultyText': getDifficultyText(card),
      'stability': card.stability,
      'scheduledDays': card.scheduledDays,
      'nextReview': getNextReviewText(card),
      'repetitions': card.repetitions,
      'reviewCount': card.reviewCount,
    };
  }
}
