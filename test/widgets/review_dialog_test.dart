// 测试：A-5 review_dialog dueCount==0 空态展示。
//
// 修复前：dueCount==0 时直接进入空复习页面。
// 修复后：dueCount==0 时展示友好空态「今天没有需要复习的单词」+ CTA。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:word_app/engine/fsrs6_engine.dart';
import 'package:word_app/features/learning/application/review_schedule_reader.dart';
import 'package:word_app/features/learning/data/learning_progress_repository.dart';
import 'package:word_app/features/learning/data/learning_queue_repository.dart';
import 'package:word_app/features/learning/data/review_schedule_repository.dart';
import 'package:word_app/features/learning/presentation/learning_session_state.dart';
import 'package:word_app/models/word.dart';
import 'package:word_app/repositories/fav_repository.dart';
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
/// 使用当前接口构造：queueRepository/progressRepository/reviewSchedule（公开名），
/// 其中 progress/review 采用 no-arg 真实仓储，队列仓储用轻量假件（不使用真实 IO）。
class _StubSessionState extends LearningSessionState {
  _StubSessionState() : super(
        queueRepository: LearningQueueRepository(
          wordSource: _FakeWordSource(),
          favRepository: _FakeFavRepository(),
        ),
        progressRepository: LearningProgressRepository(),
        reviewSchedule: ReviewScheduleRepository(),
      );

  @override
  int get total => 100;

  @override
  int get learnedNum => 30;
}

/// 假单词源（LearningQueueWordSource 为 interface class，需 implements）。
class _FakeWordSource implements LearningQueueWordSource {
  @override
  Future<List<Word>> getWordsByBook(int bookId, {required int limit, required int offset}) async => const [];

  @override
  Future<List<Word>> getWordsByNames(Iterable<String> words) async => const [];
}

/// 假收藏仓库（FavRepository 抽象类，需实现全部成员）。
class _FakeFavRepository implements FavRepository {
  @override
  Future<Set<String>> getFavoriteWords() async => const {};

  @override
  Future<void> addFavorite(String word) async {}

  @override
  Future<void> removeFavorite(String word) async {}

  @override
  Future<void> toggleFavorite(String word) async {}

  @override
  bool isFavorite(String word) => false;

  @override
  int get favoriteCount => 0;

  @override
  Future<List<Map<String, dynamic>>> getFavoriteSentences() async => const [];

  @override
  Future<bool> addFavoriteSentence({
    required int wordId,
    required String sentenceId,
    required String english,
    required String chinese,
    String source = '',
  }) async => true;

  @override
  Future<bool> removeFavoriteSentence(int wordId, String sentenceId) async => true;

  @override
  Future<bool> toggleFavoriteSentence({
    required int wordId,
    required String sentenceId,
    required String english,
    required String chinese,
    String source = '',
  }) async => true;

  @override
  Future<bool> isFavoriteSentence(int wordId, String sentenceId) async => false;

  @override
  int get favoriteSentenceCount => 0;
}
