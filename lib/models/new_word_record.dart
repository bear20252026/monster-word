/// 用户手动加入生词本的持久化记录。
///
/// [wordId] 是词库中 `words.id` 的稳定身份；[wordText] 作为可读快照，
/// 用于诊断或词库更新后追溯来源，列表展示仍以词库中的 [Word] 为准。
/// [operationCode] 和 [syncedAt] 为后续同步链路保留变更语义。
class NewWordRecord {
  const NewWordRecord({
    required this.wordId,
    required this.wordText,
    required this.source,
    this.operationCode = 'add',
    required this.createdAt,
    int? updatedAt,
    this.syncedAt,
  }) : updatedAt = updatedAt ?? createdAt;

  final int wordId;
  final String wordText;
  final String source;
  final String operationCode;
  final int createdAt;
  final int updatedAt;
  final int? syncedAt;

  factory NewWordRecord.fromMap(Map<String, Object?> map) {
    return NewWordRecord(
      wordId: (map['word_id'] as num?)?.toInt() ?? 0,
      wordText: map['word_text'] as String? ?? '',
      source: map['source'] as String? ?? '',
      operationCode: map['operation_code'] as String? ?? 'add',
      createdAt: (map['created_at'] as num?)?.toInt() ?? 0,
      updatedAt: (map['updated_at'] as num?)?.toInt() ?? 0,
      syncedAt: (map['synced_at'] as num?)?.toInt(),
    );
  }

  Map<String, Object?> toMap() {
    return {
      'word_id': wordId,
      'word_text': wordText,
      'source': source,
      'operation_code': operationCode,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'synced_at': syncedAt,
    };
  }
}
