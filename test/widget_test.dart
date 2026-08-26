// 应用启动冒烟测试
import 'package:flutter_test/flutter_test.dart';
import 'package:word_app/main.dart';
import 'package:word_app/core/di/service_locator.dart';

void main() {
  testWidgets('应用启动冒烟测试', (WidgetTester tester) async {
    // ✅ 测试前初始化依赖注入容器
    setupServiceLocator();

    // 验证 WordApp 能构建（数据库初始化在 main 中，测试不触发）
    await tester.pumpWidget(const WordApp());
    expect(find.byType(WordApp), findsOneWidget);

    // ✅ 测试后清理
    disposeServiceLocator();
  });
}
