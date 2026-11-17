// 第四轮审计 M4（2026-11-17）：学习评分执行器下沉回归。
// 口径：先落盘后推进引擎；硬失败引擎不动、onAgain 不触发；pendingRetry 照常推进。
import 'package:flutter_test/flutter_test.dart';

import 'package:word_app/core/engine/fsrs6_engine.dart' show FsrsRating;
import 'package:word_app/core/engine/leitner_engine.dart';
import 'package:word_app/features/learning/application/learning_rating_executor.dart';
import 'package:word_app/features/learning/application/review_schedule_writer_port.dart';
import 'package:word_app/models/mw_word_process.dart';

class _RecordingWriter implements ReviewScheduleWriterPort {
  _RecordingWriter({this.outcome = FsrsRatingOutcome.saved, this.hardFail = false});
  final FsrsRatingOutcome outcome;
  final bool hardFail;
  final List<({String word, FsrsRating rating})> calls = [];

  @override
  Future<FsrsRatingOutcome> rateWord({required String word, required FsrsRating rating}) async {
    calls.add((word: word, rating: rating));
    if (hardFail) throw FsrsRatingPersistException('降级日志也写不进');
    return outcome;
  }

  @override
  Future<void> forget(String word) async {}
}

void main() {
  LeitnerCardEngine engineWithWords() {
    final engine = LeitnerCardEngine();
    engine.init([
      MwWordProcess(id: 1, wordId: 1, word: 'alpha', interpret: '[{"t":"n.","def":[{"cn":"甲"}]}]'),
      MwWordProcess(id: 2, wordId: 2, word: 'beta', interpret: '[{"t":"n.","def":[{"cn":"乙"}]}]'),
    ]);
    return engine;
  }

  test('good 评分：先落盘再推进引擎，返回 true', () async {
    final writer = _RecordingWriter();
    final engine = engineWithWords();
    final executor = LearningRatingExecutor(engine: engine, writerPort: writer);
    final before = engine.currentWord()!.word;

    final ok = await executor.rate(word: before, rating: FsrsRating.good);

    expect(ok, isTrue);
    expect(writer.calls.single.word, before);
    expect(writer.calls.single.rating, FsrsRating.good);
    expect(engine.currentWord()!.word, isNot(before), reason: '落盘成功后引擎必须推进');
  });

  test('again 评分：onAgain 回调触发（错词记录交还 presentation）', () async {
    final writer = _RecordingWriter();
    final engine = engineWithWords();
    final executor = LearningRatingExecutor(engine: engine, writerPort: writer);
    var againCalls = 0;

    await executor.rate(word: engine.currentWord()!.word, rating: FsrsRating.again, onAgain: () => againCalls++);

    expect(againCalls, 1);
  });

  test('good/hard/easy 不触发 onAgain', () async {
    for (final rating in [FsrsRating.good, FsrsRating.hard, FsrsRating.easy]) {
      final writer = _RecordingWriter();
      final executor = LearningRatingExecutor(engine: engineWithWords(), writerPort: writer);
      var againCalls = 0;
      await executor.rate(word: 'alpha', rating: rating, onAgain: () => againCalls++);
      expect(againCalls, 0, reason: '$rating 不应触发错词回调');
    }
  });

  test('硬失败：异常上抛、引擎未推进、onAgain 不触发（P1-02 绝无假成功）', () async {
    final writer = _RecordingWriter(hardFail: true);
    final engine = engineWithWords();
    final executor = LearningRatingExecutor(engine: engine, writerPort: writer);
    final before = engine.currentWord()!.word;
    var againCalls = 0;

    await expectLater(
      executor.rate(word: before, rating: FsrsRating.again, onAgain: () => againCalls++),
      throwsA(isA<FsrsRatingPersistException>()),
    );
    expect(engine.currentWord()!.word, before, reason: '硬失败引擎必须停在本题');
    expect(againCalls, 0);
  });

  test('pendingRetry（降级日志已落）：照常推进引擎', () async {
    final writer = _RecordingWriter(outcome: FsrsRatingOutcome.pendingRetry);
    final engine = engineWithWords();
    final executor = LearningRatingExecutor(engine: engine, writerPort: writer);
    final before = engine.currentWord()!.word;

    final ok = await executor.rate(word: before, rating: FsrsRating.good);

    expect(ok, isTrue);
    expect(engine.currentWord()!.word, isNot(before));
  });
}
