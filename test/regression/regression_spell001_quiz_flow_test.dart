import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:word_app/features/learning/presentation/spelling_quiz_flow.dart';
import 'package:word_app/models/word.dart';
import 'package:word_app/theme/skin_system.dart';

/// REG-SPELL-001：拼写/听写/快速拼写共享测验脚手架的行为契约。
///
/// 三页（spell/dictation/quick_spell）共用 SpellingQuizController +
/// SpellingQuizScaffold，此处锁定判分/推进/结束/重开的核心行为，
/// 防止后续改动破坏：
/// 1. 答对 → 「回答正确」+ 对勾图标；答错 → 展示「正确答案：单词」；
/// 2. 「下一个」推进进度，走完进入结果视图（正确率统计）；
/// 3. 「再来一次」复位计数重新开始；
/// 4. 空词表 → 空态页 + 返回首页按钮（不白屏）。
void main() {
  List<Word> words() => [
    Word(
      id: 1,
      word: 'apple',
      mainWord: 'apple',
      interpret: 'n. 苹果',
      ukPron: 'ˈæpl',
      usPron: 'ˈæpl',
      phrase: '',
      example: '',
      confuse: '',
    ),
    Word(
      id: 2,
      word: 'banana',
      mainWord: 'banana',
      interpret: 'n. 香蕉',
      ukPron: 'bəˈnɑːnə',
      usPron: 'bəˈnænə',
      phrase: '',
      example: '',
      confuse: '',
    ),
  ];

  Widget harness(SpellingQuizController controller) => MaterialApp(
    home: SkinProvider(
      skin: SkinSystem(),
      child: SpellingQuizScaffold(
        controller: controller,
        title: '拼写练习',
        inputHint: '输入英文单词',
        promptBuilder: (context, word) => Text('prompt:${word.word}'),
      ),
    ),
  );

  testWidgets('答对显示正确反馈，答错显示正确答案，计数准确', (tester) async {
    final quiz = SpellingQuizController();
    await tester.pumpWidget(harness(quiz));
    quiz.seed(words());
    await tester.pumpAndSettle();

    expect(find.text('1 / 2'), findsOneWidget);
    expect(find.text('prompt:apple'), findsOneWidget);

    // 第一词答对
    await tester.enterText(find.byType(TextField), 'Apple'); // 大小写不敏感
    await tester.tap(find.text('确认'));
    await tester.pumpAndSettle();
    expect(find.text('回答正确'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);

    // 第二词答错
    await tester.tap(find.text('下一个'));
    await tester.pumpAndSettle();
    expect(find.text('2 / 2'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'banna');
    await tester.tap(find.text('确认'));
    await tester.pumpAndSettle();
    expect(find.text('正确答案：banana'), findsOneWidget);
    expect(find.byIcon(Icons.cancel_rounded), findsOneWidget);
  });

  testWidgets('走完全部词后进入结果视图，「再来一次」复位重开', (tester) async {
    final quiz = SpellingQuizController();
    await tester.pumpWidget(harness(quiz));
    quiz.seed(words());
    await tester.pumpAndSettle();

    // 两词全对
    for (final w in ['apple', 'banana']) {
      await tester.enterText(find.byType(TextField), w);
      await tester.tap(find.text('确认'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('下一个'));
      await tester.pumpAndSettle();
    }

    // 结果视图：统计 + 重开
    expect(find.text('练习完成'), findsOneWidget);
    expect(find.text('正确率 100.0%'), findsOneWidget);
    expect(find.text('再来一次'), findsOneWidget);

    await tester.tap(find.text('再来一次'));
    await tester.pumpAndSettle();
    expect(find.text('1 / 2'), findsOneWidget);
    expect(find.text('prompt:apple'), findsOneWidget);
  });

  testWidgets('空词表显示空态页与返回首页按钮', (tester) async {
    final quiz = SpellingQuizController();
    await tester.pumpWidget(harness(quiz));
    quiz.seed(const []);
    await tester.pumpAndSettle();

    expect(find.text('暂无待学习单词'), findsOneWidget);
    expect(find.text('返回首页'), findsOneWidget);
  });

  testWidgets('finishByTime 直接结束会话（快速拼写时间到）', (tester) async {
    final quiz = SpellingQuizController();
    await tester.pumpWidget(harness(quiz));
    quiz.seed(words());
    await tester.pumpAndSettle();

    quiz.finishByTime();
    await tester.pumpAndSettle();

    expect(find.text('练习完成'), findsOneWidget);
    // 无作答记录时正确率 0%
    expect(find.text('正确率 0.0%'), findsOneWidget);
  });
}
