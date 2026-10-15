// SQLite 版本兼容守卫（棘轮）。
//
// 为什么需要这条守卫（2026-10-15 第三轮审计 R3-E01 / R3-D01）：
// `minSdk` 是 `flutter.minSdkVersion` = **24**（`FlutterExtension.kt:26` 实证），
// 而 Android 系统自带的 SQLite 版本随 API 走：
//
//   API 24 → 3.9.2   API 26 → 3.18   API 27 → 3.19   API 28 → 3.22
//   API 29 → 3.28    API 31+ → 3.32+
//
// ⇒ **API ≤ 28（Android 7/8/9）的系统库低于 3.24**。而这些设备上的失败几乎都被
// 「只上报不抛」的容错层吞掉，表现为**静默失效**而不是崩溃 —— 最坏的一种。
//
// 台账 `REG-AUDIT-002` 已经在 `review_schedule_store` 踩过一次
// （`INSERT … ON CONFLICT … DO UPDATE` 需 3.24，改成「UPDATE 命中 0 行再 INSERT」），
// 但**当时只修了实例、没立守卫**，于是 2026-10-15 审计又在两处新代码里发现复发：
//   - `usage_stats_dao.writeDay` 的 UPSERT（埋点在这些设备上 100% 静默不落盘）
//   - `user_data_backup_service` 的 `VACUUM INTO`（备份从未产生，恢复网失效）
// 这条守卫就是为了不再有第三次。
//
// 允许出现的前提只有一个：**把 minSdk 提到 29+**（那时本守卫可以直接删掉）。
// 在那之前，需要「插入或更新」就写两步（UPDATE 命中 0 行再 INSERT），
// 需要「一致性快照」就探版本降级（见 `user_data_backup_service._snapshot`）。
//
// 只扫 `lib/`，且会先剥掉 `//` 行注释 —— 注释里提到这些语法是允许的（本文档自己就在提）。
//
// **显式豁免**：某一行若带 `// sqlite-compat-ok: <理由>` 就跳过。用于「已经自己探过版本、
// 只在支持时才走这条路」的场景（例如 `user_data_backup_service` 里那句 `VACUUM INTO ?`
// 前面有 `_supportsVacuumInto(db)` 判断）。豁免必须写明理由，便于复核。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 需要高版本 SQLite 的语法 → (最低版本, 最低 API, 替代写法)。
const Map<String, ({String minVersion, int minApi, String instead})> kForbiddenSyntax = {
  'DO UPDATE': (
    minVersion: '3.24',
    minApi: 29,
    instead: '「UPDATE 命中 0 行再 INSERT」两步（见 review_schedule_store._upsertDailyStats）',
  ),
  'VACUUM INTO': (
    minVersion: '3.27',
    minApi: 29,
    instead: '探 sqlite_version() 后降级为 checkpoint + 复制（见 user_data_backup_service._snapshot）',
  ),
  'RETURNING': (minVersion: '3.35', minApi: 33, instead: '插入后另发一条 SELECT 取回'),
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
bool _waived(String rawLine) => rawLine.contains('sqlite-compat-ok:');

void main() {
  test('lib/ 不使用需要高版本 SQLite 的语法（minSdk 24 覆盖 Android ≤9）', () {
    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (_waived(lines[i])) continue;
        final code = _stripLineComment(lines[i]);
        for (final entry in kForbiddenSyntax.entries) {
          final pattern = entry.key;
          final needsWordBoundary = pattern == 'RETURNING';
          final hit = needsWordBoundary
              ? RegExp(r'\bRETURNING\b').hasMatch(code)
              : code.toUpperCase().contains(pattern);
          if (!hit) continue;
          final info = entry.value;
          offenders.add(
            '${entity.path}:${i + 1}  含 `$pattern`（需 SQLite ≥${info.minVersion}，'
            '即 API ≥${info.minApi}）→ 改用 ${info.instead}',
          );
        }
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'minSdk 是 flutter.minSdkVersion = 24，覆盖 Android 7/8/9（系统 SQLite ≤3.22）。\n'
          '以下位置用了需要更高版本 SQLite 的语法，会在这些设备上**静默失效**'
          '（容错层只上报不抛，用户与管理员都看不出异常）：\n${offenders.join('\n')}\n'
          '若确实必须用，请先把 minSdk 提到 29+ 并删除本守卫。',
    );
  });

  test('守卫前提仍成立：minSdk 仍低于 29（若已提高，本守卫应删除）', () {
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();
    final literal = RegExp(r'minSdk\s*=\s*(\d+)').firstMatch(gradle);
    if (literal != null) {
      final value = int.parse(literal.group(1)!);
      expect(value, lessThan(29), reason: 'minSdk 已提到 $value ⇒ 系统 SQLite 足够新，本守卫可以删除了（连同 kForbiddenSyntax）');
    } else {
      // flutter.minSdkVersion：Flutter 当前默认 24，仍在本守卫的适用范围内。
      expect(
        gradle.contains('flutter.minSdkVersion'),
        isTrue,
        reason: '既不是字面量也没引用 flutter.minSdkVersion —— 构建配置变了，请人工确认 minSdk 后更新本守卫',
      );
    }
  });
}
