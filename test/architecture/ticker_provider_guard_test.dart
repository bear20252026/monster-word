// 质量门禁：约束「SingleTickerProviderStateMixin 只允许一个 AnimationController」。
//
// 根因：SingleTickerProviderStateMixin 为实现 createTicker 只能被调用一次，
// 一旦某个 State 用它却创建了多个 AnimationController，Flutter 会在 build 时
// 抛 "multiple tickers were created" 而崩溃。CheckInHistoryPage 即为此类事故。
//
// 本测试扫描 lib/** 全部 Dart 文件，统计每个「带 SingleTickerProviderStateMixin
// 的 class」体内的 AnimationController( 数量，>1 即判为违规并列出，作为 CI 门禁。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

class _ClassBody {
  final String className;
  final String body;
  const _ClassBody(this.className, this.body);
}

/// 找出 src 中所有「声明里含 SingleTickerProviderStateMixin 的 class」及其方法体。
List<_ClassBody> _findMixinClassBodies(String src) {
  final out = <_ClassBody>[];
  final lines = src.split('\n');
  final declRe = RegExp(r'^(class|mixin)\s+(\w+)\s+.*SingleTickerProviderStateMixin');
  for (var i = 0; i < lines.length; i++) {
    final m = declRe.firstMatch(lines[i]);
    if (m == null) continue;
    final className = m.group(2)!;
    // 定位类体起始大括号
    var braceLine = i;
    var braceCol = lines[i].indexOf('{');
    if (braceCol == -1) {
      for (var j = i; j < lines.length; j++) {
        final idx = lines[j].indexOf('{');
        if (idx != -1) {
          braceLine = j;
          braceCol = idx;
          break;
        }
      }
    }
    if (braceCol == -1) continue;
    // 大括号配对，取类体文本
    final sb = StringBuffer();
    var depth = 0;
    var started = false;
    for (var j = braceLine; j < lines.length; j++) {
      final line = lines[j];
      for (var k = 0; k < line.length; k++) {
        final ch = line[k];
        if (ch == '{') {
          depth++;
          started = true;
        } else if (ch == '}') {
          depth--;
        }
        if (started) sb.write(ch);
        if (started && depth == 0) break;
      }
      if (started && depth == 0) break;
    }
    out.add(_ClassBody(className, sb.toString()));
  }
  return out;
}

void main() {
  test('lib 中不得出现「SingleTickerProviderStateMixin + 多个 AnimationController」', () {
    final root = p.normalize(p.join(Directory.current.path, 'lib'));
    final violations = <String>[];
    for (final f in _dartFiles(root)) {
      final src = File(f).readAsStringSync();
      for (final b in _findMixinClassBodies(src)) {
        final count = RegExp(r'AnimationController\s*\(').allMatches(b.body).length;
        if (count > 1) {
          violations.add(
            '${p.relative(f, from: root)} :: ${b.className} 创建了 $count 个 AnimationController'
            '（改用 TickerProviderStateMixin）',
          );
        }
      }
    }
    if (violations.isNotEmpty) {
      fail(
        '发现 ${violations.length} 处多动画控制器反模式（会导致启动崩溃）：\n'
        '${violations.join('\n')}',
      );
    }
  });
}

List<String> _dartFiles(String dir) {
  final result = <String>[];
  for (final e in Directory(dir).listSync(recursive: true)) {
    if (e is File && e.path.endsWith('.dart')) result.add(e.path);
  }
  return result;
}
