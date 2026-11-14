// 复习会话快照：一局进行中的「词序 + 走到第几步 + 已评分词 + 待提交作答」。
//
// 口径参考 word-atlas 的 ActiveSession（steps/index/graded/pending），按本仓的实际
// 结构收窄成复习局：新学不在此列。存储只用一段 SharedPreferences JSON，
// **不建 SQLite 表、不改 schema、不抬版本号**。
//
// 读取必须走 [decodeReviewSessionSnapshot]：字段白名单 + 范围校验 + 超时丢弃，
// 任何一项不合法都整段丢弃（当作没有存档），绝不抛错、也绝不半截恢复。
import 'dart:convert';

import 'package:word_app/core/utils/boss_siege.dart' show reviewSessionCap;

/// 快照版本；读到未知版本整段丢弃（旧客户端不会误读未来字段）。
const int reviewSessionSnapshotVersion = 1;

/// 超过这个时长未更新的半局自动丢弃，防止「半月前的半局」突然弹出来。
const Duration reviewSessionSnapshotMaxAge = Duration(hours: 24);

/// 允许的时钟回拨容差：`updated_at` 略晚于本机时间不算损坏。
const Duration reviewSessionSnapshotClockSkew = Duration(minutes: 5);

/// 已作答但尚未提交（正确反馈驻留窗口内被杀进程）。
///
/// 恢复时**不把 pending 计为已完成**：若评分真的落库了，该词已不再到期，
/// 会被重建逻辑排除并计为 done；若没落库，该词仍在队列里，让用户重答即可。
/// 两种情况都不会双计。
class ReviewSessionPending {
  const ReviewSessionPending({required this.wordId, required this.correct});

  final int wordId;
  final bool correct;
}

/// 一局复习的可恢复快照。
class ReviewSessionSnapshot {
  const ReviewSessionSnapshot({
    required this.sessionId,
    required this.wordIds,
    required this.index,
    required this.ratedIds,
    required this.pending,
    required this.hadDueAtStart,
    required this.dueAtStart,
    required this.updatedAt,
    this.wrongCount = 0,
  });

  /// 一局唯一 id（首次初始化时生成，恢复后原样保留）。
  final String sessionId;

  /// 本局完整词序（≤ [reviewSessionCap]）。
  final List<int> wordIds;

  /// 已走完的步数（= 会话 `done`）。
  final int index;

  /// 已消费的词 id（FSRS 已落库 + 「标记已掌握」+ 已不再到期的词）。
  final List<int> ratedIds;

  /// 已作答未提交的题；没有则为 null。
  final ReviewSessionPending? pending;

  /// 开局时是否真的有到期词（头目战触发口径的一半，恢复后必须冻结不变）。
  final bool hadDueAtStart;

  /// 开局时的到期词总数（截断前）。
  final int dueAtStart;

  /// 最近一次写入的毫秒时间戳。
  final int updatedAt;

  /// 本局「首次作答即答错」的题数（用户反馈修复 2026-11-14：恢复后正确率/XP 不虚高）。
  /// 旧存档无此字段时按 0（向后兼容）。
  final int wrongCount;

  int get total => wordIds.length;

  Map<String, Object?> toJson() => {
    'v': reviewSessionSnapshotVersion,
    'session_id': sessionId,
    'word_ids': wordIds,
    'index': index,
    'rated_ids': ratedIds,
    'pending': pending == null ? null : {'word_id': pending!.wordId, 'correct': pending!.correct},
    'had_due_at_start': hadDueAtStart,
    'due_at_start': dueAtStart,
    'updated_at': updatedAt,
    'wrong_count': wrongCount,
  };

  String encode() => jsonEncode(toJson());
}

/// 解析并消毒一段快照 JSON；任何不合法都返回 null（调用方按「没有存档」处理）。
ReviewSessionSnapshot? decodeReviewSessionSnapshot(String raw, {required DateTime now}) {
  if (raw.isEmpty) return null;
  Object? decoded;
  try {
    decoded = jsonDecode(raw);
  } on FormatException {
    return null;
  }
  if (decoded is! Map<String, dynamic>) return null;
  return _sanitize(decoded, now);
}

ReviewSessionSnapshot? _sanitize(Map<String, dynamic> raw, DateTime now) {
  if (raw['v'] != reviewSessionSnapshotVersion) return null;

  final sessionId = raw['session_id'];
  if (sessionId is! String || sessionId.isEmpty || sessionId.length > 128) return null;

  final wordIds = _intList(raw['word_ids'], maxLength: reviewSessionCap);
  if (wordIds == null || wordIds.isEmpty) return null;

  final index = raw['index'];
  if (index is! int || index < 0 || index > wordIds.length) return null;

  final ratedIds = _intList(raw['rated_ids'], maxLength: wordIds.length, allowEmpty: true);
  if (ratedIds == null || ratedIds.length > index) return null;
  final wordSet = wordIds.toSet();
  if (!ratedIds.every(wordSet.contains)) return null;

  final hadDueAtStart = raw['had_due_at_start'];
  if (hadDueAtStart is! bool) return null;

  final dueAtStart = raw['due_at_start'];
  if (dueAtStart is! int || dueAtStart < 0 || dueAtStart > 100000) return null;
  // 有到期词才可能截出一局；词序长度不会超过开局到期数。
  if (hadDueAtStart && (dueAtStart <= 0 || wordIds.length > dueAtStart)) return null;

  final updatedAt = raw['updated_at'];
  if (updatedAt is! int || updatedAt <= 0) return null;
  final age = now.difference(DateTime.fromMillisecondsSinceEpoch(updatedAt));
  if (age > reviewSessionSnapshotMaxAge || age < -reviewSessionSnapshotClockSkew) return null;

  final rawPending = raw['pending'];
  ReviewSessionPending? pending;
  if (rawPending != null) {
    if (rawPending is! Map<String, dynamic>) return null;
    final wordId = rawPending['word_id'];
    final correct = rawPending['correct'];
    if (wordId is! int || !wordSet.contains(wordId) || ratedIds.contains(wordId) || correct is! bool) {
      return null;
    }
    pending = ReviewSessionPending(wordId: wordId, correct: correct);
  }

  // 旧存档无 wrong_count 按 0；非法值 clamp 到 [0, index]。
  final rawWrong = raw['wrong_count'];
  final wrongCount = rawWrong is int ? rawWrong.clamp(0, index) : 0;

  return ReviewSessionSnapshot(
    sessionId: sessionId,
    wordIds: List<int>.unmodifiable(wordIds),
    index: index,
    ratedIds: List<int>.unmodifiable(ratedIds),
    pending: pending,
    hadDueAtStart: hadDueAtStart,
    dueAtStart: dueAtStart,
    updatedAt: updatedAt,
    wrongCount: wrongCount,
  );
}

/// 正整数 id 列表：拒绝空列表（除非 [allowEmpty]）、非 int、非正数、重复项。
List<int>? _intList(Object? value, {required int maxLength, bool allowEmpty = false}) {
  if (value is! List) return null;
  if (value.isEmpty && !allowEmpty) return null;
  if (value.length > maxLength) return null;
  final out = <int>[];
  final seen = <int>{};
  for (final item in value) {
    if (item is! int || item <= 0) return null;
    if (!seen.add(item)) return null;
    out.add(item);
  }
  return out;
}
