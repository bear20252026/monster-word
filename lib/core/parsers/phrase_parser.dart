// 由 Claude 团队生成 | Monster Word App

// 短语/搭配解析器：从词库 phrase JSON 中提取中英文短语搭配
// 词库格式（示例）：
// [{"t":2,"p":[{"en":"abandon a child","cn":"抛弃孩子","exams":"[]"}],"pseqs":{"ZK":[ids]}}]
import 'dart:convert';

/// 单条短语/搭配
class PhraseItem {
  final String en; // 英文短语
  final String cn; // 中文释义
  final List<String> exams; // 考试标签（如高考/四级等）

  PhraseItem({required this.en, this.cn = '', this.exams = const []});

  bool get hasData => en.isNotEmpty;
}

/// 一组短语（同一词条下按类型 t 分组）
class PhraseGroup {
  final int type; // 短语类型标识（释义来源分组）
  final List<PhraseItem> items;

  PhraseGroup({this.type = 0, this.items = const []});

  bool get hasData => items.isNotEmpty;
}

/// 解析词库 phrase 字段
class PhraseParser {
  /// 解析短语 JSON 字符串，返回按类型分组的短语列表。
  /// 解析失败或空串返回空列表，绝不抛异常。
  static List<PhraseGroup> parse(String raw) {
    if (raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      final list = decoded is List ? decoded : <dynamic>[decoded];
      final groups = <PhraseGroup>[];
      for (final g in list) {
        if (g is! Map<String, dynamic>) continue;
        final t = (g['t'] as num?)?.toInt() ?? 0;
        final p = g['p'] as List? ?? const [];
        final items = <PhraseItem>[];
        for (final it in p) {
          if (it is! Map<String, dynamic>) continue;
          final en = _clean(it['en']);
          final cn = _clean(it['cn']);
          if (en.isEmpty) continue;
          items.add(PhraseItem(en: en, cn: cn, exams: _parseExams(it['exams'])));
        }
        if (items.isNotEmpty) {
          groups.add(PhraseGroup(type: t, items: items));
        }
      }
      return groups;
    } catch (_) {
      // B 级豁免：词条/词库数据解析降级，损坏数据不影响主流程（不逐条上报防刷屏，REG-OBS-001）
      return const [];
    }
  }

  /// 扁平化提取所有短语（忽略分组）
  static List<PhraseItem> flatItems(String raw) {
    final result = <PhraseItem>[];
    for (final g in parse(raw)) {
      result.addAll(g.items);
    }
    return result;
  }

  /// 是否含有可展示的短语
  static bool hasData(String raw) => flatItems(raw).isNotEmpty;

  static String _clean(Object? v) {
    final s = v is String ? v : (v?.toString() ?? '');
    return s.trim();
  }

  /// exams 可能是 JSON 数组字符串（"[\"高考\"]"）、纯逗号串或已是数组。
  static List<String> _parseExams(Object? exams) {
    final result = <String>[];
    if (exams is String) {
      final s = exams.trim();
      if (s.isEmpty || s == '[]') return result;
      if (s.startsWith('[')) {
        try {
          final decoded = jsonDecode(s);
          if (decoded is List) {
            for (final e in decoded) {
              final t = _clean(e);
              if (t.isNotEmpty) result.add(t);
            }
            return result;
          }
        } catch (_) {
          // 落入逗号拆分
        }
      }
      for (final e in s.split(RegExp(r'[,，、;；\s]+'))) {
        final t = e.trim();
        if (t.isNotEmpty) result.add(t);
      }
    } else if (exams is List) {
      for (final e in exams) {
        final t = _clean(e);
        if (t.isNotEmpty) result.add(t);
      }
    }
    return result;
  }
}
