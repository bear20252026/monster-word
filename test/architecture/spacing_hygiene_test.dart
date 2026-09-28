// 间距卫生守卫（棘轮）——可映射 AppSpacing 的 EdgeInsets 字面量只减不增。
//
// 背景：裸 EdgeInsets 数字字面量曾达 419 行 / 406 调用，AppSpacing 仅 3 处使用
// （审计 I59）。2026-09-28 批次1 已将 212 处值命中阶梯（4 xxs / 8 xs / 12 sm /
// 16 md / 20 lg / 24 xl / 32 xxl / 64 section）的调用收敛为 token。
// 本测试锁定：**值可映射却仍写数字**的调用为 0；新代码请直接用 AppSpacing。
// 非阶梯值（10/14/6…）与变量/表达式调用不在本守卫范围（后续阶梯扩展再收）。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _scanRoots = <String>['lib/features', 'lib/widgets', 'lib/app', 'lib/core', 'lib/main.dart'];

const _tokens = <String>{'4', '8', '12', '16', '20', '24', '32', '64'};

final _callRe = RegExp(r'EdgeInsets\.(all|symmetric|only|fromLTRB)\s*\(');
final _argRe = RegExp(r'^\s*(\w+:\s*)?(-?\d+)(\.0)?\s*$');

/// 与 scripts 批次脚本同口径：判断该调用的参数是否全部可映射 token
bool _mappable(String argSrc) {
  for (final part in argSrc.split(',')) {
    final m = _argRe.firstMatch(part);
    if (m == null) return false;
    if (!_tokens.contains(m.group(2))) return false;
  }
  return true;
}

/// 找到与 openIdx 配对的右括号（处理嵌套）
int _findClose(String src, int openIdx) {
  var depth = 0;
  for (var i = openIdx; i < src.length; i++) {
    if (src[i] == '(') depth++;
    if (src[i] == ')') {
      depth--;
      if (depth == 0) return i;
    }
  }
  return -1;
}

void main() {
  test('可映射 AppSpacing 的 EdgeInsets 字面量存量为 0（棘轮）', () {
    final hits = <String>[];
    for (final root in _scanRoots) {
      final dir = Directory(root);
      if (!dir.existsSync()) continue;
      for (final f in dir.listSync(recursive: true).whereType<File>()) {
        if (!f.path.endsWith('.dart')) continue;
        final rel = f.path.replaceAll('\\', '/');
        final src = f.readAsStringSync();
        for (final m in _callRe.allMatches(src)) {
          final close = _findClose(src, m.end - 1);
          if (close < 0) continue;
          if (_mappable(src.substring(m.end, close))) {
            final line = src.substring(0, m.start).split('\n').length;
            hits.add('$rel:$line');
          }
        }
      }
    }
    expect(
      hits,
      isEmpty,
      reason:
          '可映射 AppSpacing 的 EdgeInsets 字面量出现 ${hits.length} 处。\n'
          '新代码请直接使用 AppSpacing 阶梯：4 xxs / 8 xs / 12 sm / 16 md / '
          '20 lg / 24 xl / 32 xxl / 64 section。\n'
          '残留明细（前 20 条）：\n${hits.take(20).join('\n')}',
    );
  });
}
