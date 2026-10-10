// 由 Claude 团队生成 | Monster Word App
// BookRepositoryImpl — 词书数据仓库实现

import 'package:word_app/core/infrastructure/wordbook_database.dart';
import 'package:word_app/features/book/data/book_repository.dart';
import 'package:word_app/core/utils/swallowed_error_report.dart';

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
    try {
      if (!_database.isInitialized) return [];
      final db = _database.db;
      final maps = await db.query('books');
      return maps.map((m) => Book.fromMap(m)).toList();
    } catch (e, s) {
      // SQL 异常不穿透到 UI；返回空列表由上层兜底（词书整页为空应远程可见）
      reportSwallowedError('BookRepositoryImpl.getBooks failed', e, s);
      return [];
    }
  }

  @override
  Future<Book?> getBookById(int id) async {
    try {
      final db = _database.db;
      final maps = await db.query('books', where: 'id = ?', whereArgs: [id]);
      if (maps.isEmpty) return null;
      return Book.fromMap(maps.first);
    } catch (e, s) {
      // 与 getBooks 同口径：库未初始化/查询异常不沿 getCurrentBook() 直抛 UI
      reportSwallowedError('BookRepositoryImpl.getBookById failed', e, s);
      return null;
    }
  }

  @override
  Future<int> getWordCount(int bookId) async {
    try {
      if (!_database.isInitialized) return 0;
      final db = _database.db;
      // 安全审计 R4：关联在 word_books 表（words 无 book_id 列）
      final result = await db.rawQuery('SELECT COUNT(*) as cnt FROM word_books WHERE book_id = ?', [bookId]);
      return (result.first['cnt'] as int?) ?? 0;
    } catch (e, s) {
      reportSwallowedError('BookRepositoryImpl.getWordCount failed', e, s);
      return 0;
    }
  }

  @override
  Future<List<Book>> searchBooks(String query) async {
    try {
      final db = _database.db;
      // LIKE 元字符转义（\ → % → _，与 word_repository_impl._escapeLike 同款）：
      // 输入 % 曾全库匹配。
      final escaped = query.replaceAll(r'\', r'\\').replaceAll('%', r'\%').replaceAll('_', r'\_');
      final maps = await db.query(
        'books',
        where: "name LIKE ? ESCAPE '\\' OR code LIKE ? ESCAPE '\\'",
        whereArgs: ['%$escaped%', '%$escaped%'],
      );
      return maps.map((m) => Book.fromMap(m)).toList();
    } catch (e, s) {
      reportSwallowedError('BookRepositoryImpl.searchBooks failed', e, s);
      return [];
    }
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
