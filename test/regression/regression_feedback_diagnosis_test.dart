// 由 Claude 团队生成 | Monster Word App

// REG-FDB-001：反馈页提交真实落盘（本地存档），不再只做假延迟。
// REG-FDB-002：空内容提交被拦截。
// REG-NET-001：网络诊断真实反映失败步骤（mock 失败步骤时页面显示失败项，
//              旧版硬编码「全部成功」属误导性假语义）。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:word_app/features/account/application/feedback_archive.dart';
import 'package:word_app/features/account/presentation/feedback_page.dart';
import 'package:word_app/features/settings/application/network_diagnosis_service.dart';
import 'package:word_app/features/settings/domain/diagnosis_result.dart';
import 'package:word_app/features/settings/presentation/net_diagnosis_page.dart';

class _FakeDiagnosisService implements NetworkDiagnosisService {
  _FakeDiagnosisService(this.steps);
  final List<DiagnosisResult> steps;

  @override
  Future<List<DiagnosisResult>> runDiagnosis({void Function(DiagnosisResult step)? onStep}) async {
    for (final r in steps) {
      onStep?.call(r);
    }
    return steps;
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('REG-FDB-001: 填写内容提交后显示感谢页，且反馈本地存档', (WidgetTester tester) async {
    final prefs = await SharedPreferences.getInstance();
    final uploads = <FeedbackEntry>[];
    final archive = FeedbackArchive(prefsOverride: prefs, upload: (entry) async => uploads.add(entry));

    await tester.pumpWidget(MaterialApp(home: FeedbackPage(archiveOverride: archive)));

    await tester.enterText(find.byType(TextField).first, '希望能支持暗黑模式跟手切换');
    await tester.enterText(find.byType(TextField).at(1), 'user@example.com');
    await tester.tap(find.text('提交反馈'));
    await tester.pumpAndSettle();

    expect(find.text('感谢你的反馈！'), findsOneWidget);
    final history = await archive.history();
    expect(history, hasLength(1));
    expect(history.first.content, '希望能支持暗黑模式跟手切换');
    expect(uploads, hasLength(1));
  });

  testWidgets('REG-FDB-002: 空内容提交被拦截并提示', (WidgetTester tester) async {
    final prefs = await SharedPreferences.getInstance();
    final archive = FeedbackArchive(prefsOverride: prefs, upload: (entry) async {});

    await tester.pumpWidget(MaterialApp(home: FeedbackPage(archiveOverride: archive)));

    await tester.tap(find.text('提交反馈'));
    await tester.pump();

    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text('感谢你的反馈！'), findsNothing);
    expect(await archive.history(), isEmpty);
  });

  testWidgets('REG-NET-001: 诊断失败步骤真实上屏（失败图标与文案）', (WidgetTester tester) async {
    final service = _FakeDiagnosisService([
      const DiagnosisResult(name: '网络连接', success: true, detail: '解析成功：1.2.3.4 (12ms)'),
      const DiagnosisResult(name: '短信服务可达', success: false, detail: '失败：SocketException (6000ms)'),
    ]);

    await tester.pumpWidget(MaterialApp(home: NetDiagnosisPage(serviceOverride: service)));
    await tester.tap(find.text('开始诊断'));
    await tester.pumpAndSettle();

    expect(find.text('网络连接'), findsOneWidget);
    expect(find.text('解析成功：1.2.3.4 (12ms)'), findsOneWidget);
    expect(find.text('短信服务可达'), findsOneWidget);
    expect(find.text('失败：SocketException (6000ms)'), findsOneWidget);
    // 成功 1 个 check_circle + 失败 1 个 error：结果真实反映，不再恒成功。
    expect(find.byIcon(Icons.error), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
  });
}
