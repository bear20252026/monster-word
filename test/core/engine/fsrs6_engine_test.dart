// 由 Claude 团队生成 | Monster Word App

// FSRS-6 引擎公式回归网（审计跟进批次 A）。
// 参照来源：py-fsrs 官方 main 分支 fsrs/scheduler.py（2026-09-04 联网核对），
// 全部期望值由官方公式逐字复刻计算（Python IEEE754 与 Dart double 同精度）。
// 任何人改动公式导致与官方漂移，本测试即失败。
//
// 官方公式清单（w[i] 为权重）：
//   DECAY  = -w[20]
//   FACTOR = 0.9^(1/DECAY) - 1
//   R      = (1 + FACTOR·t/S)^DECAY
//   S0(G)  = w[G-1]
//   D0(G)  = w4 - e^(w5·(G-1)) + 1
//   D'(D,G)= w7·D0(4) + (1-w7)·(D + (10-D)·(-w6·(G-3))/9)
//   S'_st  = S·e^(w17·(G-3+w18))·S^(-w19)，Hard/Good/Easy 时增长因子 max(·,1)
//   S'_rec = S·(1 + e^w8·(11-D)·S^(-w9)·(e^((1-R)·w10)-1)·hard(w15)·easy(w16))
//   S'_fgt = min(w11·D^(-w12)·((S+1)^w13-1)·e^((1-R)·w14), S/e^(w17·w18))
//   I      = round(S/FACTOR·(r^(1/DECAY)-1))，钳制 [1, 36500]

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:word_app/core/engine/fsrs6_engine.dart';

const _officialWeights = [
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
  0.1542,
];

FsrsCard _card({double stability = 2.3065, double difficulty = 5.0, bool isNew = false, int elapsedDays = 5}) {
  final now = DateTime.now();
  return FsrsCard(
    word: 'test',
    stability: stability,
    difficulty: difficulty,
    isNew: isNew,
    lastReview: now.subtract(Duration(days: elapsedDays)),
    dueDate: now,
  );
}

void main() {
  group('FSRS-6 官方常量锁定（py-fsrs scheduler.py）', () {
    test('DECAY = -w20 = -0.1542', () {
      expect(Fsrs6Engine().decay, -0.1542);
    });

    test('FACTOR = 0.9^(1/DECAY)-1 ≈ 0.9803464944', () {
      expect(Fsrs6Engine().factor, closeTo(0.9803464944134797, 1e-12));
    });

    test('21 个默认权重与官方 DEFAULT_PARAMETERS 逐位一致', () {
      final engine = Fsrs6Engine();
      expect(engine.weights.length, 21);
      for (var i = 0; i < _officialWeights.length; i++) {
        expect(engine.weights[i], _officialWeights[i], reason: 'w[$i] 与官方漂移');
      }
    });
  });

  group('初始稳定性 S0(G) = w[G-1]', () {
    final engine = Fsrs6Engine();
    test('again=0.212 / hard=1.2931 / good=2.3065 / easy=8.2956', () {
      final newCard = FsrsCard(word: 'w', lastReview: DateTime.now(), dueDate: DateTime.now());
      expect(engine.review(newCard, FsrsRating.again).stability, 0.212);
      final c2 = FsrsCard(word: 'w', lastReview: DateTime.now(), dueDate: DateTime.now());
      expect(engine.review(c2, FsrsRating.hard).stability, 1.2931);
      final c3 = FsrsCard(word: 'w', lastReview: DateTime.now(), dueDate: DateTime.now());
      expect(engine.review(c3, FsrsRating.good).stability, 2.3065);
      final c4 = FsrsCard(word: 'w', lastReview: DateTime.now(), dueDate: DateTime.now());
      expect(engine.review(c4, FsrsRating.easy).stability, 8.2956);
    });
  });

  group('初始难度 D0(G) = w4 - e^(w5·(G-1)) + 1（钳制 [1,10]）', () {
    test('again=6.4133 / hard=5.1121707 / good=2.1181039 / easy 钳到 1.0', () {
      final engine = Fsrs6Engine();
      final cases = <(FsrsRating, double)>[
        (FsrsRating.again, 6.4133),
        (FsrsRating.hard, 5.112170705601056),
        (FsrsRating.good, 2.118103970459016),
        (FsrsRating.easy, 1.0), // 原始值 -4.7716 被钳到下界
      ];
      for (final (rating, expected) in cases) {
        final card = FsrsCard(word: 'w', lastReview: DateTime.now(), dueDate: DateTime.now());
        expect(engine.review(card, rating).difficulty, closeTo(expected, 1e-9), reason: '$rating 初始难度漂移');
      }
    });
  });

  group('retrievability R = (1 + FACTOR·t/S)^DECAY', () {
    test('R(t=5, S=2.3065) = 0.8388614268', () {
      final r = Fsrs6Engine().getRetrievability(_card(elapsedDays: 5));
      expect(r, closeTo(0.8388614268145294, 1e-9));
    });

    test('R(t=30, S=2.3065) = 0.6675263338', () {
      final r = Fsrs6Engine().getRetrievability(_card(elapsedDays: 30));
      expect(r, closeTo(0.6675263338730357, 1e-9));
    });

    test('R(t=S) = 0.9（stability 语义不变量）', () {
      // S 的定义：R 降至 0.9 所需天数——官方公式在该点必须精确成立
      final engine = Fsrs6Engine();
      final factor = engine.factor;
      final decay = engine.decay;
      final r = pow(1.0 + factor * 2.3065 / 2.3065, decay).toDouble();
      expect(r, closeTo(0.9, 1e-12));
    });

    test('新词 / elapsed=0 返回 1.0', () {
      final engine = Fsrs6Engine();
      expect(engine.getRetrievability(FsrsCard(word: 'w', lastReview: DateTime.now(), dueDate: DateTime.now())), 1.0);
      expect(engine.getRetrievability(_card(elapsedDays: 0)), 1.0);
    });
  });

  group('难度更新 D\'（线性阻尼 + 均值回归），D=5 跨天', () {
    final engine = Fsrs6Engine();
    test('四档评分官方值', () {
      final cases = <(FsrsRating, double)>[
        (FsrsRating.again, 8.341762369296838),
        (FsrsRating.hard, 6.665995369296838),
        (FsrsRating.good, 4.9902283692968386),
        (FsrsRating.easy, 3.3144613692968385),
      ];
      for (final (rating, expected) in cases) {
        final updated = engine.review(_card(), rating);
        expect(updated.difficulty, closeTo(expected, 1e-9), reason: '$rating 难度更新漂移');
      }
    });
  });

  group('同日短时稳定性（w17/w18/w19）', () {
    final engine = Fsrs6Engine();
    test('again=0.77508398 / hard=good=2.3065（增长因子钳 1）/ easy=3.94605406', () {
      final cases = <(FsrsRating, double)>[
        (FsrsRating.again, 0.7750839828558984),
        (FsrsRating.hard, 2.3065),
        (FsrsRating.good, 2.3065),
        (FsrsRating.easy, 3.946054067969477),
      ];
      for (final (rating, expected) in cases) {
        final updated = engine.review(_card(elapsedDays: 0), rating);
        expect(updated.stability, closeTo(expected, 1e-9), reason: '$rating 同日稳定性漂移');
      }
    });
  });

  group('跨天回忆稳定性 S\'_rec（S=2.3065, D=5, t=5）', () {
    final engine = Fsrs6Engine();
    test('hard=8.75040522 / good=13.02134074 / easy=22.37432522', () {
      final cases = <(FsrsRating, double)>[
        (FsrsRating.hard, 8.750405219997022), // w15 hard penalty
        (FsrsRating.good, 13.0213407382724),
        (FsrsRating.easy, 22.37432521871038), // w16 easy bonus
      ];
      for (final (rating, expected) in cases) {
        final updated = engine.review(_card(), rating);
        expect(updated.stability, closeTo(expected, 1e-9), reason: '$rating 回忆稳定性漂移');
      }
    });
  });

  group('遗忘稳定性 S\'_fgt = min(长期项, 短期项)', () {
    final engine = Fsrs6Engine();
    test('t=5: min(0.64753250, 2.19516063) = 0.64753250', () {
      final updated = engine.review(_card(), FsrsRating.again);
      expect(updated.stability, closeTo(0.6475325061206791, 1e-9));
    });

    test('t=30: min(0.85883827, 2.19516063) = 0.85883827', () {
      final updated = engine.review(_card(elapsedDays: 30), FsrsRating.again);
      expect(updated.stability, closeTo(0.8588382711340833, 1e-9));
    });
  });

  group('间隔公式 I = round(S/FACTOR·(r^(1/DECAY)-1))，钳制 [1, 36500]', () {
    test('新卡 Good：S=2.3065 → I=2 天', () {
      final engine = Fsrs6Engine();
      final card = FsrsCard(word: 'w', lastReview: DateTime.now(), dueDate: DateTime.now());
      expect(engine.review(card, FsrsRating.good).scheduledDays, 2);
    });

    test('新卡 Easy：S=8.2956 → I=8 天', () {
      final engine = Fsrs6Engine();
      final card = FsrsCard(word: 'w', lastReview: DateTime.now(), dueDate: DateTime.now());
      expect(engine.review(card, FsrsRating.easy).scheduledDays, 8);
    });

    test('间隔不变量：按 I 天后检索率应回到目标 0.9（±轮数误差）', () {
      final engine = Fsrs6Engine();
      final card = FsrsCard(word: 'w', lastReview: DateTime.now(), dueDate: DateTime.now());
      final updated = engine.review(card, FsrsRating.good);
      final r = pow(1.0 + engine.factor * updated.scheduledDays / updated.stability, engine.decay).toDouble();
      expect(r, closeTo(0.9, 0.02), reason: '间隔公式未按目标留存率反解');
    });
  });

  group('review 流程状态维护', () {
    test('again 清零 repetitions，其余递增；reviewCount 恒增；isNew 置 false', () {
      final engine = Fsrs6Engine();
      final card = FsrsCard(word: 'w', lastReview: DateTime.now(), dueDate: DateTime.now(), repetitions: 3);
      final again = engine.review(card, FsrsRating.again);
      expect(again.repetitions, 0);
      expect(again.reviewCount, 1);
      expect(again.isNew, isFalse);
      final good = engine.review(card, FsrsRating.good);
      expect(good.repetitions, 4);
    });

    test('原卡片不被修改（不可变语义）', () {
      final engine = Fsrs6Engine();
      final card = FsrsCard(word: 'w', lastReview: DateTime.now(), dueDate: DateTime.now());
      engine.review(card, FsrsRating.good);
      expect(card.isNew, isTrue);
      expect(card.stability, 0);
    });
  });
}
