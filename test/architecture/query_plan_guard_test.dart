// 词库查询性能守卫（棘轮）。
//
// 为什么需要这条守卫（2026-10-16，全面审计 R3-D02 复核）：
//
// 词库是**只读 + 大表**（真库实测：words 771,251 行 / 232MB，word_books 605,513 行）。
// 这类表上有两种写法会把「取 N 行」变成「扫全表或整本书」，而且都**不会报错**，
// 只表现为卡顿 —— 与 SQLite 版本守卫同类，属于必须靠棘轮拦住的静默劣化。
//
// ① `ORDER BY RANDOM()` + LIMIT：SQLite 必须为每一行算一次随机数并整体排序
//    （EXPLAIN 有 `USE TEMP B-TREE FOR ORDER BY`）才能挑出前 N 行。
//    真库实测取 10 行 **110ms**、取 50 行 **126ms**（book 213 / 12083 词）。
//    改用「先取 id → Dart 侧部分 Fisher-Yates 抽样 → 按主键 IN 取行」两步式后
//    同口径 **7.6ms / 9.0ms**（14.6× / 13.9×）。
//
// ② `JOIN word_books wb ON wb.word_id = w.id`：`word_books.word_id` 在物理上是
//    **乱序**的（它是 INSERT 顺序，不是词序），于是「按 wb 顺序逐行回表 words」
//    退化成**随机 rowid 访问**。真库实测 book 213 取 10 行 **136ms**；
//    换成 `WHERE id IN (SELECT word_id FROM word_books WHERE book_id = ?)`
//    让 words 按主键顺序扫描、命中即停，同查询 **10.5ms**（13×）。
//    ⚠️ 这条与 ① 是**同一现象的两种触发方式**，注意别只修一个。
//
// 允许豁免的前提：确有一个**更窄的过滤条件**能把候选集压到很小
// （例如已经 `WHERE book_id = ?` 且该书只有几十个词），此时随机回表的代价可忽略。
// 豁免写法：行尾加 `// query-plan-ok: <理由>`，必须写明理由便于复核。
//
// 只扫 `lib/`，且先剥掉 `//` 行注释 —— 注释里提到这些写法是允许的（本文档自己就在提）。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 需要拦住的写法 → (为什么慢, 替代写法)。
const Map<String, ({String why, String instead})> kSlowPatterns = {
  'ORDER BY RANDOM': (
    why: 'SQLite 需物化全部候选行进临时 B-tree 再排序（EXPLAIN: USE TEMP B-TREE FOR ORDER BY）',
    instead: '两步式：先取 id 列表，Dart 侧部分 Fisher-Yates 抽样，再按主键 IN 取行',
  ),
  "'RANDOM()'": (
    why: '同 ORDER BY RANDOM：orderBy: \'RANDOM()\' 会整表排序',
    instead: '两步式抽样（见 word_repository_impl.getRandomWords）',
  ),
};

/// 剥掉 `//` 行注释，但保留 `://`（URL 里的双斜杠）。
String _stripLineComment(String line) {
  for (var i = 0; i < line.length - 1; i++) {
    if (line[i] == '/' && line[i + 1] == '/') {
      if (i > 0 && line[i - 1] == ':') continue; // https://
      return line.substring(0, i);
    }
  }
  return line;
}

/// 该行是否声明了显式豁免（见文件头说明）。
bool _waived(String rawLine) => rawLine.contains('query-plan-ok:');

void main() {
  test('lib/ 不用 ORDER BY RANDOM() 在大表上取样', () {
    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (_waived(lines[i])) continue;
        final code = _stripLineComment(lines[i]).toUpperCase();
        for (final pattern in kSlowPatterns.keys) {
          if (!code.contains(pattern)) continue;
          offenders.add('${entity.path}:${i + 1}  [$pattern]  ${lines[i].trim()}');
        }
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          '发现 ${offenders.length} 处大表随机取样写法（真库实测慢 13-15×）：\n'
          '${offenders.join('\n')}\n\n'
          '替代写法见 kSlowPatterns.instead；确需豁免请在该行加 "// query-plan-ok: <理由>"。',
    );
  });

  test('words JOIN word_books 的取词路径按主键顺序驱动（避免随机回表）', () {
    // JOIN word_books 后回表 words 的顺序取决于 word_books 的**物理序**（乱序），
    // 于是「逐行回表」退化为随机 rowid 访问（真库实测 book 213 取 10 行 136ms，
    // 改子查询形态后 10.5ms）。因此凡是「words ⨝ word_books 且要 ORDER BY」
    // 的取词查询，都必须用 `id IN (SELECT word_id FROM word_books …)` 形态。
    //
    // 豁免：该行/该文件声明了 `query-plan-ok:`（用于候选集本来就极小的场景）。
    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final rawLines = entity.readAsLinesSync();
      // 豁免按**原始文本**判定（不能先剥注释，否则豁免标记本身会被剥掉）
      if (rawLines.any((line) => line.contains('query-plan-ok:'))) continue;
      final source = rawLines.map(_stripLineComment).join('\n');
      final joinPattern = RegExp(r'JOIN\s+word_books\s+\w+\s+ON\s+\w+\.word_id\s*=\s*\w+\.id', caseSensitive: false);
      if (!joinPattern.hasMatch(source)) continue;
      if (!RegExp(r'ORDER\s+BY', caseSensitive: false).hasMatch(source)) continue;
      // 已改写成子查询形态的取词路径视为合规
      if (source.contains('IN (SELECT word_id FROM word_books')) continue;
      offenders.add(entity.path);
    }
    expect(
      offenders,
      isEmpty,
      reason:
          '以下文件的「words ⨝ word_books + ORDER BY」未用子查询形态，'
          '存在随机回表风险（真库实测慢 13×）：\n${offenders.join('\n')}\n\n'
          '改写为 `WHERE id IN (SELECT word_id FROM word_books WHERE book_id = ?)`；'
          '确需豁免请在该文件加 "// query-plan-ok: <理由>"。',
    );
  });
}
