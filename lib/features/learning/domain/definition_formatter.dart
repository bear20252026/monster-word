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

    // 用户反馈修复（2026-11-14）：先判定是否为合法 JSON。是 JSON 就只走结构化
    // 提取（遍历全部 entry/def），绝不回退到「含 CJK 即取第一行」——否则首 def
    // 无 cn 时会把原始 JSON 文本当中文释义泄漏到选项/队列。
    Object? decoded;
    try {
      decoded = jsonDecode(text);
    } on FormatException {
      decoded = null;
    }
    if (decoded is List) {
      return _extractFromJsonList(decoded);
    }

    // 回退：纯文本释义——含中文字符即有效，取第一行含中文的部分。
    if (_cjk.hasMatch(text)) {
      return text.split('\n').firstWhere((line) => _cjk.hasMatch(line), orElse: () => text).trim();
    }
    return '';
  }

  /// 遍历全部 entry 与 def，返回首个非空 cn/cndef（用户反馈修复 2026-11-14：
  /// 旧实现只读首 entry 首 def，后续 def 有 cn 的词被误判无中文而滤掉）。
  static String _extractFromJsonList(List decoded) {
    for (final entry in decoded) {
      if (entry is! Map) continue;
      final definitions = entry['def'];
      if (definitions is! List) continue;
      for (final definition in definitions) {
        if (definition is! Map) continue;
        final chinese = definition['cn'] ?? definition['cndef'] ?? '';
        if (chinese is String && chinese.trim().isNotEmpty) {
          return chinese.trim();
        }
      }
    }
    return '';
  }

  static final RegExp _duplicatedPosDots = RegExp(
    r'\b(n|v|vi|vt|adj|adv|a|ad|prep|conj|pron|art|num|interj)\.(?=\.)(\.+)',
  );

  /// 规范化用于选项/释义展示的文本：收紧词性标记后的重复句点。
  ///
  /// 词库原始数据存在 `"n.. 错误"`、`"adv.. 明显地"` 等脏格式，直接展示
  /// 观感差；此处仅在词性标记位置收紧（不影响释义中的省略号）。
  static String normalizeDisplay(String interpret) {
    return interpret.replaceAllMapped(_duplicatedPosDots, (match) => '${match.group(1)}.');
  }
}
