// 测试：A-5 review_dialog dueCount==0 空态展示。
//
// 修复前：dueCount==0 时直接进入空复习页面。
// 修复后：dueCount==0 时展示友好空态「今天没有需要复习的单词」+ CTA。
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:word_app/engine/fsrs6_engine.dart';
import 'package:word_app/features/learning/application/choice_generator_port.dart';
import 'package:word_app/features/learning/application/learning_progress_port.dart';
import 'package:word_app/features/learning/application/learning_queue_port.dart';
import 'package:word_app/features/learning/application/review_schedule_reader.dart';
import 'package:word_app/features/learning/application/review_schedule_writer_port.dart';
import 'package:word_app/features/learning/presentation/learning_session_state.dart';
import 'package:word_app/models/book.dart';
import 'package:word_app/models/word.dart';
import 'package:word_app/widgets/review_dialog.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('A-5: review_dialog dueCount==0 空态', () {
    testWidgets('dueCount==0 时展示友好空态而非空复习', (tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<ReviewScheduleReader>.value(
              value: _StubScheduleReader(dueCount: 0),
            ),
            ChangeNotifierProvider<LearningSessionState>.value(
              value: _StubSessionState(),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SizedBox.shrink(),
            ),
          ),
        ),
      );

      // 触发弹窗
      showReviewDialog(tester.element(find.byType(SizedBox)));
      await tester.pumpAndSettle();

      // 验证空态文案展示
      expect(find.text('今天没有需要复习的单词'), findsOneWidget);
      expect(find.text('太棒了！今天的复习任务已完成，休息一下吧。'), findsOneWidget);
      // 验证 CTA 按钮
      expect(find.text('好的'), findsOneWidget);
      // 验证复习按钮不展示（未进入空复习）
      expect(find.text('开始复习'), findsNothing);
    });

    testWidgets('dueCount>0 时展示统计卡片与按钮', (tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<ReviewScheduleReader>.value(
              value: _StubScheduleReader(dueCount: 5),
            ),
            ChangeNotifierProvider<LearningSessionState>.value(
              value: _StubSessionState(),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SizedBox.shrink(),
            ),
          ),
        ),
      );

      showReviewDialog(tester.element(find.byType(SizedBox)));
      await tester.pumpAndSettle();

      // 验证统计卡片展示
      expect(find.text('今日已学'), findsOneWidget);
      expect(find.text('今日复习'), findsOneWidget);
      // 验证按钮展示
      expect(find.text('继续学习'), findsOneWidget);
      expect(find.text('开始复习'), findsOneWidget);
      // 验证空态文案不展示
      expect(find.text('今天没有需要复习的单词'), findsNothing);
    });
  });
}

/// 测试替身：ReviewScheduleReader（抽象类）
class _StubScheduleReader extends ReviewScheduleReader {
  final int _dueCount;

  _StubScheduleReader({required this._dueCount});

  @override
  FsrsCard? cardFor(String word) => null;

  @override
  String getStatusText(FsrsCard card) => '';

  @override
  String getDifficultyText(FsrsCard card) => '';

  @override
  int get todayLearnCount => 3;

  @override
  int get todayReviewCount => _dueCount;

  @override
  int get dueCount => _dueCount;

  @override
  int get activeDateCount => 0;

  @override
  Map<String, int> get memoryStats => {};

  @override
  List<Word> dueWordsFor(Iterable<Word> words) => [];
}

/// 测试替身：LearningSessionState
///
/// 通过端口构造：queuePort/progressPort/reviewSchedulePort/choicePort，
/// 其中队列用假件，进度/评分用轻量假件（不使用真实 IO）。
class _StubSessionState extends LearningSessionState {
  _StubSessionState() : super(
        queuePort: _StubQueuePort(),
        progressPort: _StubProgressPort(),
        reviewSchedulePort: _StubReviewScheduleWriterPort(),
        choicePort: _StubChoicePort(),
      );

  @override
  int get total => 100;

  @override
  int get learnedNum => 30;
}

class _StubQueuePort implements LearningQueuePort {
  @override
  Future<List<Word>> loadBook(Book book, {int? limit, required bool shuffle}) async => const [];

  @override
  Future<List<Word>> loadFavoriteWords({required List<Word> currentQueue}) async => const [];
}

class _StubProgressPort implements LearningProgressPort {
  @override
  Future<void> save({
    required Book currentBook,
    required int currentIndex,
    required List<Word> queue,
  }) async {}

  @override
  Future<LearningProgress?> load() async => null;
}

class _StubReviewScheduleWriterPort implements ReviewScheduleWriterPort {
  @override
  Future<void> rateWord({required String word, required FsrsRating rating}) async {}

  @override
  Future<void> forget(String word) async {}
}

class _StubChoicePort implements ChoiceGeneratorPort {
  @override
  List<ChoiceCandidate> generate({
    required ChoiceCandidate correct,
    required Iterable<ChoiceCandidate> candidates,
    Random? random,
  }) =>
      [correct];
}
