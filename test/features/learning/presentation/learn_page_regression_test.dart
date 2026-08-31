import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:word_app/core/audio/audio_playback_state.dart';
import 'package:word_app/features/learning/application/choice_generator_port.dart';
import 'package:word_app/features/learning/application/learning_progress_port.dart';
import 'package:word_app/features/learning/application/learning_queue_port.dart';
import 'package:word_app/features/learning/data/repository_review_schedule_writer_port.dart';
import 'package:word_app/features/learning/data/review_schedule_repository.dart';
import 'package:word_app/features/learning/domain/choice_generator.dart';
import 'package:word_app/features/learning/presentation/learning_session_state.dart';
import 'package:word_app/models/book.dart';
import 'package:word_app/models/word.dart';
import 'package:word_app/features/learning/presentation/learn_page.dart';
import 'package:word_app/core/audio/audio_service.dart';
import 'package:word_app/theme/skin_system.dart';

/// 假音频服务。
class _FakeAudioService implements AudioService {
  @override
  Future<void> playWordAudio(String word, {String accent = 'us', String? audioUrl}) async {}
  @override
  Future<void> playFromUrl(String url) async {}
  @override
  Future<void> stop() async {}
  @override
  bool get isPlaying => false;
  @override
  void dispose() {}
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('答对后出现"查看详解"按钮（修复背单词答对后无法跳转下一个词）', (tester) async {
    final schedule = ReviewScheduleRepository();
    await schedule.initialize();
    final session = LearningSessionState(
      queuePort: _FakeQueuePort([
        Word(id: 1, word: 'first', interpret: '第一释义'),
        Word(id: 2, word: 'second', interpret: '第二释义'),
        Word(id: 3, word: 'third', interpret: '第三释义'),
        Word(id: 4, word: 'fourth', interpret: '第四释义'),
      ]),
      progressPort: _FakeProgressPort(),
      reviewSchedulePort: RepositoryReviewScheduleWriterPort(schedule),
      choicePort: _FakeChoicePort(),
    );
    await session.loadBook(_testBook, shuffle: false);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<LearningSessionState>.value(value: session),
          ChangeNotifierProvider<AudioPlaybackState>(
            create: (_) => AudioPlaybackState(audioService: _FakeAudioService()),
          ),
        ],
        // 把 Provider 放在 MaterialApp 之上，使 push 出来的 WordDetailPage 路由也能访问。
        child: MaterialApp(
          home: SkinProvider(skin: SkinSystem(), child: const LearnPage()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 学习页面首屏：当前词 first，词义提示/选项为 "第一释义"。
    expect(find.text('查看详解'), findsNothing);

    // 点击正确选项："第一释义"（当前词 first 的释义）。
    final choiceFinder = find.text('第一释义');
    expect(choiceFinder, findsWidgets);
    await tester.tap(choiceFinder.last);
    await tester.pumpAndSettle();

    // 修复点：出现"查看详解"按钮（此前从未实现，导致答对后无法跳转下一个词）。
    expect(find.text('查看详解'), findsOneWidget);

    // "查看详解"文本位于一个 ElevatedButton 内部（证明它是真实可点的按钮）。
    expect(find.ancestor(of: find.text('查看详解'), matching: find.byType(ElevatedButton)), findsOneWidget);
  });
}

final _testBook = Book(id: 1, code: 'TEST', name: '测试', wordCount: 2);

class _FakeQueuePort implements LearningQueuePort {
  _FakeQueuePort(this._words);

  final List<Word> _words;

  @override
  Future<List<Word>> loadFavoriteWords({required List<Word> currentQueue}) async => const [];

  @override
  Future<List<Word>> loadBook(Book book, {int? limit, required bool shuffle}) async {
    final queue = List<Word>.from(_words);
    if (shuffle) {
      queue.shuffle();
    }
    return (limit == null || limit >= queue.length) ? queue : queue.sublist(0, limit);
  }
}

class _FakeProgressPort implements LearningProgressPort {
  @override
  Future<LearningProgress?> load() async => null;

  @override
  Future<void> save({required Book currentBook, required int currentIndex, required List<Word> queue}) async {}
}

class _FakeChoicePort implements ChoiceGeneratorPort {
  @override
  List<ChoiceCandidate> generate({
    required ChoiceCandidate correct,
    required Iterable<ChoiceCandidate> candidates,
    Random? random,
  }) {
    return ChoiceGenerator.generate(correct: correct, candidates: candidates, random: random);
  }
}
