/// 词书模型
///
/// 从 data/wordbook_database.dart 迁移到 models/ 层
class Book {
  final int id;
  final String code;
  final String name;
  final int wordCount;

  Book({required this.id, required this.code, required this.name, required this.wordCount});

  factory Book.fromMap(Map<String, dynamic> map) => Book(
    id: (map['id'] as num?)?.toInt() ?? 0,
    code: (map['code'] as String?) ?? '',
    name: (map['name'] as String?) ?? (map['code'] as String?) ?? '',
    wordCount: (map['word_count'] as num?)?.toInt() ?? 0,
  );

  Map<String, dynamic> toMap() => {'id': id, 'code': code, 'name': name, 'word_count': wordCount};
}
