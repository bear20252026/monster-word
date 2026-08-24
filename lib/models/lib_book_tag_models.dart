// 由 Claude 团队生成 | Monster Word App

// 数据模型层：翻译自 bean/（v3.2 源码 1:1）
// 文件：LibBookLevel1Tag + LibBookLevel2Tag + CategoryLibBooks + LexisLibrary

import 'lib_book.dart';

/// 词书一级标签（翻译自 LibBookLevel1Tag.java）
class LibBookLevel1Tag {
  final int id;
  final String name;

  LibBookLevel1Tag({
    this.id = 0,
    this.name = '',
  });

  factory LibBookLevel1Tag.fromJson(Map<String, dynamic> json) =>
      LibBookLevel1Tag(
        id: (json['id'] as num?)?.toInt() ?? 0,
        name: json['name'] ?? '',
      );
}

/// 词书二级标签（翻译自 LibBookLevel2Tag.java）
class LibBookLevel2Tag {
  final int id;
  final String name;
  final int bookCount;
  final int bookDeletable;

  LibBookLevel2Tag({
    this.id = 0,
    this.name = '',
    this.bookCount = 0,
    this.bookDeletable = 0,
  });

  bool get isBookDeletable => bookDeletable == 1;

  factory LibBookLevel2Tag.fromJson(Map<String, dynamic> json) =>
      LibBookLevel2Tag(
        id: (json['id'] as num?)?.toInt() ?? 0,
        name: json['name'] ?? '',
        bookCount: (json['bookCount'] as num?)?.toInt() ?? 0,
        bookDeletable: (json['bookDeletable'] as num?)?.toInt() ?? 0,
      );
}

/// 分类词书（翻译自 CategoryLibBooks.java）
class CategoryLibBooks {
  final LibBookLevel1Tag? lvl1Tag;
  final List<LibBookLevel2Tag> lvl2Tags;
  final List<LibBook> books;

  CategoryLibBooks({
    this.lvl1Tag,
    List<LibBookLevel2Tag>? lvl2Tags,
    List<LibBook>? books,
  })  : lvl2Tags = lvl2Tags ?? [],
        books = books ?? [];

  int get level1TagId => lvl1Tag?.id ?? -1;

  /// 获取二级标签名称列表
  List<String> get level2TagNames => lvl2Tags.map((t) => t.name).toList();

  /// 根据名称查找二级标签
  LibBookLevel2Tag? getLevel2TagByName(String name) {
    for (final tag in lvl2Tags) {
      if (tag.name == name) return tag;
    }
    return null;
  }

  /// 根据 bookId 查找词书
  LibBook? getLibBookByBookId(int id) {
    for (final book in books) {
      if (book.id == id) return book;
    }
    return null;
  }

  factory CategoryLibBooks.fromJson(Map<String, dynamic> json) =>
      CategoryLibBooks(
        lvl1Tag: json['lvl1Tag'] != null
            ? LibBookLevel1Tag.fromJson(
                json['lvl1Tag'] as Map<String, dynamic>)
            : null,
        lvl2Tags: (json['lvl2Tags'] as List?)
                ?.map((e) =>
                    LibBookLevel2Tag.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        books: (json['books'] as List?)
                ?.map((e) => LibBook.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
      );

  static List<CategoryLibBooks> fromJsonArray(List<dynamic> arr) {
    return arr
        .map((e) => CategoryLibBooks.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

/// 词库常量（翻译自 LexisLibrary.java）
class LexisLibrary {
  static const String newWordCode = 'V3_NEW_WORD';
  static const String fieldBookId = 'id';
  static const String fieldBooks = 'books';
  static const String fieldCode = 'code';
  static const String fieldCount = 'count';
  static const String fieldCover = 'cover';
  static const String fieldDesc = 'desc';
  static const String fieldLvl1TagName = 'lvl1TagName';
  static const String fieldName = 'name';
  static const String fieldSortBy = 'sortBy';
  static const String fieldUrl = 'url';
  static const String fieldVersion = 'version';
}
