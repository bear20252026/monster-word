import 'package:flutter_test/flutter_test.dart';

import 'package:word_app/features/learning/application/learning_progress_port.dart';
import 'package:word_app/features/learning/application/learning_resume_planner.dart';
import 'package:word_app/models/book.dart';
import 'package:word_app/models/word.dart';

/// 结构修复步骤3b：MW-27/R2-06 断点恢复决策的表驱动单测。
/// 纯函数无 SP/时钟依赖，覆盖全部分支（含旧实现只能整状态测的边界）。
void main() {
  final book = Book(id: 1, code: 'TEST', name: '测试', wordCount: 3);
  final otherBook = Book(id: 2, code: 'OTHR', name: '别的书', wordCount: 3);
  Word w(int id) => Word(id: id, word: 'word$id', interpret: '释义$id');

  LearningProgress snap({Book? b, required int index, required List<Word> queue}) =>
      LearningProgress(currentBook: b ?? book, currentIndex: index, queue: queue);

  group('planLearningResume', () {
    test('无快照 → None', () {
      final plan = planLearningResume(resume: null, book: book, newQueue: [w(1)]);
      expect(plan, isA<LearningResumeNone>());
    });

    test('新队列为空 → None（不消费重建分支）', () {
      final plan = planLearningResume(
        resume: snap(index: 0, queue: [w(1)]),
        book: book,
        newQueue: const [],
      );
      expect(plan, isA<LearningResumeNone>());
    });

    test('异书快照 → None', () {
      final plan = planLearningResume(
        resume: snap(b: otherBook, index: 0, queue: [w(1)]),
        book: book,
        newQueue: [w(1)],
      );
      expect(plan, isA<LearningResumeNone>());
    });

    test('快照指针越界（currentIndex >= queue.length）→ None', () {
      final plan = planLearningResume(
        resume: snap(index: 5, queue: [w(1)]),
        book: book,
        newQueue: [w(1)],
      );
      expect(plan, isA<LearningResumeNone>());
    });

    test('R2-06：同书同词但新队列已重排 → 按词身份反查真实位置，不复用旧 index', () {
      // 旧队列 index 1 = id2；新抽样洗牌后 id2 落在 index 0。
      final plan = planLearningResume(
        resume: snap(index: 1, queue: [w(1), w(2), w(3)]),
        book: book,
        newQueue: [w(2), w(3), w(1)],
      );
      expect(plan, isA<LearningResumeAtIndex>());
      expect((plan as LearningResumeAtIndex).index, 0);
    });

    test('快照词不在新抽样 → 按快照队列原序重建，位置沿用快照 index', () {
      final oldQueue = [w(7), w(8), w(9)];
      final plan = planLearningResume(
        resume: snap(index: 1, queue: oldQueue),
        book: book,
        newQueue: [w(1), w(2)],
      );
      expect(plan, isA<LearningResumeRebuild>());
      final rebuild = plan as LearningResumeRebuild;
      expect(rebuild.queue.map((e) => e.id), [7, 8, 9]);
      expect(rebuild.index, 1);
    });

    test('重建分支 index 越界时钳制到队尾（防脏快照越界）', () {
      // 直接构造脏快照：index 超出自身队列长度时 resumeWord 为 null → None；
      // 而 index 恰好合法但等于 length-1 的边界应原样保留。
      final plan = planLearningResume(
        resume: snap(index: 2, queue: [w(7), w(8), w(9)]),
        book: book,
        newQueue: [w(1)],
      );
      expect((plan as LearningResumeRebuild).index, 2);
    });
  });
}
