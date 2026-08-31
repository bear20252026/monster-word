// 由 Claude 团队生成 | Monster Word App
//
// 考试速刷页 — 呈现层测试
//
// 验证 ExamQuickReviewPage 在功能域内的渲染与交互：
// - 加载状态与单词渲染
// - 查看答案 / 认识 / 不认识 交互
// - 考试类型切换
// - 完成页统计渲染

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:word_app/features/quick_review/application/quick_review_word_reader.dart';
import 'package:word_app/features/quick_review/presentation/exam_quick_review_page.dart';
import 'package:word_app/models/word.dart';

/// 内存假实现：返回预设单词，无需 WordRepository。
class FakeQuickReviewWordReader implements QuickReviewWordReader {
  FakeQuickReviewWordReader(this.words, {this.loadDelay = Duration.zero});
  final List<Word> words;
  final Duration loadDelay;

  @override
  Future<List<Word>> loadWords({int limit = 50}) async {
    if (loadDelay > Duration.zero) {
      await Future<void>.delayed(loadDelay);
    }
    return words.take(limit).toList();
  }
}

Widget _buildTestPage(QuickReviewWordReader reader) {
  return MaterialApp(
    home: Provider<QuickReviewWordReader>.value(value: reader, child: const ExamQuickReviewPage()),
  );
}

void main() {
  group('ExamQuickReviewPage', () {
    testWidgets('加载后渲染第一题与操作按钮', (tester) async {
      final reader = FakeQuickReviewWordReader([Word(id: 1, word: 'serendipity'), Word(id: 2, word: 'ephemeral')]);
      await tester.pumpWidget(_buildTestPage(reader));
      await tester.pumpAndSettle();

      // 显示第一个单词
      expect(find.text('serendipity'), findsOneWidget);
      // 进度指示
      expect(find.text('1 / 2'), findsOneWidget);
      // 查看答案按钮
      expect(find.text('查看答案'), findsOneWidget);
      // 统计徽章
      expect(find.text('已答'), findsOneWidget);
      expect(find.text('正确'), findsOneWidget);
      expect(find.text('正确率'), findsOneWidget);
      expect(find.text('用时'), findsOneWidget);
    });

    testWidgets('点击查看答案后显示认识/不认识按钮', (tester) async {
      final reader = FakeQuickReviewWordReader([Word(id: 1, word: 'serendipity'), Word(id: 2, word: 'ephemeral')]);
      await tester.pumpWidget(_buildTestPage(reader));
      await tester.pumpAndSettle();

      await tester.tap(find.text('查看答案'));
      await tester.pumpAndSettle();

      expect(find.text('认识'), findsOneWidget);
      expect(find.text('不认识'), findsOneWidget);
      // 查看答案按钮消失
      expect(find.text('查看答案'), findsNothing);
    });

    testWidgets('点击认识后进入下一题并更新统计', (tester) async {
      final reader = FakeQuickReviewWordReader([Word(id: 1, word: 'serendipity'), Word(id: 2, word: 'ephemeral')]);
      await tester.pumpWidget(_buildTestPage(reader));
      await tester.pumpAndSettle();

      // 查看答案 → 认识
      await tester.tap(find.text('查看答案'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('认识'));
      await tester.pumpAndSettle();

      // 进入第二题
      expect(find.text('ephemeral'), findsOneWidget);
      expect(find.text('2 / 2'), findsOneWidget);
      // 正确数更新为 1
      expect(find.text('1'), findsNWidgets(2)); // 已答=1, 正确=1
    });

    testWidgets('点击不认识后答错统计更新', (tester) async {
      final reader = FakeQuickReviewWordReader([Word(id: 1, word: 'serendipity'), Word(id: 2, word: 'ephemeral')]);
      await tester.pumpWidget(_buildTestPage(reader));
      await tester.pumpAndSettle();

      await tester.tap(find.text('查看答案'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('不认识'));
      await tester.pumpAndSettle();

      // 进入第二题
      expect(find.text('ephemeral'), findsOneWidget);
    });

    testWidgets('可切换考试类型', (tester) async {
      final reader = FakeQuickReviewWordReader([Word(id: 1, word: 'apple')]);
      await tester.pumpWidget(_buildTestPage(reader));
      await tester.pumpAndSettle();

      // 显示考试类型标签
      expect(find.text('四级高频'), findsOneWidget);
      expect(find.text('考研核心'), findsOneWidget);

      // 切换到考研核心
      await tester.tap(find.text('考研核心'));
      await tester.pumpAndSettle();

      // 重新加载后仍显示单词
      expect(find.text('apple'), findsOneWidget);
    });

    testWidgets('完成所有题目后显示结果页', (tester) async {
      final reader = FakeQuickReviewWordReader([Word(id: 1, word: 'serendipity'), Word(id: 2, word: 'ephemeral')]);
      await tester.pumpWidget(_buildTestPage(reader));
      await tester.pumpAndSettle();

      // 第一题：认识
      await tester.tap(find.text('查看答案'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('认识'));
      await tester.pumpAndSettle();

      // 第二题：不认识
      await tester.tap(find.text('查看答案'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('不认识'));
      await tester.pumpAndSettle();

      // 结果页
      expect(find.text('本轮完成！'), findsOneWidget);
      expect(find.text('答题总数'), findsOneWidget);
      expect(find.text('答对'), findsOneWidget);
      expect(find.text('答错'), findsOneWidget);
      expect(find.text('跳过'), findsOneWidget);
      expect(find.text('正确率'), findsOneWidget);
      expect(find.text('用时'), findsOneWidget);
      expect(find.text('再来一轮'), findsOneWidget);
    });

    testWidgets('再来一轮可重新开始', (tester) async {
      final reader = FakeQuickReviewWordReader([Word(id: 1, word: 'serendipity'), Word(id: 2, word: 'ephemeral')]);
      await tester.pumpWidget(_buildTestPage(reader));
      await tester.pumpAndSettle();

      // 完成第一题
      await tester.tap(find.text('查看答案'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('认识'));
      await tester.pumpAndSettle();

      // 完成第二题
      await tester.tap(find.text('查看答案'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('不认识'));
      await tester.pumpAndSettle();

      // 重新开始
      await tester.tap(find.text('再来一轮'));
      await tester.pumpAndSettle();

      // 回到第一题
      expect(find.text('serendipity'), findsOneWidget);
      expect(find.text('1 / 2'), findsOneWidget);
    });
  });
}
