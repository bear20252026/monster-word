// 单词笔记模型
// 用户对单词的个人笔记，支持增删改查

/// 单词笔记
class WordNote {
  final int? id;
  final int wordId;
  final String word;
  final String content;
  final String createdAt;
  final String updatedAt;

  WordNote({
    this.id,
    required this.wordId,
    required this.word,
    required this.content,
    String? createdAt,
    String? updatedAt,
  }) : createdAt = createdAt ?? _now(),
       updatedAt = updatedAt ?? _now();

  /// 数据层审计 P3：统一 ISO8601——note_repository_impl.addNote 写入的是
  /// ISO8601，此前默认构造生成 yyyyMMddHHmmss，同一 created_at 字段两种
  /// 格式并存导致字符串排序/展示错乱。
  static String _now() => DateTime.now().toIso8601String();

  WordNote copyWith({int? id, int? wordId, String? word, String? content, String? createdAt, String? updatedAt}) {
    return WordNote(
      id: id ?? this.id,
      wordId: wordId ?? this.wordId,
      word: word ?? this.word,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? _now(),
    );
  }

  factory WordNote.fromMap(Map<String, dynamic> map) => WordNote(
    id: map['id'] as int?,
    wordId: map['word_id'] as int,
    word: (map['word'] as String?) ?? '',
    content: (map['content'] as String?) ?? '',
    createdAt: (map['created_at'] as String?) ?? '',
    updatedAt: (map['updated_at'] as String?) ?? '',
  );

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'word_id': wordId,
    'word': word,
    'content': content,
    'created_at': createdAt,
    'updated_at': updatedAt,
  };
}
