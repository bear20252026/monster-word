import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:word_app/core/infrastructure/degraded_journal.dart';
import 'package:word_app/core/infrastructure/user_database.dart';
import 'package:word_app/core/utils/swallowed_error_report.dart';
import 'package:word_app/models/new_word_record.dart';
import 'package:word_app/models/word.dart';
import 'package:word_app/core/repositories/new_word_repository.dart';

class NewWordRepositoryImpl implements NewWordRepository {
  NewWordRepositoryImpl(this._database, {Database? databaseOverride}) : _override = databaseOverride;

  final UserDatabase _database;

  /// 测试注入口：提供即绕过 [UserDatabase] 单例（内存库），
  /// 与 FavoriteWordsDao / FavSentenceDao 的 `openDatabase` 注入口同款。
  final Database? _override;

  Database get _db => _override ?? _database.db;

  /// P1-01 余项：SQLite 写失败时的生词意图降级日志。
  ///
  /// 生词本是此前唯一**完全没有兜底**的写路径——`insert` 直接裸调，失败即抛给
  /// UI，用户的「加入生词本」当场丢失。此处按 FSRS journal 同款口径补齐：
  /// 幂等键为 word_id（new_words 主键），回放用 REPLACE / 标记 remove。
  static const String degradedJournalKey = 'new_words_degraded_journal_v1';
  final DegradedJournal _journal = const DegradedJournal(key: degradedJournalKey, domain: '生词本');

  Future<void>? _journalReplay;

  /// 切换串行闸：toggle 是「查后改」跨 await，快速双击两次都读到「未加入」
  /// 都走 add，终态停在已加入而非切换回（审计：check-then-act 竞态）。
  Future<void> _toggleQueue = Future<void>.value();

  /// 懒回放（单飞）：任何公开入口都会先触发一次，保证降级期间产生的加/删生词
  /// 在**本次启动内**即可见，而不必等到下一次冷启动。
  Future<void> _ensureJournalReplayed() => _journalReplay ??= _replayJournal();

  Future<void> _replayJournal() async {
    try {
      await _journal.replay((entry) async {
        final wordId = (entry['wordId'] as num?)?.toInt();
        if (wordId == null || wordId <= 0) return;
        final at = (entry['at'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch;
        if (entry['op'] == 'remove') {
          await _db.update(
            'new_words',
            {'operation_code': 'remove', 'updated_at': at, 'synced_at': null},
            where: 'word_id = ? AND operation_code = ?',
            whereArgs: [wordId, 'add'],
          );
          return;
        }
        final wordText = entry['wordText'] as String? ?? '';
        if (wordText.isEmpty) return;
        await _db.insert('new_words', {
          'word_id': wordId,
          'word_text': wordText,
          'source': entry['source'] as String? ?? 'manual',
          'operation_code': 'add',
          'created_at': at,
          'updated_at': at,
          'synced_at': null,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      });
    } catch (e, s) {
      reportSwallowedError('生词本降级日志回放失败（日志保留待下次启动重试）', e, s);
    }
  }

  @override
  Future<bool> addNewWord(Word word, {String source = 'manual'}) async {
    _validateWord(word);
    await _ensureJournalReplayed();
    if (await isNewWord(word.id)) {
      return false;
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    try {
      await _db.insert('new_words', {
        'word_id': word.id,
        'word_text': word.word,
        'source': source,
        'operation_code': 'add',
        'created_at': now,
        'updated_at': now,
        'synced_at': null,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    } catch (e, s) {
      reportSwallowedError('NewWordRepository add persist', e, s);
      // P1-01：落降级日志。日志写入成功即视为「已加入」——重启（或本进程
      // 后续入口）回放补上，用户这次操作不丢；只有日志也写不进才外抛，
      // 由调用方如实呈现失败。
      final journaled = await _journal.append({
        'op': 'add',
        'wordId': word.id,
        'wordText': word.word,
        'source': source,
        'at': now,
      });
      if (!journaled) rethrow;
    }
    return true;
  }

  @override
  Future<List<NewWordRecord>> getNewWords({int? limit, int? offset}) async {
    await _ensureJournalReplayed();
    final rows = await _db.query(
      'new_words',
      where: 'operation_code = ?',
      whereArgs: const ['add'],
      orderBy: 'updated_at DESC',
      limit: limit,
      offset: offset,
    );
    return rows.map((row) => NewWordRecord.fromMap(row)).toList();
  }

  @override
  Future<int> getNewWordCount() async {
    await _ensureJournalReplayed();
    final rows = await _db.rawQuery('SELECT COUNT(*) AS count FROM new_words WHERE operation_code = ?', const ['add']);
    return (rows.isNotEmpty ? rows.first['count'] as num? : null)?.toInt() ?? 0;
  }

  @override
  Future<bool> isNewWord(int wordId) async {
    await _ensureJournalReplayed();
    final rows = await _db.query(
      'new_words',
      columns: const ['word_id'],
      where: 'word_id = ? AND operation_code = ?',
      whereArgs: [wordId, 'add'],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  @override
  Future<bool> removeNewWord(int wordId) async {
    await _ensureJournalReplayed();
    if (!await isNewWord(wordId)) {
      return false;
    }

    final updatedAt = DateTime.now().millisecondsSinceEpoch;
    try {
      final updated = await _db.update(
        'new_words',
        {'operation_code': 'remove', 'updated_at': updatedAt, 'synced_at': null},
        where: 'word_id = ? AND operation_code = ?',
        whereArgs: [wordId, 'add'],
      );
      return updated > 0;
    } catch (e, s) {
      reportSwallowedError('NewWordRepository remove persist', e, s);
      // 同 add：日志保底成功则按「已移除」返回，回放补上。
      final journaled = await _journal.append({'op': 'remove', 'wordId': wordId, 'at': updatedAt});
      if (!journaled) rethrow;
      return true;
    }
  }

  @override
  Future<bool> toggleNewWord(Word word, {String source = 'manual'}) {
    final run = _toggleQueue.then((_) => _toggleNewWordLocked(word, source: source));
    _toggleQueue = run.then<void>((_) {}, onError: (Object _) {});
    return run;
  }

  Future<bool> _toggleNewWordLocked(Word word, {String source = 'manual'}) async {
    _validateWord(word);
    if (await isNewWord(word.id)) {
      await removeNewWord(word.id);
      return false;
    }
    await addNewWord(word, source: source);
    return true;
  }

  void _validateWord(Word word) {
    if (word.id <= 0 || word.word.trim().isEmpty) {
      throw ArgumentError.value(word, 'word', '生词本仅接受具有有效词库 ID 和文本的单词');
    }
  }
}
