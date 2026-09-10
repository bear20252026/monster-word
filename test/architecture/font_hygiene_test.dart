// 排版卫生守卫（棘轮）——fontSize 数字字面量只减不增。
//
// 背景：B1 清了颜色、B2 清了时长，但 fontSize 字面量曾达 ~150 处，
// 排版阶漂移（同一层级页面各写各的字号）。v2.8.4 批量收敛为
// MwTypography token（含补齐 titleLg/displaySm/stat 三档），存量从 150+ 降到
// 棘轮上限以下。本测试锁定：
// - 消费处 fontSize 数字字面量总数 ≤ 上限（只减不增）；
// - 移除存量时必须同步下调上限（防止回弹）；
// - 新代码一律用 MwTypography.xxx（尺寸/字重/行高一体的排版阶）。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 字号字面量的允许出现位置（"字号的家"）
const _whitelist = <String>[
  'lib/app/app.dart', // ThemeData 构建处（主题定义）
  'lib/features/learning/presentation/share_image_service.dart', // 分享位图固定像素设计
];

const _scanRoots = <String>['lib/features', 'lib/widgets', 'lib/app'];

/// 棘轮上限：当前存量。只允许下降；清理存量后请把数字改小。
const _ceiling = 64;

final _pattern = RegExp(r'fontSize:\s*\d+\s*[,)]');

void main() {
  test('fontSize 数字字面量存量只减不增（当前上限 $_ceiling）', () {
    final hits = <String>[];
    for (final root in _scanRoots) {
      final dir = Directory(root);
      if (!dir.existsSync()) continue;
      for (final f in dir.listSync(recursive: true).whereType<File>()) {
        if (!f.path.endsWith('.dart')) continue;
        final rel = f.path.replaceAll('\\', '/');
        if (_whitelist.contains(rel)) continue;
        final lines = f.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          if (_pattern.hasMatch(lines[i])) hits.add('$rel:${i + 1}');
        }
      }
    }
    expect(
      hits.length,
      lessThanOrEqualTo(_ceiling),
      reason:
          'fontSize 字面量存量 ${hits.length} 超过棘轮上限 $_ceiling。\n'
          '新代码请用 MwTypography token（12 micro / 13 caption / 14 bodySm / 16 bodyMd·bodyBold / '
          '18 heading5 / 20 titleLg / 22 heading4 / 24 displaySm / 28 heading3 / 32 stat…）；\n'
          '若你刚清理了存量，请同步把 _ceiling 下调到新的实际值。\n'
          '残留明细（前 20 条）：\n${hits.take(20).join('\n')}',
    );
  });
}
