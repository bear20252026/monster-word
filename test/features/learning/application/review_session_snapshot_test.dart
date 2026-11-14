// 复习会话快照的解析/消毒：任何损坏都整段丢弃，绝不半截恢复。
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:word_app/core/utils/boss_siege.dart';
import 'package:word_app/features/learning/application/review_session_snapshot.dart';

final DateTime _now = DateTime(2026, 11, 5, 12);

Map<String, Object?> _validJson({
  Object? version = 1,
  Object? sessionId = 's1',
  Object? wordIds = const [1, 2, 3, 4],
  Object? index = 1,
  Object? ratedIds = const [1],
  Object? pending = const {'word_id': 2, 'correct': true},
  Object? hadDueAtStart = true,
  Object? dueAtStart = 42,
  Object? updatedAt,
}) => {
  'v': version,
  'session_id': sessionId,
  'word_ids': wordIds,
  'index': index,
  'rated_ids': ratedIds,
  'pending': pending,
  'had_due_at_start': hadDueAtStart,
  'due_at_start': dueAtStart,
  'updated_at': updatedAt ?? _now.millisecondsSinceEpoch,
};

ReviewSessionSnapshot? _decode(Map<String, Object?> json) => decodeReviewSessionSnapshot(jsonEncode(json), now: _now);

void main() {
  group('ReviewSessionSnapshot 消毒', () {
    test('合法快照完整解析（词序 / 步数 / 已评分 / pending / 开局事实）', () {
      final snapshot = _decode(_validJson());

      expect(snapshot, isNotNull);
      expect(snapshot!.sessionId, 's1');
      expect(snapshot.wordIds, [1, 2, 3, 4]);
      expect(snapshot.total, 4);
      expect(snapshot.index, 1);
      expect(snapshot.ratedIds, [1]);
      expect(snapshot.pending?.wordId, 2);
      expect(snapshot.pending?.correct, isTrue);
      expect(snapshot.hadDueAtStart, isTrue);
      expect(snapshot.dueAtStart, 42);
      expect(snapshot.updatedAt, _now.millisecondsSinceEpoch);
    });

    test('encode → decode 往返一致', () {
      final original = _decode(_validJson())!;
      final roundTrip = decodeReviewSessionSnapshot(original.encode(), now: _now);

      expect(roundTrip, isNotNull);
      expect(roundTrip!.sessionId, original.sessionId);
      expect(roundTrip.wordIds, original.wordIds);
      expect(roundTrip.index, original.index);
      expect(roundTrip.ratedIds, original.ratedIds);
      expect(roundTrip.pending?.wordId, original.pending?.wordId);
      expect(roundTrip.hadDueAtStart, original.hadDueAtStart);
      expect(roundTrip.dueAtStart, original.dueAtStart);
    });

    test('wrong_count 往返一致；旧存档缺省按 0（2026-11-14）', () {
      final base = _validJson(index: 2, ratedIds: const [1, 2], pending: null);
      final withWrong = _decode(base..['wrong_count'] = 2)!;
      expect(withWrong.wrongCount, 2);
      final roundTrip = decodeReviewSessionSnapshot(withWrong.encode(), now: _now)!;
      expect(roundTrip.wrongCount, 2);

      // 旧存档无 wrong_count 字段 → 0（向后兼容）。
      expect(_decode(_validJson())!.wrongCount, 0);
      // 非法值 clamp 到 [0, index]。
      expect(_decode(base..['wrong_count'] = 99)!.wrongCount, 2);
    });

    test('空串 / 非 JSON / 非对象 一律返回 null', () {
      expect(decodeReviewSessionSnapshot('', now: _now), isNull);
      expect(decodeReviewSessionSnapshot('{not json', now: _now), isNull);
      expect(decodeReviewSessionSnapshot('[1,2,3]', now: _now), isNull);
    });

    test('未知版本整段丢弃', () {
      expect(_decode(_validJson(version: 2)), isNull);
      expect(_decode(_validJson(version: null)), isNull);
    });

    test('词序损坏：空、重复、非正数、超上限、非 int 都丢弃', () {
      expect(_decode(_validJson(wordIds: const [])), isNull);
      expect(_decode(_validJson(wordIds: const [1, 1, 2])), isNull);
      expect(_decode(_validJson(wordIds: const [0, 1])), isNull);
      expect(_decode(_validJson(wordIds: const ['1', 2])), isNull);
      expect(_decode(_validJson(wordIds: List<int>.generate(reviewSessionCap + 1, (i) => i + 1))), isNull);
    });

    test('步数越界 / 已评分不是词序子集 / 已评分多于步数 都丢弃', () {
      expect(_decode(_validJson(index: -1)), isNull);
      expect(_decode(_validJson(index: 5)), isNull);
      expect(_decode(_validJson(index: null)), isNull);
      expect(_decode(_validJson(ratedIds: const [9])), isNull);
      expect(_decode(_validJson(index: 0, ratedIds: const [1])), isNull);
    });

    test('pending 损坏：未知词 / 已评分词 / correct 非 bool 都丢弃', () {
      expect(_decode(_validJson(pending: const {'word_id': 99, 'correct': true})), isNull);
      expect(_decode(_validJson(pending: const {'word_id': 1, 'correct': true})), isNull);
      expect(_decode(_validJson(pending: const {'word_id': 2, 'correct': 'yes'})), isNull);
      expect(_decode(_validJson(pending: 42)), isNull);
    });

    test('没有 pending 时允许为 null', () {
      expect(_decode(_validJson(pending: null)), isNotNull);
    });

    test('开局事实损坏：非 bool / 有到期词但到期数为 0 / 词序超过到期数', () {
      expect(_decode(_validJson(hadDueAtStart: 'true')), isNull);
      expect(_decode(_validJson(hadDueAtStart: true, dueAtStart: 0)), isNull);
      expect(_decode(_validJson(hadDueAtStart: true, dueAtStart: 2)), isNull);
      expect(_decode(_validJson(hadDueAtStart: false, dueAtStart: 0)), isNotNull);
    });

    test('时间戳：超 24 小时、明显未来、缺失都丢弃', () {
      final stale = _now.subtract(reviewSessionSnapshotMaxAge + const Duration(minutes: 1)).millisecondsSinceEpoch;
      final future = _now.add(const Duration(minutes: 30)).millisecondsSinceEpoch;
      expect(_decode(_validJson(updatedAt: stale)), isNull);
      expect(_decode(_validJson(updatedAt: future)), isNull);
      expect(_decode(_validJson(updatedAt: 0)), isNull);
    });

    test('容差内的时间戳（略早 / 略晚于本机）可接受', () {
      final skew = _now.add(const Duration(minutes: 2)).millisecondsSinceEpoch;
      expect(_decode(_validJson(updatedAt: skew)), isNotNull);
      final justFresh = _now.subtract(reviewSessionSnapshotMaxAge - const Duration(minutes: 1)).millisecondsSinceEpoch;
      expect(_decode(_validJson(updatedAt: justFresh)), isNotNull);
    });

    test('字段缺失（缺 session_id / 缺 rated_ids）丢弃', () {
      final noSession = _validJson()..remove('session_id');
      final noRated = _validJson()..remove('rated_ids');
      expect(_decode(noSession), isNull);
      expect(_decode(noRated), isNull);
    });
  });
}
