// 由 Claude 团队生成 | Monster Word App

// 由账号4生成
// SRS 间隔重复学习引擎（SM-2 算法）
// 每个单词维护：记忆等级(0-5)、间隔天数、到期日、复习次数
import 'dart:math';

/// 评分等级（学习时用户反馈）
enum RecallRating {
  again(0, '不认识'), // 完全忘记 → 重新学习
  hard(3, '模糊'), // 勉强想起 → 较短间隔
  good(4, '认识'), // 正常记忆 → 标准间隔
  easy(5, '熟练'); // 非常熟练 → 更长间隔

  const RecallRating(this.quality, this.label);
  final int quality;
  final String label;
}

/// 单个单词的学习状态（SM-2 卡片）
class SrsCard {
  final String word;
  int repetitions; // 连续答对次数
  int interval; // 当前间隔天数
  double easeFactor; // 易度因子（初始 2.5）
  int dueDays; // 下次复习间隔天数（从上次复习起）
  DateTime dueDate; // 下次复习日期
  bool isNew; // 是否是新词（从未学过）
  int reviewCount; // 复习总次数

  SrsCard({
    required this.word,
    this.repetitions = 0,
    this.interval = 0,
    this.easeFactor = 2.5,
    this.dueDays = 0,
    required this.dueDate,
    this.isNew = true,
    this.reviewCount = 0,
  });

  /// 是否到期需要复习
  bool get isDue => !isNew && dueDate.isBefore(DateTime.now());

  /// 序列化（存 shared_preferences）
  Map<String, dynamic> toJson() => {
        'word': word,
        'repetitions': repetitions,
        'interval': interval,
        'easeFactor': easeFactor,
        'dueDays': dueDays,
        'dueDate': dueDate.toIso8601String(),
        'isNew': isNew,
        'reviewCount': reviewCount,
      };

  factory SrsCard.fromJson(Map<String, dynamic> json) => SrsCard(
        word: json['word'] as String,
        repetitions: (json['repetitions'] as num?)?.toInt() ?? 0,
        interval: (json['interval'] as num?)?.toInt() ?? 0,
        easeFactor: (json['easeFactor'] as num?)?.toDouble() ?? 2.5,
        dueDays: (json['dueDays'] as num?)?.toInt() ?? 0,
        dueDate:
            DateTime.parse(json['dueDate'] as String? ?? DateTime.now().toIso8601String()),
        isNew: (json['isNew'] as bool?) ?? true,
        reviewCount: (json['reviewCount'] as num?)?.toInt() ?? 0,
      );

  /// 克隆（不可变更新）
  SrsCard copy() => SrsCard.fromJson(toJson());
}

/// SM-2 间隔重复算法引擎
class SrsEngine {
  /// 评分一个卡片，返回更新后的卡片（SM-2 核心逻辑）
  SrsCard review(SrsCard card, RecallRating rating) {
    final updated = card.copy();
    final q = rating.quality;
    final now = DateTime.now();

    if (q < 3) {
      // 失败：重置重复计数，间隔归 1 天
      updated.repetitions = 0;
      updated.interval = 1;
      updated.dueDays = 1;
      updated.isNew = false;
    } else {
      if (updated.repetitions == 0) {
        // 第一次答对：间隔 1 天
        updated.interval = 1;
      } else if (updated.repetitions == 1) {
        // 第二次答对：间隔 6 天
        updated.interval = 6;
      } else {
        // 之后：间隔 × 易度因子
        updated.interval = (updated.interval * updated.easeFactor).round();
      }
      updated.repetitions++;
      updated.dueDays = updated.interval;
    }

    // 易度因子更新（SM-2 公式）
    updated.easeFactor = max(
      1.3,
      updated.easeFactor +
          (0.1 - (5 - q) * (0.08 + (5 - q) * 0.02)),
    );

    updated.dueDate = now.add(Duration(days: updated.interval));
    updated.isNew = false;
    updated.reviewCount++;
    return updated;
  }

  /// 首次学习一个单词（评分后创建卡片）
  SrsCard learn(String word, RecallRating rating) {
    final card = SrsCard(word: word, dueDate: DateTime.now());
    return review(card, rating);
  }

  /// 计算今天应复习的单词（从卡片列表中过滤）
  List<SrsCard> getDueCards(List<SrsCard> cards) {
    final now = DateTime.now();
    return cards.where((c) => !c.isNew && !c.dueDate.isAfter(now)).toList();
  }
}
