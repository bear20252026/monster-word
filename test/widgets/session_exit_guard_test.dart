import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:word_app/widgets/session_exit_guard.dart';

void main() {
  group('SessionExitGuard (UX-FIX-D D-1)', () {
    testWidgets('shouldIntercept 返回 false 时不弹确认框', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SessionExitGuard(
            subject: '测试',
            shouldIntercept: () => false, // 无进度
            child: const Scaffold(body: Text('内容')),
          ),
        ),
      );

      // 触发系统返回
      final dynamic widgetsBinding = tester.binding;
      await widgetsBinding.handlePopRoute();
      await tester.pumpAndSettle();

      // 无进度时不应弹确认框
      expect(find.text('退出测试？'), findsNothing);
    });

    testWidgets('shouldIntercept 返回 true 时弹确认框', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SessionExitGuard(
            subject: '测试',
            shouldIntercept: () => true, // 有进度
            child: const Scaffold(body: Text('内容')),
          ),
        ),
      );

      // 触发系统返回
      final dynamic widgetsBinding = tester.binding;
      await widgetsBinding.handlePopRoute();
      await tester.pumpAndSettle();

      // 有进度时应弹确认框
      expect(find.text('退出测试？'), findsOneWidget);
      expect(find.text('继续学习'), findsOneWidget);
      expect(find.text('暂停并保存'), findsOneWidget);
    });

    testWidgets('shouldIntercept 为 null 时始终拦截（向后兼容）', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SessionExitGuard(
            subject: '测试',
            // shouldIntercept 为 null
            child: const Scaffold(body: Text('内容')),
          ),
        ),
      );

      // 触发系统返回
      final dynamic widgetsBinding = tester.binding;
      await widgetsBinding.handlePopRoute();
      await tester.pumpAndSettle();

      // 为 null 时应弹确认框（旧行为）
      expect(find.text('退出测试？'), findsOneWidget);
    });

    testWidgets('点击「继续学习」关闭对话框', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SessionExitGuard(
            subject: '测试',
            shouldIntercept: () => true,
            child: const Scaffold(body: Text('内容')),
          ),
        ),
      );

      // 触发系统返回
      final dynamic widgetsBinding = tester.binding;
      await widgetsBinding.handlePopRoute();
      await tester.pumpAndSettle();

      // 确认框弹出
      expect(find.text('退出测试？'), findsOneWidget);

      // 点击继续学习
      await tester.tap(find.text('继续学习'));
      await tester.pumpAndSettle();

      // 对话框关闭，页面仍在
      expect(find.text('退出测试？'), findsNothing);
      expect(find.text('内容'), findsOneWidget);
    });

    testWidgets('点击「暂停并保存」关闭对话框', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SessionExitGuard(
            subject: '测试',
            shouldIntercept: () => true,
            child: const Scaffold(body: Text('内容')),
          ),
        ),
      );

      // 触发系统返回
      final dynamic widgetsBinding = tester.binding;
      await widgetsBinding.handlePopRoute();
      await tester.pumpAndSettle();

      // 确认框弹出
      expect(find.text('退出测试？'), findsOneWidget);

      // 点击退出
      await tester.tap(find.text('暂停并保存'));
      await tester.pumpAndSettle();

      // 对话框关闭（栈底 safePop 不黑屏，页面仍在）
      expect(find.text('退出测试？'), findsNothing);
      expect(find.text('内容'), findsOneWidget);
    });
  });
}
