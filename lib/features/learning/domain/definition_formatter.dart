import 'dart:convert';

/// 解析词库中 JSON 化释义的纯领域规则。
class DefinitionFormatter {
  const DefinitionFormatter._();

  /// 返回第一条可读的中文释义；无法解析时返回空字符串。
  static final RegExp _cjk = RegExp(r'[\u4e00-\u9fff]');

  /// 返回第一条可读的中文释义；无法解析时返回空字符串。
  ///
  /// 兼容两种词库格式：
  /// 1. JSON 结构 `[{"def":[{"cn":"..."}]}]`（新结构化释义）
  /// 2. 纯文本 `vi. 倒塌；崩溃\nvt. ...`（旧格式，实测占多数）。
  ///    此前只认 JSON，导致 ChoiceGenerator 把所有纯文本释义判为
  ///    "无中文候选"，四选一干扰项质量崩坏（选项混入英文释义）。
  static String extractChinese(String interpret) {
    final text = interpret.trim();
    if (text.isEmpty || text == '""') {
      return '';
    }

    final jsonChinese = _extractFromJson(text);
    if (jsonChinese.isNotEmpty) {
      return jsonChinese;
    }

    // 回退：纯文本释义——含中文字符即有效，取第一行含中文的部分。
    if (_cjk.hasMatch(text)) {
      return text
          .split('\n')
          .firstWhere((line) => _cjk.hasMatch(line), orElse: () => text)
          .trim();
    }
    return '';
  }

  static String _extractFromJson(String text) {
    try {
      final decoded = jsonDecode(text);
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
