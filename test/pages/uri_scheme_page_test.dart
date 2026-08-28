// 测试：UriSchemePage 深链解析异常处理。
//
// 修复前（AUD-5 P2-5）：Uri.parse 失败时抛出异常，无 try-catch 保护。
// 修复后：使用 Uri.tryParse + try-catch，异常时兜底回首页。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:word_app/pages/uri_scheme_page.dart';

void main() {
  testWidgets('UriSchemePage 处理无效 URI 时不抛异常', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: UriSchemePage(uri: 'invalid-uri')),
    );

    await tester.pump(const Duration(milliseconds: 200));

    // 验证不抛异常（无效 URI 时不应崩溃）
    expect(tester.takeException(), isNull);
  });

  testWidgets('UriSchemePage 处理空 URI 时不抛异常', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: UriSchemePage(uri: '')),
    );

    await tester.pump(const Duration(milliseconds: 200));

    expect(tester.takeException(), isNull);
  });

  testWidgets('UriSchemePage 处理带 scheme 的 URI', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: UriSchemePage(uri: 'monsterword://word/test'),
      ),
    );

    await tester.pump(const Duration(milliseconds: 200));

    expect(tester.takeException(), isNull);
  });
}
