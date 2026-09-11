// 圆角卫生守卫（棘轮）——BorderRadius.circular(数字) 只减不增。
//
// 背景：圆角字面量曾达 ~100 处（B1 只清了颜色）。v2.8.4 批量收敛为
// context.design.radius 阶梯（6 xs / 10 sm / 14 md / 16 control / 20 lg /
// 24 xl / 28 sheet / 32 xxl / 9999 pill），存量降到棘轮上限以下。
// 本测试锁定：消费处数字字面量总数 ≤ 上限；移除存量时同步下调。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 圆角字面量的允许出现位置（"圆角的家"）
const _whitelist = <String>[
  'lib/app/app.dart', // ThemeData 构建处（主题定义）
  'lib/features/learning/presentation/share_image_service.dart', // 分享位图固定像素设计
];

const _scanRoots = <String>['lib/features', 'lib/widgets', 'lib/app'];

/// 棘轮上限：当前存量。只允许下降；清理存量后请把数字改小。
const _ceiling = 3;

final _pattern = RegExp(r'BorderRadius\.circular\(\d+\)');

void main() {
  test('BorderRadius.circular 数字字面量存量只减不增（当前上限 $_ceiling）', () {
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
          '圆角字面量存量 ${hits.length} 超过棘轮上限 $_ceiling。\n'
          '新代码请用 context.design.radius（或 skin.design.radius）阶梯：'
          '6 xs / 10 sm / 14 md / 16 control / 20 lg / 24 xl / 28 sheet / 32 xxl / pill；\n'
          '若你刚清理了存量，请同步把 _ceiling 下调到新的实际值。\n'
          '残留明细（前 20 条）：\n${hits.take(20).join('\n')}',
    );
  });
}
