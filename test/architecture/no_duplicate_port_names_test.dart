// 由 Claude 团队生成 | Monster Word App

// 跨 feature application 端口重名守卫（审计跟进批次 B / REG-ARCH-004）。
// 背景：learning 与 book 各有一个同名 BookWordsReader，行为不同（截断 vs 全量），
// 接错线编译期不报错。book 侧已更名 BookWordListReader 消歧，本测试锁定：
// 任何 feature 的 application 层不得声明与其它 feature 同名的抽象端口。

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('application 层抽象端口名不得跨 feature 重复（REG-ARCH-004）', () {
    final declared = <String, String>{}; // 类名 -> 首个声明的 feature
    final violations = <String>[];

    final featuresDir = Directory('lib/features');
    expect(featuresDir.existsSync(), isTrue, reason: 'lib/features 不存在（请在仓库根目录运行）');

    for (final feature in featuresDir.listSync().whereType<Directory>()) {
      final appName = feature.uri.pathSegments.where((s) => s.isNotEmpty).last;
      final appDir = Directory('${feature.path}/application');
      if (!appDir.existsSync()) continue;
      for (final file in appDir.listSync().whereType<File>()) {
        if (!file.path.endsWith('.dart')) continue;
        final src = file.readAsStringSync();
        final pattern = RegExp(r'abstract\s+(?:interface\s+)?class\s+(\w+)');
        for (final match in pattern.allMatches(src)) {
          final name = match.group(1)!;
          if (declared.containsKey(name) && declared[name] != appName) {
            violations.add('$name 同时由 ${declared[name]} 与 $appName 声明（接错线编译期不报错）');
          } else {
            declared.putIfAbsent(name, () => appName);
          }
        }
      }
    }

    expect(violations, isEmpty, reason: '跨 feature 端口重名：${violations.join('；')}');
  });
}
