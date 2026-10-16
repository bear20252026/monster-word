// 词库规模口径守卫（棘轮）。
//
// 为什么需要这条守卫（2026-10-16 第三轮审计 R3-D09）：
//
// 同一个「词库有多大」的问题，在本仓注释里前后出现过**互相矛盾**的答案：
//   · `cn_search_index.dart` 文件头曾写「words 表 **3.2 万行**」
//   · 同文件 MW-32 段落曾写「原始词行缓冲（**3.2 万行**，几 MB）」
//   · `wordbook_database.dart` 曾写「words 表 **20 万+ 行**」
// 而真库实测是 **771,251 行**（232MB 库；词+释义文本 20MB UTF-8 ⇒ 40MB UTF-16）。
//
// 为什么这不是「注释写错而已」：这些数字正是 **R3-D03 内存预算**的依据。
// 注释低估 24× ⇒ 「这活占多少内存、低端机能不能跑」的判断整体失真，
// 而 D03 的问题恰恰就是内存。**数字错了，围绕它做的所有判断都错。**
//
// 同类还有一处：bigram 对数原写「~160 万对」，按真实算法复算是
// **4,556,073 对（含重复）/ 4,260,905（去重）**，低估 2.8× —— 而 pairs 是
// 峰值内存的主体（峰值 ≈ 1 × pairs）。
//
// ⇒ 本守卫的做法：**只要注释里出现了「规模量级断言」，就必须同时带出处旁证。**
// 「规模量级断言」= 数字紧跟 `万行` / `万条` / `万对` / `M 对` 这类量词
// （这是本仓实际的写法，见 grep 结果）。带出处的判据（满足其一即可）：
//   · 同一行/相邻行出现 `实测` 或 `R3-D09` 等审计编号
//   · 同一行出现带千位分隔的精确值（如 `771,251`、`4,260,905`）
//   · 该行是对**历史错误值**的引用（含 `曾写`/`历史上`/`原写`/`订正`/`低估`）
//
// 只扫 `lib/`。本守卫**专门检查注释文本**，所以不剥注释（与其他守卫相反）。
//
// **显式豁免**：该行带 `// scale-ok: <理由>` 则跳过。
//
// 实测复核命令（PowerShell / bash 均可，用本机 Python 直连真库）：
//   SELECT COUNT(*) FROM words;                          -- 771,251
//   SELECT SUM(LENGTH(word))+SUM(LENGTH(interpret)) FROM words;  -- 约 20MB(utf8)
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 规模量级断言：数字 + 中文量词。本仓实际写法见文件头 grep 结论。
final RegExp kScaleMagnitude = RegExp(r'\d+(\.\d+)?\s*(万行|万条|万对|万\s*行|M\s*对|万\s*对)');

/// 带出处的旁证（满足其一即可）。
final RegExp kProvenance = RegExp(r'实测|R3-D09|\d{1,3}(,\d{3})+|R3-D0\d|真库');

/// 对历史错误值的引用 —— 此类行允许出现旧数字。
final RegExp kHistorical = RegExp(r'曾写|历史上|原写|旧注释|订正|低估|先后写过|错');

bool _waived(String rawLine) => rawLine.contains('scale-ok:');

/// 取出该行 `//` 之后的注释文本；非注释行返回 null。
String? _commentText(String line) {
  for (var i = 0; i < line.length - 1; i++) {
    if (line[i] == '/' && line[i + 1] == '/') {
      if (i > 0 && line[i - 1] == ':') continue; // https://
      return line.substring(i + 2);
    }
  }
  return null;
}

/// 收集 lib/ 下所有「注释行」及其（文件, 行号, 注释文本）。
List<({String path, int line, String text})> _collectCommentLines() {
  final out = <({String path, int line, String text})>[];
  for (final entity in Directory('lib').listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    final lines = entity.readAsLinesSync();
    for (var i = 0; i < lines.length; i++) {
      if (_waived(lines[i])) continue;
      final c = _commentText(lines[i]);
      if (c == null) continue;
      out.add((path: entity.path, line: i + 1, text: c));
    }
  }
  return out;
}

void main() {
  test('lib/ 注释里的词库规模断言必须带实测出处（R3-D09）', () {
    final all = _collectCommentLines();
    final offenders = <String>[];

    for (final entry in all) {
      if (!kScaleMagnitude.hasMatch(entry.text)) continue;
      if (kProvenance.hasMatch(entry.text)) continue;
      if (kHistorical.hasMatch(entry.text)) continue;
      offenders.add('${entry.path}:${entry.line}  ${entry.text.trim()}');
    }

    expect(
      offenders,
      isEmpty,
      reason:
          '以下注释断言了词库规模但**没有实测出处**（真库实测 771,251 行 / 232MB）：\n'
          '${offenders.join('\n')}\n\n'
          '这些数字是内存预算的依据，写错会让后续判断整体失真（R3-D09）。\n'
          '请写成 `771,251` 这类精确值，或显式标注「实测」；\n'
          '引用历史错误值请用「曾写/历史上/原写」等措辞，或加 `// scale-ok: <理由>`。',
    );
  });

  test('bigram 对数不得再用「160 万对」这个低估值（R3-D09）', () {
    final all = _collectCommentLines();
    final offenders = <String>[];

    for (final entry in all) {
      if (!RegExp(r'160\s*万对|1\.6\s*M|160\s*万\s*对').hasMatch(entry.text)) continue;
      if (kHistorical.hasMatch(entry.text)) continue;
      offenders.add('${entry.path}:${entry.line}  ${entry.text.trim()}');
    }

    expect(
      offenders,
      isEmpty,
      reason:
          '以下注释仍在用「160 万对」这个**低估 2.8×** 的口径：\n'
          '${offenders.join('\n')}\n\n'
          '按真实算法复算为 4,556,073 对（含重复）/ 4,260,905（去重）（R3-D09）。',
    );
  });
}
