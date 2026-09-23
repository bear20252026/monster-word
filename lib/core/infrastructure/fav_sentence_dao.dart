// 由 Claude 团队生成 | Monster Word App
// 收藏例句数据访问层：管理用户收藏的例句。
//
// MEM/U3：SQLite（user_data.db.favorite_sentences）为事实来源——内存只保留
// (wordId, sentenceId) 索引供同步判重，句子载荷仅在列表页查询时瞬时物化，
// 不再常驻单例缓存；新增/删除为单行 UPSERT/DELETE，不再整表 jsonEncode 重写。
// FLUTTER_TEST 未注入数据库、或开库失败时，回退旧 SP（fav_sentence_list）
// 行为；SP 键永久保留为回滚快照，迁移幂等（marker + 主键冲突忽略）。

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:word_app/core/infrastructure/user_database.dart';
import 'package:word_app/core/utils/swallowed_error_report.dart';
import 'package:word_app/models/sentence_models.dart';

/// 收藏例句 DAO（数据访问对象）
class FavSentenceDao {
  FavSentenceDao({Future<Database> Function()? openDatabase}) : _openOverride = openDatabase;

  static final FavSentenceDao instance = FavSentenceDao._();

  FavSentenceDao._() : _openOverride = null;

  static const String _spKey = 'fav_sentence_list';
  static const String _migratedMarker = 'fav_sentence_sqlite_migrated_v1';

  /// 测试注入口：提供即强制 SQLite 模式（绕过 FLUTTER_TEST 探测）。
  final Future<Database> Function()? _openOverride;

  Database? _db;
  // 同步判重索引：wordId → sentenceId 集合（不含载荷）
  final Map<int, Set<String>> _indexByWordId = <int, Set<String>>{};
  int _indexCount = 0;
  Future<void>? _loading;
  bool _useSqlite = false;

  // SP 回退模式的旧全量缓存（保持迁移前行为）
  List<FavSentenceData> _cache = [];

  bool get usesSqlite => _useSqlite;

  Future<SharedPreferences> _spPrefs() => SharedPreferences.getInstance();

  /// 加载全部收藏例句（按更新时间倒序）。
  ///
  /// SQLite 模式每次现查（列表页拿到新鲜数据，载荷不常驻内存）；
  /// SP 回退模式保持旧全量缓存行为。
  Future<List<FavSentenceData>> loadAll() async {
    await ensureLoaded();
    if (!_useSqlite) return _cache;

    final rows = await _db!.query('favorite_sentences', orderBy: 'update_time DESC');
    return rows.map(_favFromRow).toList(growable: false);
  }

  /// MEM/U3：首次访问建同步判重索引并完成 SP → SQLite 迁移（幂等，单事务）。
  Future<void> ensureLoaded() {
    return _loading ??= _ensureLoadedInner();
  }

  Future<void> _ensureLoadedInner() async {
    final override = _openOverride;
    if (override == null && !kIsWeb && !Platform.environment.containsKey('FLUTTER_TEST')) {
      try {
        await UserDatabase.instance.initialize();
        final db = UserDatabase.instance.db;
        await _migrateFromSpIfNeeded(db);
        await _buildIndex(db);
        _db = db;
        _useSqlite = true;
        return;
      } catch (e, s) {
        reportSwallowedError('FavSentenceDao sqlite init', e, s);
      }
    } else if (override != null) {
      try {
        final db = await override();
        await _migrateFromSpIfNeeded(db);
        await _buildIndex(db);
        _db = db;
        _useSqlite = true;
        return;
      } catch (e, s) {
        reportSwallowedError('FavSentenceDao sqlite init', e, s);
      }
    }
    // SP 回退：测试环境（未注入）/开库失败，保持迁移前的旧行为
    _cache = await _loadSpCache();
    _useSqlite = false;
  }

  Future<void> _buildIndex(Database db) async {
    final rows = await db.query('favorite_sentences', columns: ['word_id', 'sentence_id']);
    _indexByWordId.clear();
    _indexCount = 0;
    for (final row in rows) {
      final wordId = (row['word_id'] as num?)?.toInt() ?? 0;
      final sentenceId = row['sentence_id']! as String;
      _indexByWordId.putIfAbsent(wordId, () => <String>{}).add(sentenceId);
      _indexCount++;
    }
  }

  /// SP → SQLite 首启迁移：逐行原样保存 SP JSON（无损往返），单事务，快照保留。
  Future<void> _migrateFromSpIfNeeded(Database db) async {
    final prefs = await _spPrefs();
    if (prefs.getString(_migratedMarker) == 'done') return;

    final raw = prefs.getString(_spKey);
    if (raw != null && raw.isNotEmpty) {
      List<dynamic> jsonList;
      try {
        jsonList = jsonDecode(raw) as List<dynamic>;
      } catch (_) {
        jsonList = const <dynamic>[];
      }
      var inserted = 0;
      await db.transaction((txn) async {
        for (final entry in jsonList) {
          if (entry is! Map<String, dynamic>) continue;
          final fav = FavSentenceData.fromJson(entry);
          final rowId = await txn.insert('favorite_sentences', {
            'word_id': fav.wordId,
            'sentence_id': fav.sentenceId,
            'word': fav.word,
            'update_time': fav.updateTime,
            'data_json': jsonEncode(entry),
          }, conflictAlgorithm: ConflictAlgorithm.replace);
          if (rowId != 0) inserted++;
        }
        final counted = await txn.rawQuery('SELECT COUNT(*) AS n FROM favorite_sentences');
        final total = (counted.single['n'] as int?) ?? 0;
        if (total < inserted) {
          throw StateError('收藏例句迁移行数校验失败：预期 ≥$inserted，实际 $total');
        }
      });
    }
    await prefs.setString(_migratedMarker, 'done');
  }

  FavSentenceData _favFromRow(Map<String, Object?> row) {
    try {
      return FavSentenceData.fromJson(jsonDecode(row['data_json']! as String) as Map<String, dynamic>);
    } catch (e, s) {
      // 列回退重构：data_json 损坏时用结构化列兜底（句子载荷可能不全但不丢行）
      reportSwallowedError('FavSentenceDao row decode', e, s);
      return FavSentenceData(
        word: (row['word'] as String?) ?? '',
        wordId: (row['word_id'] as num?)?.toInt() ?? 0,
        sentenceId: row['sentence_id']! as String,
        updateTime: row['update_time']! as String,
      );
    }
  }

  // ── 同步读（索引口径，SQLite 模式） ─────────────────────────────────────

  /// 检查是否已收藏（索引判重，不触碰载荷）。
  bool isFavSentence(int wordId, String sentenceId) {
    if (_useSqlite) return _indexByWordId[wordId]?.contains(sentenceId) ?? false;
    return _cache.any((e) => e.wordId == wordId && e.sentenceId == sentenceId);
  }

  /// 获取收藏例句数量。
  int get favCount => _useSqlite ? _indexCount : _cache.length;

  // ── 写路径（索引先行 + 单行持久化） ─────────────────────────────────────

  /// 添加收藏例句
  Future<bool> addFavSentence({
    required String word,
    required int wordId,
    required String sentenceId,
    required SentenceData sentenceData,
    String wordUsage = '',
    int type = 0,
  }) async {
    await ensureLoaded();
    if (isFavSentence(wordId, sentenceId)) return false;

    final now = DateTime.now();
    final updateTime =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}'
        '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';

    final favData = FavSentenceData(
      word: word,
      wordId: wordId,
      sentenceId: sentenceId,
      sentenceData: sentenceData,
      wordUsage: wordUsage,
      updateTime: updateTime,
      type: type,
    );

    if (_useSqlite) {
      _indexByWordId.putIfAbsent(wordId, () => <String>{}).add(sentenceId);
      _indexCount++;
      try {
        await _db!.insert('favorite_sentences', {
          'word_id': wordId,
          'sentence_id': sentenceId,
          'word': word,
          'update_time': updateTime,
          'data_json': jsonEncode(favData.toJson()),
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      } catch (e, s) {
        reportSwallowedError('FavSentenceDao add persist', e, s);
      }
      return true;
    }

    _cache.insert(0, favData);
    await _saveAll();
    return true;
  }

  /// 取消收藏例句
  Future<bool> removeFavSentence(int wordId, String sentenceId) async {
    await ensureLoaded();

    if (_useSqlite) {
      final ids = _indexByWordId[wordId];
      if (ids == null || !ids.remove(sentenceId)) return false;
      if (ids.isEmpty) _indexByWordId.remove(wordId);
      _indexCount--;
      try {
        await _db!.delete(
          'favorite_sentences',
          where: 'word_id = ? AND sentence_id = ?',
          whereArgs: [wordId, sentenceId],
        );
      } catch (e, s) {
        reportSwallowedError('FavSentenceDao remove persist', e, s);
      }
      return true;
    }

    final index = _cache.indexWhere((e) => e.wordId == wordId && e.sentenceId == sentenceId);
    if (index == -1) return false;
    _cache.removeAt(index);
    await _saveAll();
    return true;
  }

  /// 切换收藏状态
  Future<bool> toggleFavSentence({
    required String word,
    required int wordId,
    required String sentenceId,
    required SentenceData sentenceData,
    String wordUsage = '',
    int type = 0,
  }) async {
    if (isFavSentence(wordId, sentenceId)) {
      return removeFavSentence(wordId, sentenceId);
    } else {
      return addFavSentence(
        word: word,
        wordId: wordId,
        sentenceId: sentenceId,
        sentenceData: sentenceData,
        wordUsage: wordUsage,
        type: type,
      );
    }
  }

  /// 清空缓存（用于刷新；SQLite 模式下仅丢弃已建索引，下次访问重建）
  void clearCache() {
    _indexByWordId.clear();
    _indexCount = 0;
    _cache = [];
    _loading = null;
  }

  // ── SP 回退持久化（迁移前旧逻辑） ────────────────────────────────────────

  Future<List<FavSentenceData>> _loadSpCache() async {
    final jsonStr = (await _spPrefs()).getString(_spKey);
    if (jsonStr == null || jsonStr.isEmpty) return [];
    try {
      final List<dynamic> jsonList = jsonDecode(jsonStr);
      final list = jsonList.map((e) => FavSentenceData.fromJson(e as Map<String, dynamic>)).toList();
      list.sort((a, b) => b.updateTime.compareTo(a.updateTime));
      return list;
    } catch (e) {
      return [];
    }
  }

  Future<void> _saveAll() async {
    final prefs = await _spPrefs();
    final jsonStr = jsonEncode(_cache.map((e) => e.toJson()).toList());
    await prefs.setString(_spKey, jsonStr);
  }
}
