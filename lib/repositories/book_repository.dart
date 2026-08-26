// 由 Claude 团队生成 | Monster Word App
// BookRepository — 词书数据访问抽象

import '../../models/book.dart';

/// 词书数据仓库接口
/// 
/// 提供词书（Book）的 CRUD 操作抽象。
/// 实现类负责具体的数据库/网络访问细节。
abstract class BookRepository {
  /// 获取所有词书
  Future<List<Book>> getBooks();

  /// 根据 ID 获取词书
  Future<Book?> getBookById(int id);

  /// 获取指定词书的单词数量
  Future<int> getWordCount(int bookId);

  /// 搜索词书（按名称）
  Future<List<Book>> searchBooks(String query);

  /// 添加词书
  Future<int> insertBook(Book book);

  /// 更新词书
  Future<int> updateBook(Book book);

  /// 删除词书
  Future<int> deleteBook(int id);
}
