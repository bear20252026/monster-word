import 'dart:convert';

/// 解析词库中 JSON 化释义的纯领域规则。
class DefinitionFormatter {
  const DefinitionFormatter._();

  /// 返回第一条可读的中文释义；无法解析时返回空字符串。
  static String extractChinese(String interpret) {
    if (interpret.trim().isEmpty) {
      return '';
    }

    try {
      final decoded = jsonDecode(interpret);
      if (decoded is! List || decoded.isEmpty) {
        return '';
      }

      final firstEntry = decoded.first;
      if (firstEntry is! Map) {
        return '';
      }

      final definitions = firstEntry['def'];
      if (definitions is! List || definitions.isEmpty) {
        return '';
      }

      final firstDefinition = definitions.first;
      if (firstDefinition is! Map) {
        return '';
      }

      final chinese = firstDefinition['cn'] ?? firstDefinition['cndef'] ?? '';
      return chinese is String ? chinese.trim() : '';
    } on FormatException {
      return '';
    } on TypeError {
      return '';
    }
  }
}
