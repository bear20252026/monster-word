// N1：门面直建守卫——除装配边界与门面自身外，禁止 PresentationPrefs()/TodayProgressStore() 构造。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _allowed = <String>[
  'lib/core/application/presentation_prefs.dart',
  'lib/core/application/today_progress_store.dart',
  'lib/features/learning/presentation/learning_feature_providers.dart',
  'lib/features/dictionary/presentation/dictionary_feature_providers.dart',
];

void main() {
  test('非装配文件禁止直建 PresentationPrefs()/TodayProgressStore()（N1/M1）', () {
    final violations = <String>[];
    final pattern = RegExp(r'PresentationPrefs\(\)|TodayProgressStore\(\)');
    for (final dirName in ['lib/features', 'lib/widgets', 'lib/app']) {
      final dir = Directory(dirName);
      if (!dir.existsSync()) continue;
      for (final f in dir.listSync(recursive: true).whereType<File>()) {
        if (!f.path.endsWith('.dart')) continue;
        final rel = f.path.replaceAll(r'\', '/');
        if (_allowed.contains(rel)) continue;
        final src = f.readAsStringSync();
        for (final m in pattern.allMatches(src)) {
          // 允许构造函数参数默认值字段声明处仍算违规——需注入
          final line = src.substring(0, m.start).split('\n').length;
          violations.add('$rel:$line ${m.group(0)}');
        }
      }
    }
    expect(violations, isEmpty, reason: '门面必须经 Provider 注入或仅在 providers/门面文件内构造：\n${violations.join('\n')}');
  });
}
