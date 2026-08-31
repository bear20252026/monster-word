// FSRS-6 间隔重复算法引擎（Free Spaced Repetition Scheduler v6）
// 参考: https://github.com/open-spaced-repetition/py-fsrs（官方 main 分支源码）
//
// 2026-08-31 算法升级（对照官方源码逐公式重写）：
// - 遗忘曲线修正：DECAY = -w20（默认 0.1542 → DECAY = -0.1542），
//   FACTOR = 0.9^(1/DECAY) - 1 = 0.981。旧实现 factor=0.0741 导致
//   stability 语义偏移 3.17 倍（R=0.9 需要 3.17·S 天而非 S 天）。
// - 全部公式对照 py-fsrs scheduler.py：初始难度指数式、难度更新
//   线性阻尼+均值回归、hard/easy 惩罚奖励改用 w15/w16、遗忘稳定
//   性取长短期 min、同日短时稳定性 w17/w18/w19。
// - 默认权重更新为官方最新机器学习优化值。
import 'dart:math';

/// FSRS-6 评分等级
enum FsrsRating {
  again(1, '不认识'), // 完全忘记
  hard(2, '模糊'), // 勉强想起
  good(3, '认识'), // 正常记忆
  easy(4, '熟练'); // 非常熟练

  const FsrsRating(this.value, this.label);
  final int value;
  final String label;
}

/// FSRS-6 卡片状态
class FsrsCard {
  final String word;
  double stability; // 记忆稳定性（天）：R 降至 90% 所需天数
  double difficulty; // 难度 (1-10)
  int elapsedDays; // 距上次复习的天数
  int scheduledDays; // 计划间隔天数
  DateTime lastReview; // 上次复习日期
  DateTime dueDate; // 下次复习日期
  int repetitions; // 连续答对次数
  int reviewCount; // 复习总次数
  bool isNew; // 是否新词
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
    lastReview: DateTime.parse(json['lastReview'] as String? ?? DateTime.now().toIso8601String()),
    dueDate: DateTime.parse(json['dueDate'] as String? ?? DateTime.now().toIso8601String()),
    repetitions: (json['repetitions'] as num?)?.toInt() ?? 0,
    reviewCount: (json['reviewCount'] as num?)?.toInt() ?? 0,
    isNew: (json['isNew'] as bool?) ?? true,
    shortTermStability: (json['shortTermStability'] as num?)?.toDouble() ?? 0,
  );

  FsrsCard copy() => FsrsCard.fromJson(toJson());
}

/// FSRS-6 算法引擎（对照 py-fsrs 官方源码逐公式实现）
class Fsrs6Engine {
  // FSRS-6 官方默认参数（py-fsrs main 分支 DEFAULT_PARAMETERS，21 个权重）
  static const List<double> _defaultWeights = [
    0.212,
    1.2931,
    2.3065,
    8.2956,
    6.4133,
    0.8334,
    3.0194,
    0.001,
    1.8722,
    0.1666,
    0.796,
    1.4835,
    0.0614,
    0.2629,
    1.6483,
    0.6014,
    1.8729,
    0.5425,
    0.0912,
    0.0658,
    0.1542, // w20：官方 FSRS_DEFAULT_DECAY
  ];

  // 参数
  final List<double> weights;
  final double decay; // 遗忘衰减指数 DECAY = -w20
  final double factor; // FACTOR = 0.9^(1/DECAY) - 1（保证 R(S,S)=0.9）
  final double desiredRetention; // 目标记忆保持率

  Fsrs6Engine({List<double>? weights, double? desiredRetention})
    : weights = weights ?? _defaultWeights,
      decay = -((weights ?? _defaultWeights)[20]),
      factor = pow(0.9, 1 / -((weights ?? _defaultWeights)[20])).toDouble() - 1,
      desiredRetention = desiredRetention ?? 0.9;

  // factor 为 final，由初始化列表按官方公式计算：FACTOR = 0.9^(1/DECAY) - 1

  double _clampStability(double s) => s.clamp(0.001, 36500.0);
  double _clampDifficulty(double d) => d.clamp(1.0, 10.0);

  /// 计算 retrievability（记忆提取概率）——官方公式：
  /// R = (1 + FACTOR · elapsed / S) ^ DECAY
  double _retrievability(int elapsedDays, double stability) {
    if (stability <= 0 || elapsedDays <= 0) return 1.0;
    return pow(1.0 + factor * elapsedDays / stability, decay).toDouble();
  }

  /// 初始稳定性 S0(G) = w[G-1]
  double _initialStability(FsrsRating rating) => _clampStability(weights[rating.value - 1]);

  /// 初始难度 D0(G) = w4 - e^(w5·(G-1)) + 1
  double _initialDifficulty(FsrsRating rating, {bool clamp = true}) {
    final d = weights[4] - exp(weights[5] * (rating.value - 1)) + 1;
    return clamp ? _clampDifficulty(d) : d;
  }

  /// 同日复习的短时稳定性：S·e^(w17·(G-3+w18))·S^(-w19)，Hard/Good/Easy 时增长下限 1
  double _shortTermStability(double stability, FsrsRating rating) {
    var inc = exp(weights[17] * (rating.value - 3 + weights[18])) * pow(stability, -weights[19]);
    if (rating != FsrsRating.again) inc = max(inc, 1.0);
    return _clampStability(stability * inc);
  }

  /// 难度更新：线性阻尼 + 均值回归（官方公式）
  double _nextDifficulty(double difficulty, FsrsRating rating) {
    final delta = -weights[6] * (rating.value - 3);
    final damping = (10.0 - difficulty) * delta / 9.0;
    final arg1 = _initialDifficulty(FsrsRating.easy, clamp: false);
    final next = weights[7] * arg1 + (1 - weights[7]) * (difficulty + damping);
    return _clampDifficulty(next);
  }

  /// 回忆成功后的长时稳定性：
  /// S·(1 + e^w8·(11-D)·S^(-w9)·(e^((1-R)·w10)-1)·hardPenalty(w15)·easyBonus(w16))
  double _nextRecallStability(double stability, double difficulty, double retrievability, FsrsRating rating) {
    final hardPenalty = rating == FsrsRating.hard ? weights[15] : 1.0;
    final easyBonus = rating == FsrsRating.easy ? weights[16] : 1.0;
    return stability *
        (1 +
            exp(weights[8]) *
                (11 - difficulty) *
                pow(stability, -weights[9]) *
                (exp((1 - retrievability) * weights[10]) - 1) *
                hardPenalty *
                easyBonus);
  }

  /// 遗忘后的长时稳定性：取长短期模型较小值
  /// long = w11·D^(-w12)·((S+1)^w13 - 1)·e^((1-R)·w14)
  /// short = S / e^(w17·w18)
  double _nextForgetStability(double stability, double difficulty, double retrievability) {
    final longTerm =
        weights[11] *
        pow(difficulty, -weights[12]) *
        (pow(stability + 1, weights[13]) - 1) *
        exp((1 - retrievability) * weights[14]);
    final shortTerm = stability / exp(weights[17] * weights[18]);
    return min(longTerm, shortTerm);
  }

  /// 下次间隔天数：round(S / FACTOR · (r^(1/DECAY) - 1))，1~36500 天
  int _nextInterval(double stability) {
    final raw = stability / factor * (pow(desiredRetention, 1 / decay).toDouble() - 1);
    return raw.round().clamp(1, 36500);
  }

  /// 评分一个卡片，返回更新后的卡片（官方 FSRS-6 流程）
  FsrsCard review(FsrsCard card, FsrsRating rating) {
    final updated = card.copy();
    final now = DateTime.now();

    // 距上次复习的天数（同日 = 0 → 短时模型）
    final elapsed = now.difference(card.lastReview).inDays;
    updated.elapsedDays = elapsed;

    if (card.isNew) {
      // 新卡片初始化
      updated.difficulty = _initialDifficulty(rating);
      updated.stability = _initialStability(rating);
      updated.shortTermStability = updated.stability;
    } else {
      final retrievability = _retrievability(elapsed, card.stability);
      updated.difficulty = _nextDifficulty(card.difficulty, rating);

      final isSameDay = elapsed == 0;
      if (isSameDay) {
        // 同一天复习：短时稳定性模型
        updated.stability = _shortTermStability(card.stability, rating);
        updated.shortTermStability = updated.stability;
      } else {
        // 跨天复习：长时模型（again → forget；其余 → recall）
        updated.stability = _nextStability(card.stability, card.difficulty, retrievability, rating);
        updated.shortTermStability = updated.stability;
      }
    }

    // 计算下次间隔
    updated.scheduledDays = _nextInterval(updated.stability);
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

  /// 长时稳定性统一入口（again → forget，否则 recall）
  double _nextStability(double stability, double difficulty, double retrievability, FsrsRating rating) {
    final next = rating == FsrsRating.again
        ? _nextForgetStability(stability, difficulty, retrievability)
        : _nextRecallStability(stability, difficulty, retrievability, rating);
    return _clampStability(next);
  }

  /// 首次学习一个单词
  FsrsCard learn(String word, FsrsRating rating) {
    final card = FsrsCard(word: word, lastReview: DateTime.now(), dueDate: DateTime.now());
    return review(card, rating);
  }

  /// 获取到期的卡片
  List<FsrsCard> getDueCards(List<FsrsCard> cards) {
    final now = DateTime.now();
    return cards.where((c) => !c.isNew && !c.dueDate.isAfter(now)).toList();
  }

  /// 记忆预测快照（review_schedule_repository.predictionFor 消费）
  Map<String, dynamic> getPrediction(FsrsCard card) {
    final r = getRetrievability(card);
    return {
      'stability': card.stability,
      'difficulty': card.difficulty,
      'retrievability': r,
      'state': getStatusText(card),
      'scheduledDays': card.scheduledDays,
      'dueDate': card.dueDate.toIso8601String(),
    };
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
    if (days <= 30) return '${(days / 7).round()} 周后';
    return '${(days / 30).round()} 月后';
  }
}
