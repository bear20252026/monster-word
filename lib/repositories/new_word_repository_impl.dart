import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../data/user_database.dart';
import '../models/new_word_record.dart';
import '../models/word.dart';
import 'new_word_repository.dart';

class NewWordRepositoryImpl implements NewWordRepository {
  NewWordRepositoryImpl(this._database);

  final UserDatabase _database;

  @override
  Future<bool> addNewWord(Word word, {String source = 'manual'}) async {
    _validateWord(word);
    if (await isNewWord(word.id)) {
      return false;
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    await _database.db.insert('new_words', {
      'word_id': word.id,
      'word_text': word.word,
      'source': source,
      'operation_code': 'add',
      'created_at': now,
      'updated_at': now,
      'synced_at': null,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    return true;
  }

  @override
  Future<List<NewWordRecord>> getNewWords({int? limit, int? offset}) async {
    final rows = await _database.db.query(
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
    final rows = await _database.db.rawQuery('SELECT COUNT(*) AS count FROM new_words WHERE operation_code = ?', const [
      'add',
    ]);
    return (rows.isNotEmpty ? rows.first['count'] as num? : null)?.toInt() ?? 0;
  }

  @override
  Future<bool> isNewWord(int wordId) async {
    final rows = await _database.db.query(
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
    if (!await isNewWord(wordId)) {
      return false;
    }

    final updated = await _database.db.update(
      'new_words',
      {'operation_code': 'remove', 'updated_at': DateTime.now().millisecondsSinceEpoch, 'synced_at': null},
      where: 'word_id = ? AND operation_code = ?',
      whereArgs: [wordId, 'add'],
    );
    return updated > 0;
  }

  @override
  Future<bool> toggleNewWord(Word word, {String source = 'manual'}) async {
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
