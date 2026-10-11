// QA-01（第六阶段审计 MW 系列收尾）：FSRS-6 官方参考向量逐项对表。
//
// 向量来源：py-fsrs 官方 DEFAULT_PARAMETERS（与 fsrs6_engine.dart 同源权重）
// 按公式手算的精确期望值（Python 参考：math.exp/pow 双精度）：
//   S0(G) = w[G-1]
//   D0(G) = clamp(w4 - e^(w5·(G-1)) + 1)
//   短时稳定性（同日）S' = S·e^(w17·(G-3+w18))·S^(-w19)，非 again 时增量下限 1
//   回忆长时稳定性 S' = S·(1 + e^w8·(11-D)·S^(-w9)·(e^((1-R)·w10)-1)·hard·easy)
//   间隔 = round(S' / FACTOR · (0.9^(1/DECAY) - 1))，FACTOR 同式
// reviewedAt 注入固定时刻（QA-01 边界：算法对时钟不可变）。
import 'package:flutter_test/flutter_test.dart';

import 'package:word_app/core/engine/fsrs6_engine.dart';

void main() {
  final engine = Fsrs6Engine();
  // 官方默认权重下的关键标量（Python double 精度预计算）
  const factor = 0.9803461995830662; // 0.9^(1/-0.1542) - 1

  group('QA-01 FSRS-6 官方参考向量', () {
    test('初始稳定性 S0(G) = w[G-1]（21 项默认权重前 4 项）', () {
      expect(engine.weights.length, 21, reason: 'FSRS-6 为 21 项权重');
      final learned = [
        engine.learn('w1', FsrsRating.again, reviewedAt: DateTime(2026, 10, 10, 9)),
        engine.learn('w2', FsrsRating.hard, reviewedAt: DateTime(2026, 10, 10, 9)),
        engine.learn('w3', FsrsRating.good, reviewedAt: DateTime(2026, 10, 10, 9)),
        engine.learn('w4', FsrsRating.easy, reviewedAt: DateTime(2026, 10, 10, 9)),
      ];
      expect(learned[0].stability, closeTo(0.212, 1e-9));
      expect(learned[1].stability, closeTo(1.2931, 1e-9));
      expect(learned[2].stability, closeTo(2.3065, 1e-9));
      expect(learned[3].stability, closeTo(8.2956, 1e-9));
      // 全部脱离新卡态
      for (final c in learned) {
        expect(c.isNew, isFalse);
        expect(c.reviewCount, 1);
      }
    });

    test('初始难度 D0(G)（含 1-10 钳制）', () {
      final d1 = engine.learn('d1', FsrsRating.again, reviewedAt: DateTime(2026, 10, 10, 9));
      final d2 = engine.learn('d2', FsrsRating.hard, reviewedAt: DateTime(2026, 10, 10, 9));
      final d3 = engine.learn('d3', FsrsRating.good, reviewedAt: DateTime(2026, 10, 10, 9));
      final d4 = engine.learn('d4', FsrsRating.easy, reviewedAt: DateTime(2026, 10, 10, 9));
      // w4=6.4133, w5=0.8334
      expect(d1.difficulty, closeTo(6.4133, 1e-9)); // G=1 → w4 + 1 - e^0 - ... = 6.4133
      expect(d2.difficulty, closeTo(5.112171, 1e-6));
      expect(d3.difficulty, closeTo(2.118104, 1e-6));
      expect(d4.difficulty, closeTo(1.0, 1e-9), reason: 'easy 档被钳到下界 1');
    });

    test('同日短时稳定性（S=2.3065 的 good 档短时模型）', () {
      final card = engine.learn('s1', FsrsRating.good, reviewedAt: DateTime(2026, 10, 10, 9));
      // 同日再复习（间隔 0 天 → 短时模型）：good 增量钳下限 1 → S 不变
      final again = engine.review(card, FsrsRating.good, reviewedAt: DateTime(2026, 10, 10, 15));
      expect(again.stability, closeTo(2.3065, 1e-9));
      // again 档走真实短时公式：S·e^(w17·(1-3+w18))·S^(-w19) = 0.775084
      final forgot = engine.review(card, FsrsRating.again, reviewedAt: DateTime(2026, 10, 10, 15));
      expect(forgot.stability, closeTo(0.775084, 1e-6));
    });

    test('跨日回忆长时稳定性 + 间隔（官方公式链）', () {
      // 先构造 D0(good)=2.118104, S0=2.3065 的卡
      final base = engine.learn('r1', FsrsRating.good, reviewedAt: DateTime(2026, 10, 10, 9));
      // 次日复习（elapsed=1 → R = (1+FACTOR·1/S)^DECAY ≈ 0.9468，非 0.9——
      // 0.9 保持率对应 elapsed=S 天）。
      final next = engine.review(base, FsrsRating.good, reviewedAt: DateTime(2026, 10, 11, 9, 0, 1));
      // Python 双精度参考值（官方公式链 w8~w10，R≈0.946842）：
      // S' = 2.3065·(1 + e^w8·(11-D0)·S^(-w9)·(e^((1-R)·w10)-1)) ≈ 7.3153
      expect(next.stability, closeTo(7.3153, 2e-3));
      expect(next.elapsedDays, 1);
      // dueDate = reviewedAt + interval；间隔 = round(S'/FACTOR·(0.9^(1/DECAY)-1)) = round(S')
      expect(next.scheduledDays, next.stability.round());
      final expectedDue = DateTime(2026, 10, 11, 9, 0, 1).add(Duration(days: next.scheduledDays));
      expect(next.dueDate.isAtSameMomentAs(expectedDue), isTrue);
    });

    test('reviewedAt 注入：同一输入两次计算结果逐位一致（确定性）', () {
      final base = engine.learn('r2', FsrsRating.good, reviewedAt: DateTime(2026, 10, 10, 9));
      final a = engine.review(base, FsrsRating.hard, reviewedAt: DateTime(2026, 10, 13, 8));
      final b = engine.review(base, FsrsRating.hard, reviewedAt: DateTime(2026, 10, 13, 8));
      expect(a.stability, b.stability);
      expect(a.difficulty, b.difficulty);
      expect(a.dueDate, b.dueDate);
    });

    test('FACTOR 与官方公式一致（0.9^(1/DECAY)-1）', () {
      // 容差 1e-6：跨平台 libm 的 pow 实现存在末位差异（Windows/Dart vs CPython）。
      expect(engine.factor, closeTo(factor, 1e-6));
      expect(engine.decay, closeTo(-0.1542, 1e-12));
    });
  });
}
