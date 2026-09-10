// Emoji 红线守卫——禁止 emoji 充当 UI 图标/文案装饰。
//
// 设计语言明确：图形语义一律用矢量图标（Icons.*）或 MonsterIcon/MonsterAvatar
// 品牌形象；emoji 在 Windows 桌面与 Android 手机渲染不一致（双端不一致的
// 字形回退），且破坏星巴克奶油画布的艺术统一。
// v2.8.4 已清零全站 emoji 图标（🚩🧸📡✅⭐❤️♡🎬）与 ✓/✗ 判色 hack。
//
// 本测试锁定：lib/ 非注释行不得出现 emoji 表意区块字符。
// 允许：箭头 U+2190–U+21FF（正文排版符号，如「课程页 → 沉浸背单词」）、
// 数学符号、普通标点。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _scanRoots = <String>['lib'];

/// emoji 表意区块（多平面 pictograph + 杂项符号 + 装饰符号 + 变体选择符）
final _banned = RegExp(
  '[\u{1F000}-\u{1FAFF}]|[\u{2600}-\u{27BF}]|[\u{2B00}-\u{2BFF}]|[\u{FE00}-\u{FE0F}]|[\u{1F1E6}-\u{1F1FF}]',
  unicode: true,
);

void main() {
  test('lib 非注释行零 emoji 表意字符（UI 图标一律用矢量/品牌形象）', () {
    final violations = <String>[];
    for (final root in _scanRoots) {
      final dir = Directory(root);
      if (!dir.existsSync()) continue;
      for (final f in dir.listSync(recursive: true).whereType<File>()) {
        if (!f.path.endsWith('.dart')) continue;
        final rel = f.path.replaceAll('\\', '/');
        final lines = f.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final stripped = lines[i].trim();
          if (stripped.startsWith('//') || stripped.startsWith('*') || stripped.startsWith('/*')) continue;
          final m = _banned.firstMatch(lines[i]);
          if (m != null) {
            violations.add('$rel:${i + 1}: ${stripped.length > 90 ? stripped.substring(0, 90) : stripped}');
          }
        }
      }
    }
    expect(
      violations,
      isEmpty,
      reason:
          '发现 emoji 表意字符——UI 图标请用 Icons.* / MonsterIcon / MonsterAvatar，'
          '正文装饰请用排版符号（→ · 等）：\n${violations.take(20).join('\n')}',
    );
  });
}
