// R4：presentation 路由单源——routeName 必须引用 RouteNames.*，禁止字面量或本地常量双源。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('presentation 页面 routeName 必须使用 RouteNames.*（R4）', () {
    final violations = <String>[];
    final dir = Directory('lib/features');
    for (final f in dir.listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      final rel = f.path.replaceAll(r'\', '/');
      if (!rel.contains('/presentation/')) continue;
      if (rel.endsWith('_feature_providers.dart')) continue;
      final src = f.readAsStringSync();
      final pattern = RegExp(r'static const \w*\s*routeName\s*=\s*([^;]+);');
      for (final m in pattern.allMatches(src)) {
        final rhs = m.group(1)!.trim();
        if (!rhs.startsWith('RouteNames.')) {
          violations.add('$rel → routeName = $rhs');
        }
      }
    }
    expect(violations, isEmpty, reason: '路由名必须引用 RouteNames：\n${violations.join('\n')}');
  });
}
