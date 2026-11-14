// 学习伴侣 AI 化 · 小怪兽长期记忆 DAO（core/infrastructure）。
//
// SQLite（user_data.db.companion_memory，(kind,key) 主键）为事实来源；内存 Map
// 作同步读索引。照 MasteredWordsDao 先例：测试注入口 / 串行写闸门 / 写失败落
// DegradedJournal 启动回放 / FLUTTER_TEST 未注入或开库失败回退空记忆（对话降级
// 无记忆不阻断）。记忆为新增数据，无 SP 存量迁移。
import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:word_app/core/application/monster_memory_port.dart';
import 'package:word_app/core/infrastructure/degraded_journal.dart';
import 'package:word_app/core/infrastructure/user_database.dart';
import 'package:word_app/core/utils/swallowed_error_report.dart';

class CompanionMemoryDao implements MonsterMemoryPort {
  CompanionMemoryDao({Future<Database> Function()? openDatabase}) : _openOverride = openDatabase;

  static final CompanionMemoryDao instance = CompanionMemoryDao._();

  CompanionMemoryDao._() : _openOverride = null;

  static const String degradedJournalKey = 'companion_memory_degraded_journal_v1';
  final DegradedJournal _journal = const DegradedJournal(key: degradedJournalKey, domain: '小怪兽记忆');

  final Future<Database> Function()? _openOverride;

  Database? _db;
  final Map<String, MemoryEntry> _index = {};
  Future<void>? _loading;
  bool _useSqlite = false;

  bool get usesSqlite => _useSqlite;

  static String _idxKey(MemoryKind kind, String key) => '${kind.name}:$key';

  Future<void> ensureLoaded() => _loading ??= _ensureLoadedInner();

  Future<void> _ensureLoadedInner() async {
    final override = _openOverride;
    if (override != null) {
      try {
        await _activateSqlite(await override());
        return;
      } catch (e, s) {
        reportSwallowedError('CompanionMemoryDao sqlite init', e, s);
      }
    } else if (!kIsWeb && !Platform.environment.containsKey('FLUTTER_TEST')) {
      try {
        await UserDatabase.instance.initialize();
        await _activateSqlite(UserDatabase.instance.db);
        return;
      } catch (e, s) {
        reportSwallowedError('CompanionMemoryDao sqlite init', e, s);
      }
    }
    // 回退：测试未注入 / 开库失败 → 空记忆（对话降级无记忆不阻断）。
    _index.clear();
    _useSqlite = false;
  }

  Future<void> _activateSqlite(Database db) async {
    _db = db;
    _useSqlite = true;
    await _replayDegradedJournal();
    final rows = await db.query('companion_memory', orderBy: 'updated_at DESC');
    _index.clear();
    for (final row in rows) {
      final entry = _fromRow(row);
      _index[_idxKey(entry.kind, entry.key)] = entry;
    }
  }

  MemoryEntry _fromRow(Map<String, Object?> row) {
    final kind = MemoryKind.values.firstWhere((k) => k.name == row['kind'], orElse: () => MemoryKind.recent);
    return MemoryEntry(
      kind: kind,
      key: row['key']! as String,
      content: row['content']! as String,
      updatedAt: (row['updated_at'] as num).toInt(),
    );
  }

  Future<void> _replayDegradedJournal() async {
    final db = _db;
    if (db == null) return;
    await _journal.replay((entry) async {
      final kindName = entry['kind'] as String?;
      final key = entry['key'] as String?;
      if (kindName == null || key == null) return;
      final op = entry['op'] as String?;
      if (op == 'remove') {
        await db.delete('companion_memory', where: 'kind = ? AND key = ?', whereArgs: [kindName, key]);
        return;
      }
      await db.insert('companion_memory', {
        'kind': kindName,
        'key': key,
        'content': entry['content'] as String? ?? '',
        'updated_at': (entry['at'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  // ── 写路径（索引先行 + 单行持久化，串行闸门） ─────────────────────────────

  Future<void> _writeGate = Future.value();

  Future<T> _serialized<T>(Future<T> Function() action) {
    final result = _writeGate.then((_) => action());
    _writeGate = result.then((_) {}, onError: (Object _) {});
    return result;
  }

  @override
  Future<void> put(MemoryKind kind, String key, String content) async {
    await ensureLoaded();
    await _serialized(() async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final entry = MemoryEntry(kind: kind, key: key, content: content, updatedAt: now);
      _index[_idxKey(kind, key)] = entry;
      final db = _db;
      if (_useSqlite && db != null) {
        try {
          await db.insert('companion_memory', {
            'kind': kind.name,
            'key': key,
            'content': content,
            'updated_at': now,
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        } catch (e, s) {
          reportSwallowedError('CompanionMemoryDao put persist', e, s);
          final journaled = await _journal.append({
            'op': 'put',
            'kind': kind.name,
            'key': key,
            'content': content,
            'at': now,
          });
          if (!journaled) {
            _index.remove(_idxKey(kind, key));
            reportSwallowedError('记忆写入失败且降级日志不可用', StateError('DB+journal 双失败：$key'), s);
          }
        }
      }
    });
  }

  @override
  Future<List<MemoryEntry>> read(MemoryKind kind) async {
    await ensureLoaded();
    final list = _index.values.where((e) => e.kind == kind).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  }

  @override
  Future<MemoryEntry?> get(MemoryKind kind, String key) async {
    await ensureLoaded();
    return _index[_idxKey(kind, key)];
  }

  @override
  Future<void> remove(MemoryKind kind, String key) async {
    await ensureLoaded();
    await _serialized(() async {
      _index.remove(_idxKey(kind, key));
      final db = _db;
      if (_useSqlite && db != null) {
        try {
          await db.delete('companion_memory', where: 'kind = ? AND key = ?', whereArgs: [kind.name, key]);
        } catch (e, s) {
          reportSwallowedError('CompanionMemoryDao remove persist', e, s);
          final journaled = await _journal.append({'op': 'remove', 'kind': kind.name, 'key': key});
          if (!journaled) {
            reportSwallowedError('记忆删除失败且降级日志不可用', StateError('DB+journal 双失败：$key'), s);
          }
        }
      }
    });
  }

  @override
  Future<void> trimRecent(int limit) async {
    await ensureLoaded();
    final recent = await read(MemoryKind.recent);
    if (recent.length <= limit) return;
    for (final old in recent.skip(limit)) {
      await remove(MemoryKind.recent, old.key);
    }
  }
}
