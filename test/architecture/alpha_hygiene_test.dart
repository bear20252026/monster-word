// 透明度卫生守卫（棘轮）——可映射 AppAlphas 的 withValues(alpha:) 字面量只减不增。
//
// 背景：裸 alpha 数字字面量 182 处散布 60+ 文件，无单一真相（审计 I61）。
// 2026-10-01 批次已将值命中档位的调用全部收敛为 AppAlphas token（档位即
// 现存高频值本身，不做视觉近似合并）。本测试锁定：**值命中档位却仍写
// 数字**的调用为 0；新代码请直接用 AppAlphas。
// 非档位值（如 0.13）与变量/表达式调用不在本守卫范围（后续档位扩展再收）。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _scanRoots = <String>['lib/features', 'lib/widgets', 'lib/app', 'lib/core', 'lib/main.dart'];

/// 与 lib/tokens/design_tokens.dart AppAlphas 档位同口径（含 0.1/0.10 等同值写法）。
const _tokens = <String>{
  '0',
  '0.0',
  '0.05',
  '0.06',
  '0.08',
  '0.1',
  '0.10',
  '0.12',
  '0.14',
  '0.15',
  '0.18',
  '0.2',
  '0.20',
  '0.22',
  '0.25',
  '0.3',
  '0.30',
  '0.35',
  '0.4',
  '0.40',
  '0.5',
  '0.50',
  '0.55',
  '0.6',
  '0.60',
  '0.65',
  '0.7',
  '0.70',
  '0.75',
  '0.8',
  '0.80',
  '0.85',
  '0.9',
  '0.90',
  '0.92',
  '0.96',
};

final _callRe = RegExp(r'withValues\(alpha:\s*(-?[01](?:\.\d+)?)\s*\)');

void main() {
  test('可映射 AppAlphas 的 withValues(alpha:) 字面量存量为 0（棘轮）', () {
    final hits = <String>[];
    for (final root in _scanRoots) {
      final dir = Directory(root);
      if (!dir.existsSync()) continue;
      for (final f in dir.listSync(recursive: true).whereType<File>()) {
        if (!f.path.endsWith('.dart')) continue;
        final rel = f.path.replaceAll('\\', '/');
        final src = f.readAsStringSync();
        for (final m in _callRe.allMatches(src)) {
          if (_tokens.contains(m.group(1))) {
            final line = src.substring(0, m.start).split('\n').length;
            hits.add('$rel:$line (alpha: ${m.group(1)})');
          }
        }
      }
    }
    expect(hits, isEmpty, reason: '以下调用应改用 AppAlphas token（棘轮：字面量只减不增）：\n${hits.join('\n')}');
  });

  test('AppAlphas 档位定义与守卫口径一致', () {
    final src = File('lib/tokens/design_tokens.dart').readAsStringSync();
    final classBody = src.substring(src.indexOf('class AppAlphas'));
    for (final token in _tokens) {
      // 守卫口径值 ×100 即 token 名：0.1→o10、0.05→o05、0→o0
      final n = (double.parse(token) * 100).round();
      final name = n == 0 ? 'o0' : 'o${n.toString().padLeft(2, '0')}';
      expect(classBody.contains('static const double $name'), isTrue, reason: '守卫口径值 $token 应对应 AppAlphas.$name');
    }
  });
}
