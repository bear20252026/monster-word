import '../../../models/definition.dart';

/// 单条释义值对象。
///
/// 封装一个词性下的所有释义文本，纯数据，无外部依赖。
class DefinitionItem {
  const DefinitionItem({
    required this.partOfSpeech,
    required this.definitions,
  });

  /// 词性（如 "n."、"v."、"adj."）
  final String partOfSpeech;

  /// 该词性下的释义列表
  final List<String> definitions;

  bool get hasDefinitions => definitions.isNotEmpty;

  /// 将释义格式化为单行文本，用分号连接。
  String get formatted => definitions.join('; ');

  /// 从 `Word.parsedDefinitions`（`List<Definition>`）创建。
  ///
  /// 按词性分组，将同一词性的中文释义聚合到一起。
  static List<DefinitionItem> fromParsed(List<Definition>? parsed) {
    if (parsed == null || parsed.isEmpty) return const [];
    final grouped = <String, List<String>>{};
    for (final d in parsed) {
      final pos = d.partOfSpeech.trim();
      final text = d.cnDef.trim().isEmpty ? d.enDef.trim() : d.cnDef.trim();
      if (text.isEmpty) continue;
      grouped.putIfAbsent(pos, () => []);
      grouped[pos]!.add(text);
    }
    return grouped.entries
        .map((e) => DefinitionItem(partOfSpeech: e.key, definitions: e.value))
        .toList();
  }
}
