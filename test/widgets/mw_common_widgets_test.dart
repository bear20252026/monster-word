// 商业观感组件测试：骨架屏 / 空状态 / 错误边界
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:word_app/widgets/common/mw_empty_state.dart';
import 'package:word_app/widgets/common/mw_error_boundary.dart' show mwErrorBuilder;
import 'package:word_app/widgets/common/mw_skeleton.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  group('MwSkeleton 骨架屏', () {
    testWidgets('页面骨架渲染指定数量的列表行', (tester) async {
      await tester.pumpWidget(wrap(const MwSkeletonPage(rows: 3)));
      await tester.pump();
      // 每行 2 块（头像 + 文字行），首屏另有 1 个标题块
      expect(find.byType(MwSkeletonBlock), findsNWidgets(1 + 3 * 3));
    });

    testWidgets('网格骨架渲染指定卡片数', (tester) async {
      await tester.pumpWidget(wrap(const MwSkeletonGrid(count: 4)));
      await tester.pump();
      expect(find.byType(MwSkeletonBlock), findsNWidgets(4 * 2));
    });
  });

  group('MwEmptyState 空状态', () {
    testWidgets('默认文案 + 预置图标渲染', (tester) async {
      await tester.pumpWidget(wrap(const MwEmptyState(kind: MwEmptyKind.search)));
      expect(find.text('没有找到相关内容'), findsOneWidget);
      expect(find.byIcon(Icons.search_off_rounded), findsOneWidget);
    });

    testWidgets('自定义文案 + 行动按钮可点击', (tester) async {
      var tapped = false;
      await tester.pumpWidget(wrap(MwEmptyState(
        title: '自定义标题',
        subtitle: '自定义副标题',
        actionLabel: '重试',
        onAction: () => tapped = true,
      )));
      expect(find.text('自定义标题'), findsOneWidget);
      await tester.tap(find.text('重试'));
      expect(tapped, isTrue);
    });
  });

  group('全局错误边界', () {
    testWidgets('widget 异常渲染为友好错误页而非灰字', (tester) async {
      final original = ErrorWidget.builder;
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (d) {}; // 吞掉预期中的 boom，不让框架把测试判负
      ErrorWidget.builder = mwErrorBuilder; // debug 下直接注入（installMwErrorBoundary 仅 release 生效）
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => throw FlutterError('boom'),
                ),
              ),
              child: const Text('crash'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('crash'));
      await tester.pumpAndSettle();
      expect(find.text('页面出错了'), findsOneWidget, reason: 'widget 崩溃必须降级为友好错误页');
      expect(find.text('返回上一页'), findsOneWidget);
      FlutterError.onError = originalOnError;
      ErrorWidget.builder = original;
    });
  });
}
