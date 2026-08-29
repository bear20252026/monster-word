// 由 Claude 团队生成 | Monster Word App

// 由账号4生成
// 例句解析器：从词库 example JSON 中提取中英文例句
// 词库格式：
// {"v":1,"data":[{"oid":...,"i":{"e":"英文释义","c":"中文释义","p":"词性"},
//   "g":[{"uid":0,"u":"用法","s":[{"eid":...,"e":"英文例句","c":"中文翻译","b":"来源剧集"}]}]}]}
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

/// 高亮片段
class HighlightPart {
  final String text;
  final bool highlight;
  HighlightPart(this.text, this.highlight);
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

  /// 提取所有例句（含释义分组）
  static List<ExampleSentence> parse(String raw) {
    final sentences = <ExampleSentence>[];
    if (raw.isEmpty) return sentences;

    try {
      final decoded = jsonDecode(raw);
      final data = decoded is Map<String, dynamic> ? (decoded['data'] as List? ?? []) : (decoded as List? ?? []);

      for (final item in data) {
        if (item is! Map<String, dynamic>) continue;
        final groups = item['g'] as List? ?? [];
        for (final group in groups) {
          if (group is! Map<String, dynamic>) continue;
          final sList = group['s'] as List? ?? [];
          for (final s in sList) {
            if (s is! Map<String, dynamic>) continue;
            final en = (s['e'] as String?) ?? '';
            final cn = (s['c'] as String?) ?? '';
            final source = (s['b'] as String?) ?? '';
            // 例句音频真实字段为 u（相对路径 /sentence/audio/xxx.mp3），
            // 兼容 audio/audioUrl 旧写法；统一归一为完整可播放 URL。
            var audioUrl = (s['u'] as String?) ??
                (s['audio'] as String?) ??
                (s['audioUrl'] as String?);
            if (audioUrl != null && audioUrl.isNotEmpty) {
              audioUrl = _normalizeAudioUrl(audioUrl);
            }
            if (en.isNotEmpty) {
              sentences.add(ExampleSentence(en: en, cn: cn, source: source, audioUrl: audioUrl));
            }
          }
        }
      }
    } catch (_) {
      // 解析失败返回空
    }
    return sentences;
  }
}
