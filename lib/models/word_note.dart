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

  static String _now() {
    final d = DateTime.now();
    return '${d.year}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}'
        '${d.hour.toString().padLeft(2, '0')}${d.minute.toString().padLeft(2, '0')}${d.second.toString().padLeft(2, '0')}';
  }

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
