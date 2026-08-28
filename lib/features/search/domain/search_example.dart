// 搜索功能域 · 例句实体。
//
// 从 lib/data/example_parser.dart 迁入，保持 domain 纯净（无 Flutter / data 依赖）。

/// 单条搜索例句。
class SearchExample {
  final String en; // 英文例句（可能含 <b> 标签）
  final String cn; // 中文翻译
  final String source; // 来源（剧集 / 考试）
  final String? audioUrl; // 音频 URL

  const SearchExample({
    required this.en,
    required this.cn,
    this.source = '',
    this.audioUrl,
  });

  /// 去掉 <b> 高亮标签
  String get cleanEn => en.replaceAll('<b>', '').replaceAll('</b>', '');

  /// 高亮单词（把 <b> 转成带色文本段）
  List<HighlightPart> get highlightedParts {
    final parts = <HighlightPart>[];
    final regex = RegExp(r'<b>(.*?)</b>');
    var last = 0;
    for (final m in regex.allMatches(en)) {
      if (m.start > last) {
        parts.add(HighlightPart(en.substring(last, m.start), false));
      }
      parts.add(HighlightPart(m.group(1)!, true));
      last = m.end;
    }
    if (last < en.length) {
      parts.add(HighlightPart(en.substring(last), false));
    }
    if (parts.isEmpty && en.isNotEmpty) {
      parts.add(HighlightPart(en, false));
    }
    return parts;
  }
}

/// 高亮片段。
class HighlightPart {
  final String text;
  final bool highlight;
  const HighlightPart(this.text, this.highlight);
}
