// 由 Claude 团队生成 | Monster Word App

// 由账号4生成
// 例句解析器：从词库 example JSON 中提取中英文例句
// 词库格式：
// {"v":1,"data":[{"oid":...,"i":{"e":"英文释义","c":"中文释义","p":"词性"},
//   "g":[{"uid":0,"u":"用法","s":[{"eid":...,"e":"英文例句","c":"中文翻译","b":"来源剧集"}]}]}]}
// 注意：全库 84%（21,076/25,191）词条的 example 外层多包了一层 JSON 字符串
// （双重编码），解析时统一二次解码（REG-DICT-004）。
import 'dart:convert';

/// 单条例句
class ExampleSentence {
  final String en; // 英文例句（可能含 <b> 标签）
  final String cn; // 中文翻译
  final String source; // 来源（剧集/考试）
  final String? audioUrl; // 音频 URL

  ExampleSentence({required this.en, required this.cn, this.source = '', this.audioUrl});

  /// 去掉 <b> 高亮标签
  String get cleanEn => en.replaceAll('<b>', '').replaceAll('</b>', '');

  /// 高亮单词（把 <b> 转成带色文本段）
  List<HighlightPart> get highlightedParts {
    return parseHighlights(en);
  }
}

/// 把含 <b> 标记的原文拆成高亮片段（单一实现，UI 层负责渲染样式）。
List<HighlightPart> parseHighlights(String en) {
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

/// 高亮片段
class HighlightPart {
  final String text;
  final bool highlight;
  HighlightPart(this.text, this.highlight);
}

/// 柯林斯式释义条目：释义（i）+ 用法说明（g.u）+ 该用法下的例句组（g.s）。
/// 一个词条可能有多个释义条目（data[]），每个条目下又有多个用法组（g[]）。
class CollinsSense {
  final String enDef; // 英文释义
  final String cnDef; // 中文释义
  final String pos; // 词性
  final String usage; // 用法说明（如 "an ~ to sth"，可空）
  final List<ExampleSentence> examples;

  const CollinsSense({
    required this.enDef,
    required this.cnDef,
    this.pos = '',
    this.usage = '',
    this.examples = const [],
  });
}

/// 解析词库 example 字段
class ExampleParser {
  /// 例句音频 CDN 域名
  static const String _audioCdn = 'https://audio.beingfine.cn/';

  /// 把例句音频相对路径归一为完整可播 URL。
  /// 例：'/sentence/audio/abc.mp3' -> 'https://audio.beingfine.cn/sentence/audio/abc.mp3'
  ///
  /// 注意：词库存的是 http:// 明文 URL。Android 9+ 默认禁明文流量（manifest 未开
  /// usesCleartextTraffic），http:// 例句会被系统静默拦截——这是「例句有的响有的不响」
  /// 的真凶（Windows 无此限制所以能响）。服务器已验证支持 https，此处统一升级。
  static String _normalizeAudioUrl(String url) {
    if (url.isEmpty) return url;
    if (url.startsWith('https://')) return url;
    if (url.startsWith('http://')) return 'https://${url.substring(7)}';
    return '$_audioCdn${url.replaceFirst(RegExp(r'^/+'), '')}';
  }

  /// 解码 example 原文：兼容单层 JSON 与双重编码（外层多包一层字符串，
  /// 占全库 84%——jsonDecode 一次得到 String，需二次解码）。
  /// 解析失败返回 null（调用方降级为空数据，绝不把原文当例句渲染）。
  static dynamic _decode(String raw) {
    dynamic decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      return null;
    }
    if (decoded is String) {
      try {
        decoded = jsonDecode(decoded);
      } catch (_) {
        return null;
      }
    }
    return decoded;
  }

  /// 从 data 列表取出（兼容 {"v":1,"data":[...]} 与裸 [...] 两种形态）
  static List<dynamic> _dataOf(dynamic decoded) {
    if (decoded is Map<String, dynamic>) return decoded['data'] as List? ?? [];
    if (decoded is List) return decoded;
    return const [];
  }

  /// 单条例句字段映射（e/c/b/u，音频统一归一 https）。
  static ExampleSentence? _sentenceFrom(Map<String, dynamic> s) {
    final en = (s['e'] as String?) ?? '';
    if (en.isEmpty) return null;
    final cn = (s['c'] as String?) ?? '';
    final source = (s['b'] as String?) ?? '';
    // 例句音频真实字段为 u（相对路径 /sentence/audio/xxx.mp3），
    // 兼容 audio/audioUrl 旧写法；统一归一为完整可播放 URL。
    var audioUrl = (s['u'] as String?) ?? (s['audio'] as String?) ?? (s['audioUrl'] as String?);
    if (audioUrl != null && audioUrl.isNotEmpty) {
      audioUrl = _normalizeAudioUrl(audioUrl);
    }
    return ExampleSentence(en: en, cn: cn, source: source, audioUrl: audioUrl);
  }

  /// 提取所有例句（含释义分组，拍平为一维列表）
  static List<ExampleSentence> parse(String raw) {
    final sentences = <ExampleSentence>[];
    final decoded = _decode(raw);
    for (final item in _dataOf(decoded)) {
      if (item is! Map<String, dynamic>) continue;
      for (final group in item['g'] as List? ?? []) {
        if (group is! Map<String, dynamic>) continue;
        for (final s in group['s'] as List? ?? []) {
          if (s is! Map<String, dynamic>) continue;
          final ex = _sentenceFrom(s);
          if (ex != null) sentences.add(ex);
        }
      }
    }
    return sentences;
  }

  /// 提取柯林斯式结构化释义（释义 + 用法 + 分组例句），供词典详情页「柯林斯」tab 渲染。
  static List<CollinsSense> parseCollins(String raw) {
    final senses = <CollinsSense>[];
    final decoded = _decode(raw);
    for (final item in _dataOf(decoded)) {
      if (item is! Map<String, dynamic>) continue;
      final i = item['i'];
      final enDef = i is Map<String, dynamic> ? (i['e'] as String?) ?? '' : '';
      final cnDef = i is Map<String, dynamic> ? (i['c'] as String?) ?? '' : '';
      final pos = i is Map<String, dynamic> ? (i['p'] as String?) ?? '' : '';

      final groups = item['g'] as List? ?? [];
      for (final group in groups) {
        if (group is! Map<String, dynamic>) continue;
        final usage = (group['u'] as String?) ?? '';
        final examples = <ExampleSentence>[];
        for (final s in group['s'] as List? ?? []) {
          if (s is! Map<String, dynamic>) continue;
          final ex = _sentenceFrom(s);
          if (ex != null) examples.add(ex);
        }
        senses.add(CollinsSense(enDef: enDef, cnDef: cnDef, pos: pos, usage: usage, examples: examples));
      }
      // 释义存在但无用法组：仍输出释义行（只释义、无例句）
      if (groups.isEmpty && enDef.isNotEmpty) {
        senses.add(CollinsSense(enDef: enDef, cnDef: cnDef, pos: pos));
      }
    }
    return senses;
  }
}
