/// 释义定义模型
///
/// 从 data/wordbook_database.dart 迁移到 models/ 层
class Definition {
  final String partOfSpeech; // 词性：n., vt., adj. 等
  final String enDef; // 英文释义
  final String cnDef; // 中文释义
  final List<DefExample> examples; // 例句列表

  const Definition({required this.partOfSpeech, required this.enDef, required this.cnDef, this.examples = const []});

  factory Definition.fromMap(Map<String, dynamic> map) => Definition(
    partOfSpeech: (map['partOfSpeech'] as String?) ?? '',
    enDef: (map['enDef'] as String?) ?? '',
    cnDef: (map['cnDef'] as String?) ?? '',
    examples: (map['examples'] as List?)?.map((e) => DefExample.fromMap(e as Map<String, dynamic>)).toList() ?? [],
  );
}

/// 释义中的例句
class DefExample {
  final String en;
  final String cn;

  const DefExample({required this.en, required this.cn});

  factory DefExample.fromMap(Map<String, dynamic> map) =>
      DefExample(en: (map['en'] as String?) ?? '', cn: (map['cn'] as String?) ?? '');
}
