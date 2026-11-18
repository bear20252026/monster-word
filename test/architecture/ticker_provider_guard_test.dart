// 质量门禁：约束「SingleTickerProviderStateMixin 只允许一个 AnimationController」。
//
// 根因：SingleTickerProviderStateMixin 为实现 createTicker 只能被调用一次，
// 一旦某个 State 用它却创建了多个 AnimationController，Flutter 会在 build 时
// 抛 "multiple tickers were created" 而崩溃。CheckInHistoryPage 即为此类事故。
//
// 本测试扫描 lib/** 全部 Dart 文件，统计每个「带 SingleTickerProviderStateMixin
// 的 class」体内的 AnimationController( 数量，>1 即判为违规并列出，作为 CI 门禁。
//
// 第四轮 M12（2026-11-18）：括号配对与计数前先剥字符串/注释（maskDartSource）。
// 此前逐字符裸数 {/}，字符串字面量或注释里的花括号会错算类体边界（截短漏检、
// 或串入相邻类），注释/字符串里的 AnimationController( 也会被误计。掩码保留
// 换行与字符长度，行号/列号口径不变。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

class _ClassBody {
  final String className;
  final String body;
  const _ClassBody(this.className, this.body);
}

// ── 源码掩码器（M12）─────────────────────────────────────────────
// 把注释与字符串字面量的内容掩为空格，保留换行与总长度，使大括号配对与
// 符号计数只作用于真实代码。覆盖 Dart 的：
//   · // 行注释、/* */ 块注释（Dart 支持嵌套）
//   · 单/双引号、三引号字符串、raw 字符串（r'...' / r"..."）
//   · 反斜杠转义、字符串插值 ${...}（插值内按代码处理，可再嵌套字符串/注释/花括号）
// 不处理：$identifier 无花括号插值（不含花括号，无需特殊处理）。

enum _Kind { code, lineComment, blockComment, string }

class _Frame {
  _Frame(
    this.kind, {
    this.blockDepth = 0,
    this.quote = '',
    this.triple = false,
    this.raw = false,
    this.interpDepth = -1,
  });
  final _Kind kind;
  int blockDepth;

  /// string 帧：引号字符 / 是否三引号 / 是否 raw。
  final String quote;
  final bool triple;
  final bool raw;

  /// code 帧：>=0 表示处于字符串插值内（记录花括号深度）；-1 表示顶层代码。
  int interpDepth;
}

bool _isIdentChar(String c) {
  if (c.isEmpty) return false;
  final u = c.codeUnitAt(0);
  return (u >= 0x30 && u <= 0x39) || (u >= 0x41 && u <= 0x5A) || (u >= 0x61 && u <= 0x7A) || c == '_' || c == r'$';
}

/// 掩码后的源码（与原文等长、换行位置一致）。
String maskDartSource(String src) {
  final out = List<String>.filled(src.length, ' ');
  final stack = <_Frame>[_Frame(_Kind.code)];
  var i = 0;
  String at(int k) => k >= 0 && k < src.length ? src[k] : '';

  void keep(int k) {
    if (k >= 0 && k < src.length) out[k] = src[k];
  }

  while (i < src.length) {
    final top = stack.last;
    final ch = src[i];
    final next = at(i + 1);

    switch (top.kind) {
      case _Kind.code:
        if (ch == '/' && next == '/') {
          stack.add(_Frame(_Kind.lineComment));
          i += 2;
        } else if (ch == '/' && next == '*') {
          stack.add(_Frame(_Kind.blockComment, blockDepth: 1));
          i += 2;
        } else if (ch == "'" || ch == '"') {
          // raw 前缀：紧邻的 r 且其前不是标识符字符。
          final raw = at(i - 1) == 'r' && !_isIdentChar(at(i - 2));
          if (raw) out[i - 1] = ' ';
          final triple = next == ch && at(i + 2) == ch;
          final qLen = triple ? 3 : 1;
          stack.add(_Frame(_Kind.string, quote: ch, triple: triple, raw: raw));
          i += qLen;
        } else if (top.interpDepth >= 0 && ch == '{') {
          top.interpDepth++;
          keep(i);
          i++;
        } else if (top.interpDepth >= 0 && ch == '}') {
          if (top.interpDepth == 0) {
            stack.removeLast(); // 插值结束，回到字符串帧
          } else {
            top.interpDepth--;
            keep(i);
          }
          i++;
        } else {
          keep(i);
          i++;
        }
      case _Kind.lineComment:
        if (ch == '\n') {
          stack.removeLast();
          keep(i);
        }
        i++;
      case _Kind.blockComment:
        if (ch == '/' && next == '*') {
          top.blockDepth++;
          i += 2;
        } else if (ch == '*' && next == '/') {
          top.blockDepth--;
          i += 2;
          if (top.blockDepth == 0) stack.removeLast();
        } else {
          if (ch == '\n') keep(i);
          i++;
        }
      case _Kind.string:
        if (ch == '\n') {
          keep(i); // 保留换行以维持行结构（三引号可跨行）
          i++;
        } else if (!top.raw && ch == r'\') {
          i += 2; // 转义：掩掉反斜杠与后一字符
        } else if (!top.raw && ch == r'$' && next == '{') {
          stack.add(_Frame(_Kind.code, interpDepth: 0));
          i += 2;
        } else if (ch == top.quote && (!top.triple || (next == ch && at(i + 2) == ch))) {
          i += top.triple ? 3 : 1;
          stack.removeLast();
        } else {
          i++;
        }
    }
  }
  return out.join();
}

/// 找出 src 中所有「声明里含 SingleTickerProviderStateMixin 的 class」及其方法体。
/// 传入的 src 应已掩码（maskDartSource），以免字符串/注释干扰配对与计数。
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
      final src = maskDartSource(File(f).readAsStringSync());
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

  // ── 掩码器自测（M12）：确保剥字符串/注释后配对与计数正确 ──────────────
  group('maskDartSource 自测', () {
    test('行注释里的花括号与 AnimationController 被掩掉', () {
      const src = "class A {\n  // } AnimationController(\n  var x = 1;\n}\n";
      final masked = maskDartSource(src);
      expect(masked.contains('AnimationController'), isFalse);
      // 类体应完整到最后的 }，不被注释里的 } 截短
      final bodies = _findMixinClassBodies(
        masked.replaceAll('class A', 'class A extends State with SingleTickerProviderStateMixin'),
      );
      expect(bodies.single.body.contains('var x = 1;'), isTrue);
    });

    test('字符串里的花括号不影响类体边界', () {
      const src =
          "class A extends State with SingleTickerProviderStateMixin {\n"
          "  final s = '} { }';\n"
          "  late final c = AnimationController(vsync: this);\n"
          "}\n";
      final bodies = _findMixinClassBodies(maskDartSource(src));
      expect(bodies.single.body.contains('AnimationController'), isTrue);
      expect(RegExp(r'AnimationController\s*\(').allMatches(bodies.single.body).length, 1);
    });

    test('字符串/注释里的 AnimationController 不被计数', () {
      const src =
          "class A extends State with SingleTickerProviderStateMixin {\n"
          "  // AnimationController(\n"
          "  final s = 'AnimationController(';\n"
          "  late final c = AnimationController(vsync: this);\n"
          "}\n";
      final bodies = _findMixinClassBodies(maskDartSource(src));
      expect(RegExp(r'AnimationController\s*\(').allMatches(bodies.single.body).length, 1);
    });

    test('嵌套块注释被完整掩掉', () {
      const src = '/* outer /* inner } */ still comment } */ var keep = 1;';
      final masked = maskDartSource(src);
      expect(masked.contains('var keep = 1;'), isTrue);
      expect(masked.contains('}'), isFalse);
    });

    test('三引号字符串跨行掩码且保留换行', () {
      const src = "var s = '''\n} {\nAnimationController(\n''';\nvar after = 2;";
      final masked = maskDartSource(src);
      expect(masked.split('\n').length, src.split('\n').length);
      expect(masked.contains('AnimationController'), isFalse);
      expect(masked.contains('var after = 2;'), isTrue);
    });

    test('raw 字符串不处理插值（ dollar-brace 按字面量掩掉，花括号不泄漏）', () {
      // 合法 Dart raw 串：r'...${x}...' 中 ${x} 是字面量（raw 不插值）。
      // 注意 raw 串里反斜杠不转义引号，故夹具不用 \' 这类非法写法。
      const src =
          r"var s = r'a${x}b}c';"
          ' var after = 3;';
      final masked = maskDartSource(src);
      expect(masked.contains('var after = 3;'), isTrue);
      // raw 串内的 } 与 ${ 不应泄漏为代码花括号/插值
      expect(masked.replaceAll('var after = 3;', '').contains('}'), isFalse);
      expect(masked.contains(r'${'), isFalse);
    });

    test('字符串插值内的花括号按代码配对、嵌套字符串正确处理', () {
      const src =
          "class A extends State with SingleTickerProviderStateMixin {\n"
          r"  final s = '${foo('}')}' ;"
          "\n  late final c = AnimationController(vsync: this);\n}\n";
      final bodies = _findMixinClassBodies(maskDartSource(src));
      expect(bodies.single.body.contains('AnimationController'), isTrue);
    });

    test('转义引号不提前结束字符串', () {
      const src =
          r"var s = 'a\'}b';"
          ' var after = 4;';
      final masked = maskDartSource(src);
      expect(masked.contains('var after = 4;'), isTrue);
      expect(masked.replaceAll('var after = 4;', '').contains('}'), isFalse);
    });

    test('注释掉的类声明不被误识别', () {
      const src = '// class Fake extends State with SingleTickerProviderStateMixin {}\nvar real = 1;';
      final bodies = _findMixinClassBodies(maskDartSource(src));
      expect(bodies, isEmpty);
    });
  });
}

List<String> _dartFiles(String dir) {
  final result = <String>[];
  for (final e in Directory(dir).listSync(recursive: true)) {
    if (e is File && e.path.endsWith('.dart')) result.add(e.path);
  }
  return result;
}
