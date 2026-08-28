// 由 Claude 团队生成 | Monster Word App
// BookRepositoryImpl — 词书数据仓库实现

import '../../data/wordbook_database.dart';
import 'book_repository.dart';

/// 词书数据仓库的具体实现
///
/// 通过 WordBookDatabase 访问底层数据。
/// 这是 Repository 模式的核心：UI/Service 层只依赖 BookRepository 接口，
/// 不知道也不关心底层是 SQLite、网络还是内存缓存。
class BookRepositoryImpl implements BookRepository {
  final WordBookDatabase _database;

  BookRepositoryImpl(this._database);

  @override
  Future<List<Book>> getBooks() async {
    final db = _database.db;
    final maps = await db.query('books');
    return maps.map((m) => Book.fromMap(m)).toList();
  }

  @override
  Future<Book?> getBookById(int id) async {
    final db = _database.db;
    final maps = await db.query('books', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Book.fromMap(maps.first);
  }

  @override
  Future<int> getWordCount(int bookId) async {
    final db = _database.db;
    final result = await db.rawQuery('SELECT COUNT(*) as cnt FROM words WHERE book_id = ?', [bookId]);
    return (result.first['cnt'] as int?) ?? 0;
  }

  @override
  Future<List<Book>> searchBooks(String query) async {
    final db = _database.db;
    final maps = await db.query('books', where: 'name LIKE ? OR code LIKE ?', whereArgs: ['%$query%', '%$query%']);
    return maps.map((m) => Book.fromMap(m)).toList();
  }

  @override
  Future<int> insertBook(Book book) async {
    return await _database.db.insert('books', {'code': book.code, 'name': book.name, 'word_count': book.wordCount});
  }

  @override
  Future<int> updateBook(Book book) async {
    return await _database.db.update(
      'books',
      {'code': book.code, 'name': book.name, 'word_count': book.wordCount},
      where: 'id = ?',
      whereArgs: [book.id],
    );
  }

  @override
  Future<int> deleteBook(int id) async {
    return await _database.db.delete('books', where: 'id = ?', whereArgs: [id]);
  }
}
