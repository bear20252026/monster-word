// P3-8（架构审计 2026-11-12）：交接文档计数守卫（棘轮）。
//
// 为什么需要这条守卫：HANDOVER.md 的规模/守卫计数长期漂移——审计实测时它仍写
// 「13 套守卫 / 904 例 / lib 370 文件」，而真值是 26 套 / 1589 例 / 471 文件。
// 这些数字是接手人判断「项目多大、守卫多密」的第一依据，写错会误导排期与风险评估。
//
// 做法：把文档里**可机器复核的计数**与实测对齐校验。只校验「结构性计数」
// （守卫文件套数、features 域数、lib/test 文件数）——它们可由文件系统直接数出；
// 测试例数随每次增删波动，不在此硬校验（避免每加一个测试就要改文档的噪音），
// 改由发版前人工复核。文档若调整措辞，请同步更新这里的正则与期望值。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final handover = File('docs/HANDOVER.md');

  test('HANDOVER 守卫套数与 test/architecture 实测一致', () {
    final guardFiles = Directory('test/architecture')
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('_test.dart'))
        .length;
    final src = handover.readAsStringSync();
    final m = RegExp(r'(\d+)\s*套守卫测试').firstMatch(src);
    expect(m, isNotNull, reason: 'HANDOVER 应写明「N 套守卫测试」');
    expect(
      int.parse(m!.group(1)!),
      guardFiles,
      reason: 'HANDOVER 守卫套数漂移：实测 test/architecture 有 $guardFiles 个 *_test.dart',
    );
  });

  test('HANDOVER features 域数与 lib/features 实测一致', () {
    final featDirs = Directory('lib/features').listSync().whereType<Directory>().length;
    final src = handover.readAsStringSync();
    final m = RegExp(r'features\s*(\d+)\s*域').firstMatch(src);
    expect(m, isNotNull, reason: 'HANDOVER 应写明「features N 域」');
    expect(int.parse(m!.group(1)!), featDirs, reason: 'HANDOVER features 域数漂移：实测 $featDirs 个');
  });

  test('HANDOVER lib 文件数与实测一致', () {
    final libFiles = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .length;
    final src = handover.readAsStringSync();
    final m = RegExp(r'lib\s*(\d+)\s*文件').firstMatch(src);
    expect(m, isNotNull, reason: 'HANDOVER 应写明「lib N 文件」');
    expect(int.parse(m!.group(1)!), libFiles, reason: 'HANDOVER lib 文件数漂移：实测 $libFiles 个');
  });

  test('HANDOVER test 文件数与实测一致', () {
    final testFiles = Directory('test')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .length;
    final src = handover.readAsStringSync();
    final m = RegExp(r'test\s*(\d+)\s*文件').firstMatch(src);
    expect(m, isNotNull, reason: 'HANDOVER 应写明「test N 文件」');
    expect(int.parse(m!.group(1)!), testFiles, reason: 'HANDOVER test 文件数漂移：实测 $testFiles 个');
  });
}
