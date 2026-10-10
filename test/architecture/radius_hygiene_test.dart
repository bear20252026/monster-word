// 圆角卫生守卫（棘轮）——Radius.circular(数字) 只减不增。
//
// 背景：圆角字面量曾达 ~100 处（B1 只清了颜色）。v2.8.4 批量收敛为
// context.design.radius 阶梯（6 xs / 10 sm / 14 md / 16 control / 20 lg /
// 24 xl / 28 sheet / 32 xxl / 9999 pill），存量降到棘轮上限以下。
// 本测试锁定：消费处数字字面量总数 ≤ 上限；移除存量时同步下调。
// 2026-10-05 审计（Q2）：正则从 `BorderRadius\.circular(N)` 扩为
// `Radius\.circular(N)`——vertical/horizontal(…: Radius.circular(N)) 形态
// 此前完全不可见（8+ 处活体绕过）；新正则同时覆盖两种前缀。上限随可见
// 存量上调，新违规照拦（棘轮只减不增）。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 圆角字面量的允许出现位置（"圆角的家"）
const _whitelist = <String>[
  'lib/app/app.dart', // ThemeData 构建处（主题定义）
  'lib/features/learning/presentation/share_image_service.dart', // 分享位图固定像素设计
];

// 守卫扫描根（2026-10 审计 Q1）：补 lib/main.dart 与 lib/core（与 alpha/
// motion/spacing 守卫口径对齐，消灭「同库守卫各扫各的」盲区）。
const _scanRoots = <String>['lib/features', 'lib/widgets', 'lib/app', 'lib/main.dart', 'lib/core'];

/// 棘轮上限：当前存量（2026-10-05 正则扩宽后可见 11 处：
/// appearance/lib_select/review_dialog/settings_bottom_sheet/mw_modal/
/// mw_style_grid×2/redeem_swallow/global_nav_history_bar×3）。
/// 只允许下降；清理存量后请把数字改小。
const _ceiling = 11;

// 2026-10-07 审计（Q2 续）：再放宽到小数字面量——`Radius.circular(8.5)`
// 形态对整数正则不可见。表达式实参（如 `3.5 * s`）仍不在守卫射程内，
// 由 code review 把关（painter 几何缩放属合理场景）。
final _pattern = RegExp(r'Radius\.circular\(\d+(?:\.\d+)?\)');

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
