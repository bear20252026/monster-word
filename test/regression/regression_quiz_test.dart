// ============================================================
// 回归测试 — 学习/出题链路（REG-QUIZ-xxx）
// 台账：docs/regression_ledger.md
// ============================================================
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:word_app/features/learning/application/choice_generator_port.dart';
import 'package:word_app/features/learning/application/learning_progress_port.dart';
import 'package:word_app/features/learning/application/learning_queue_port.dart';
import 'package:word_app/features/learning/domain/choice_generator.dart';
import 'package:word_app/features/learning/domain/definition_formatter.dart';
import 'package:word_app/features/learning/presentation/learning_session_state.dart';
import 'package:word_app/core/engine/fsrs6_engine.dart';
import 'package:word_app/features/learning/application/review_schedule_writer_port.dart';
import 'package:word_app/models/book.dart';
import 'package:word_app/models/word.dart';

class _FakeQueuePort implements LearningQueuePort {
  _FakeQueuePort(this._words);
  final List<Word> _words;

  @override
  Future<List<Word>> loadFavoriteWords({required List<Word> currentQueue}) async => const [];

  @override
  Future<List<Word>> loadBook(Book book, {int? limit, required bool shuffle}) async =>
      List<Word>.from(_words);
}

class _FakeProgressPort implements LearningProgressPort {
  @override
  Future<LearningProgress?> load() async => null;

  @override
  Future<void> save({required Book currentBook, required int currentIndex, required List<Word> queue}) async {}
}

class _RealChoicePort implements ChoiceGeneratorPort {
  @override
  List<ChoiceCandidate> generate({
    required ChoiceCandidate correct,
    required Iterable<ChoiceCandidate> candidates,
    dynamic random,
  }) {
    return ChoiceGenerator.generate(correct: correct, candidates: candidates, random: random);
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('REG-QUIZ 出题链路回归', () {
    test('REG-QUIZ-001: extractChinese 必须兼容纯文本释义（旧格式占多数）', () {
      // 症状：四选一干扰项把全库词判为"无中文候选"，混入英文释义；
      // 根因：extractChinese 只认 JSON 结构 [{"def":[{"cn":...}]}]，
      // 对词库中占多数的纯文本 "vi. 倒塌；崩溃" 永远返回空。
      // 修复：commit 2eabee0 增加含 CJK 字符的纯文本回退。
      expect(DefinitionFormatter.extractChinese('vi. 倒塌；昏倒；崩溃'), isNotEmpty,
          reason: '纯文本释义是词库主流格式，判定失败会劣化全部四选一的干扰项质量');
      // 多行释义取第一行含中文的部分
      expect(DefinitionFormatter.extractChinese('n. 学位连领帽\nv. 覆盖'), contains('学位连领帽'));
      // 空壳与 JSON 两种形态回归
      expect(DefinitionFormatter.extractChinese(''), isEmpty);
      expect(DefinitionFormatter.extractChinese('""'), isEmpty);
      expect(DefinitionFormatter.extractChinese('[{"def":[{"cn":"明显的"}]}]'), '明显的');
      // 纯英文释义仍判为无中文（不得混入四选一）
      expect(DefinitionFormatter.extractChinese('n. something that is obvious'), isEmpty);
    });

    test('REG-QUIZ-002: 学习队列必须过滤无中文释义的空壳词', () async {
      // 症状：GRE 等书 45% 词库空壳词进队列 → 四选一残缺、详情页空白；
      // 修复：commit 2eabee0 _replaceQueue 过滤。
      final session = LearningSessionState(
        queuePort: _FakeQueuePort([
          Word(id: 1, word: 'solid', interpret: 'vt. 巩固'),
          Word(id: 2, word: 'hollow'), // 空释义
          Word(id: 3, word: 'empty', interpret: '""'), // JSON 空壳
        ]),
        progressPort: _FakeProgressPort(),
        reviewSchedulePort: _FakeSchedulePort(),
        choicePort: _RealChoicePort(),
      );
      await session.loadBook(Book(id: 1, code: 'T', name: '测试', wordCount: 3), shuffle: false);

      expect(session.queue.map((w) => w.word), ['solid'],
          reason: '空释义词进入队列 = 四选一残缺 + 详情页空白，宁少勿缺');
      expect(session.currentWord?.word, 'solid');
    });

    test('REG-QUIZ-003: 四选项恰好一个正确且含中文（混淆性底线）', () {
      final choices = ChoiceGenerator.generate(
        correct: ChoiceCandidate(word: 'target', interpret: 'n. 目标'),
        candidates: [
          ChoiceCandidate(word: 'noise', interpret: 'n. 噪音'),
          ChoiceCandidate(word: 'reach', interpret: 'v. 到达'),
          ChoiceCandidate(word: 'aimless', interpret: 'adj. 无目标的'),
          ChoiceCandidate(word: 'noisy', interpret: 'adj. 嘈杂的'),
        ],
      );
      expect(choices, hasLength(4));
      expect(choices.where((c) => c.word == 'target'), hasLength(1));
      expect(choices.map((c) => c.interpret).toSet(), hasLength(4), reason: '四个选项释义必须互不相同');
    });
  });
}

class _FakeSchedulePort implements ReviewScheduleWriterPort {
  @override
  Future<void> rateWord({required String word, required FsrsRating rating}) async {}

  @override
  Future<void> forget(String word) async {}
}
