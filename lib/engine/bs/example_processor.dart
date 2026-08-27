// 移植自 v3.2 bs/ExampleProcessor.java
// 例句处理器：HTML 生成、JSON/HTML 解析、单词级 span 高亮
// 用于 WebView 展示例句（普通模式 + 锁屏模式）

import 'dart:convert';

import '../../models/lexis_dict.dart';
import '../../models/sentence_models.dart';
import '../../utils/app_utils.dart';
import '../../utils/data_utils.dart';

/// 例句处理器（翻译自 ExampleProcessor.java）
class ExampleProcessor {
  static const int typeNormal = 0;
  static const int typeLock = 1;

  // --- HTML 模板（翻译自原版 lockHtmlFormat / normalHtmlFormat / sentStrFormat）---
  static const _lockHtmlFormat =
      "<html lang='en'><head><meta charset='UTF-8'><title>不背单词</title>"
      "<meta name='viewport' content='width=device-width, maximum-scale=1.0, user-scalable=no'/>"
      "<link rel='stylesheet' href='file:///android_asset/sentence_lock.css'>"
      "<style type='text/css'> span.s {color:#393939;background-color:%s;border-radius:4px;margin: 0 -2px; padding: 0 2px;}</style>"
      "<style type='text/css'> span.bs {color:#393939;background-color:%s;border-radius:4px;margin: 0 -2px; padding: 0 2px;}</style>"
      "<style type='text/css'> span.b {color:%s;}</style>"
      "</head><body><span id='rus'></span><div class='example-container'>%s</div></body></html>";

  static const _normalHtmlFormat =
      "<html lang='en'><head><meta charset='UTF-8'><title>不背单词</title>"
      "<meta name='viewport' content='width=device-width, maximum-scale=1.0, user-scalable=no'/>"
      "<link rel='stylesheet' href='file:///android_asset/example.css'>"
      "<style type='text/css'> span.s {color:#393939;background-color:%s;border-radius:4px;margin: 0 -2px; padding: 0 2px;}</style>"
      "<style type='text/css'> span.bs {color:#393939;background-color:%s;border-radius:4px;margin: 0 -2px; padding: 0 2px;}</style>"
      "<style type='text/css'> span.b {color:%s;}</style>"
      "</head><body><span id='rus'></span><div class='example-container' style='height:%spx;'>%s</div></body>"
      "<script src='file:///android_asset/js/zepto.js'></script>"
      "<script src='file:///android_asset/js/touch.js'></script>"
      "<script src='file:///android_asset/js/lexis-func.js'></script>"
      "<script src='file:///android_asset/js/lexis-select.js'></script></html>";

  static const _sentStrFormat =
      "<section class='example-form-wrap' id='exampleFormWrap' data-src='%s'>"
      "<img src='%s' class='example-form-pic' id='exampleFormPic' "
      "onerror=\"javascript:this.src='file:///android_asset/ic_lrc.png'\">"
      "<dl class='example-form-item'><dt>例句来自：</dt><dd>%s</dd></dl></section>"
      "<section class='example-wrap' id='exampleWrap' data-src='%s'>"
      "<article><div class='en-sentence'><p style=\"font-family:%s\">%s</p></div>"
      "<p class='ch-sentence'>%s</p></article><div class='temp-wrap'></div></section>";

  final int _type;
  final String _htmlFormat;

  ExampleProcessor({int type = typeNormal})
    : _type = type,
      _htmlFormat = type == typeNormal ? _normalHtmlFormat : _lockHtmlFormat;

  /// 主题色（原版 getThemeColorStr）
  static String get themeColorStr => '#e0c964';

  /// 字体名（原版 getSentenceFontName）
  static String get sentenceFontName => 'Hind-Regular';

  // ---------------------------------------------------------------------------
  // createExamples — 批量生成例句 HTML
  // ---------------------------------------------------------------------------

  /// 生成例句 HTML 列表和音频 URL 列表
  /// [sentences] 例句数据, [height] WebView 高度, [htmlList] 输出 HTML, [audioList] 输出音频
  /// [buildHtml] 是否生成 HTML（false 则只提取音频）
  void createExamples(
    List<SentenceData> sentences,
    int height,
    List<String> htmlList,
    List<String> audioList, {
    bool buildHtml = true,
  }) {
    audioList.clear();
    htmlList.clear();

    if (buildHtml) {
      if (sentences.isEmpty) {
        htmlList.add(_buildNoSentenceHtml(height));
        return;
      }
    }

    final audioUrls = List<String>.filled(sentences.length, '');
    for (var i = 0; i < sentences.length; i++) {
      if (buildHtml) {
        htmlList.add(_getExampleByIndex(sentences, height, audioUrls, i));
      } else {
        audioUrls[i] = sentences[i].u;
      }
    }
    audioList.addAll(audioUrls);
  }

  String _buildNoSentenceHtml(int height) {
    final color = themeColorStr;
    const body =
        "<section class='example-wrap no-sentence' id='exampleWrap'>"
        "<article>该单词暂无例句，我们会尽快补充。</article></section>";
    if (_type == typeNormal) {
      return _fmt(_htmlFormat, [color, color, color, height, body]);
    } else {
      return _fmt(_htmlFormat, [color, color, color, body]);
    }
  }

  String _getExampleByIndex(List<SentenceData> sentences, int height, List<String> audioArr, int index) {
    final color = themeColorStr;
    final sentence = sentences[index];
    final audio = sentence.u;
    audioArr[index] = audio;

    if (StrUtils.isEmpty(audio)) {
      return _buildNoSentenceHtml(height);
    }

    final imgUrl = 'https://img.beingfine.cn/${sentence.i}.thumb.jpg';
    final fileBaseName = _getFileBaseName(audio);
    int rowNum = 0;
    if (fileBaseName.isNotEmpty && fileBaseName.length > 5) {
      rowNum = int.tryParse(fileBaseName.substring(fileBaseName.length - 5)) ?? 0;
    }

    final escapedTitle = sentence.b.replaceAll("'", "\\'").replaceAll('"', '\\"');
    final spanHtml = createSpanHtml(sentence.e, rowNum);

    final sentBody = _fmt(_sentStrFormat, [
      fileBaseName,
      imgUrl,
      escapedTitle,
      audio,
      sentenceFontName,
      spanHtml,
      sentence.c,
    ]);

    if (_type == typeNormal) {
      return _fmt(_htmlFormat, [color, color, color, height, sentBody]);
    } else {
      return _fmt(_htmlFormat, [color, color, color, sentBody]);
    }
  }

  /// 提取文件基础名（去掉扩展名）
  static String _getFileBaseName(String path) {
    final lastSlash = path.lastIndexOf('/');
    final lastDot = path.lastIndexOf('.');
    if (lastDot > lastSlash) {
      return path.substring(lastSlash + 1, lastDot);
    }
    return path.substring(lastSlash + 1);
  }

  // ---------------------------------------------------------------------------
  // createSpanHtml — 单词级 span 包裹（核心算法，翻译自原版）
  // ---------------------------------------------------------------------------

  /// 将英文句子转换为带 span 标签的 HTML，每个单词有唯一 ID
  /// [sentence] 英文句子, [rowNum] 行号（用于生成 span ID）
  static String createSpanHtml(String sentence, int rowNum) {
    if (StrUtils.isEmpty(sentence)) return '';

    // 预处理：保护特殊缩写中的句点
    var text = sentence
        .replaceAll('Mr.', 'Mr__ ')
        .replaceAll('Mrs.', 'Mrs__ ')
        .replaceAll('Ms.', 'Ms__ ')
        .replaceAll('Dr.', 'Dr__ ')
        .replaceAllMapped(RegExp(r"[^a-zA-Z0-9](o'clock)"), (m) => ' o__clock')
        .replaceAllMapped(RegExp(r"[^a-zA-Z0-9](O'CLOCK)"), (m) => ' O__CLOCK')
        .replaceAllMapped(RegExp(r"[^a-zA-Z0-9](O'Clock)"), (m) => ' O__Clock')
        .replaceAllMapped(RegExp(r"[^a-zA-Z0-9](O'clock)"), (m) => ' O__clock')
        .replaceAll("ma'am", 'ma__am')
        .replaceAll("Ma'am", 'Ma__am')
        .replaceAll("MA'AM", 'MA__AM')
        .replaceAll('<b>', '___b1___')
        .replaceAll('</b>', '___b2___');

    // 处理连续大写字母间的句点（如 U.S.A.）
    while (true) {
      final next = text.replaceAllMapped(RegExp(r'([\w][A-Z]\.)([A-Z])'), (m) {
        return '${m.group(1)} ${m.group(2)}';
      });
      if (next == text) break;
      text = next;
    }

    // 处理大写字母缩写中的句点（如 U.S. → U___S）
    while (true) {
      final next = text.replaceAllMapped(RegExp(r'([A-Z])\.([A-Z])'), (m) {
        return '${m.group(1)}___${m.group(2)}';
      });
      if (next == text) break;
      text = next;
    }

    // 处理小数点（如 3.14 → 3___14）
    while (true) {
      final next = text.replaceAllMapped(RegExp(r'([0-9]*)\.([0-9])'), (m) {
        return '${m.group(1)}___${m.group(2)}';
      });
      if (next == text) break;
      text = next;
    }

    // 处理 n't 缩写
    while (true) {
      final next = text.replaceAllMapped(RegExp(r"(\w)(n)'(t)\b"), (m) {
        return '${m.group(1)} ${m.group(2)}___${m.group(3)}';
      });
      if (next == text) break;
      text = next;
    }

    // 合并连续空格
    text = text.replaceAll(RegExp(r' +'), ' ');

    // 按单词边界分割
    final parts = text.split(RegExp(r'\b'));
    final sb = StringBuffer();
    var wordIndex = -1;

    for (var i = 0; i < parts.length; i++) {
      var part = parts[i];
      if (part.isEmpty) continue;

      // 检测是否为加粗标记
      var isBold = false;
      if (part.startsWith('___b1___') && part.endsWith('___b2___')) {
        part = part.replaceAll('___b1___', '').replaceAll('___b2___', '');
        isBold = true;
      }

      // 判断是否为单词（以字母数字或下划线结尾）
      if (RegExp(r'[a-zA-Z0-9_]$').hasMatch(part)) {
        wordIndex++;
        // 还原保护的缩写
        part = _restoreAbbreviation(part);
        // 还原句点
        part = part.replaceAll('___', '.');

        final spanId = "'${rowNum.toString().padLeft(5, "0")}${wordIndex.toString().padLeft(3, "0")}01'";

        // 处理缩写后的撇号（'re, 'll, 've, 'm, 's, 'd）
        if (i > 0 && RegExp(r"^(re|ll|ve|m|s|d)$", caseSensitive: false).hasMatch(part) && parts[i - 1] == "'") {
          part = "'$part";
        }

        if (isBold) {
          sb.write("<span class='b' id=$spanId>$part</span>");
        } else {
          sb.write('<span id=$spanId>$part</span>');
        }
      } else if (part == ' ') {
        // 空格：检查后面是否跟着 n't
        if (i >= parts.length - 1 || parts[i + 1].toLowerCase() != 'n___t') {
          sb.write(part);
        }
      } else if (part == "'" && i < parts.length - 1) {
        // 撇号：检查后面是否跟着缩写
        final nextPart = parts[i + 1];
        if (!RegExp(r'^(re|ll|ve|m|s|d)$', caseSensitive: false).hasMatch(nextPart)) {
          sb.write(part);
        }
      } else {
        sb.write(part);
      }
    }

    return sb.toString();
  }

  /// 还原保护的缩写词
  static String _restoreAbbreviation(String part) {
    const map = {
      'Mr__': 'Mr.',
      'Mrs__': 'Mrs.',
      'Ms__': 'Ms.',
      'Dr__': 'Dr.',
      'ma__am': "ma'am",
      'Ma__am': "Ma'am",
      'MA__AM': "MA'AM",
      'o__clock': "o'clock",
      'O__clock': "O'clock",
      'O__Clock': "O'Clock",
      'O__CLOCK': "O'CLOCK",
      'n___t': "n't",
      'N___T': "N'T",
    };
    return map[part] ?? part;
  }

  // ---------------------------------------------------------------------------
  // 封装工具方法
  // ---------------------------------------------------------------------------

  /// 将 ___b1___ / ___b2___ 转为 <b> / </b>（原版 encapsulateHightLightSentence）
  static String encapsulateHighlightSentence(String str) {
    if (StrUtils.isEmpty(str)) return str;
    return str.replaceAll('___b1___', '<b>').replaceAll('___b2___', '</b>');
  }

  /// 带原生高亮的句子封装（原版 encapsulateNativeHightLightSentence）
  /// 返回 <myspan> 包裹的 HTML，高亮部分用 <highlight> 标记
  static String encapsulateNativeHighlightSentence(String str, int wordPos) {
    if (StrUtils.isEmpty(str)) return str;

    final trimmed = str.trim();
    var startTag = '___b1___';
    var endTag = '___b2___';
    if (!trimmed.contains('__b1___')) {
      startTag = '<b>';
      endTag = '</b>';
    }

    // 收集高亮区间
    final highlightRanges = <_HighlightRange>[];
    var searchStart = 0;
    var lengthOffset = 0;
    while (true) {
      final si = trimmed.indexOf(startTag, searchStart);
      if (si < 0) break;
      final ei = trimmed.indexOf(endTag, si);
      if (ei <= si) break;
      highlightRanges.add(_HighlightRange(si - lengthOffset, ei - lengthOffset - startTag.length));
      lengthOffset += startTag.length + endTag.length;
      searchStart = ei;
    }

    // 分词并标记
    final tokens = WordTokenizer.tokenize(encapsulateHighlightSentence(trimmed), keepNonAlpha: true);
    final sb = StringBuffer('<myspan></myspan>');
    var rangeIdx = 0;
    var charOffset = 0;
    var wordCount = 0;

    for (final token in tokens) {
      if (WordTokenizer.isValidSpanValue(token)) {
        final spanId = "'${wordPos.toString().padLeft(5, "0")}${wordCount.toString().padLeft(3, "0")}01'";

        if (rangeIdx < highlightRanges.length) {
          final range = highlightRanges[rangeIdx];
          if (range.start >= charOffset && range.end <= token.length + charOffset) {
            // 此单词包含高亮
            final localStart = range.start - charOffset;
            final localEnd = range.end - charOffset;
            String highlighted;
            if (localStart == 0 && localEnd >= token.length) {
              highlighted = '<highlight>$token</highlight>';
            } else if (localStart == 0) {
              highlighted =
                  '<highlight>${token.substring(0, localEnd)}</highlight>'
                  '${token.substring(localEnd)}';
            } else if (localEnd >= token.length) {
              highlighted =
                  '${token.substring(0, localStart)}'
                  '<highlight>${token.substring(localStart)}</highlight>';
            } else {
              highlighted =
                  '${token.substring(0, localStart)}'
                  '<highlight>${token.substring(localStart, localEnd)}</highlight>'
                  '${token.substring(localEnd)}';
            }
            sb.write('<myspan id=$spanId>$highlighted</myspan>');
            rangeIdx++;
            wordCount++;
            charOffset += token.length;
            continue;
          }
        }
        sb.write('<myspan id=$spanId>$token</myspan>');
        wordCount++;
      } else {
        sb.write(token);
      }
      charOffset += token.length;
    }

    return sb.toString();
  }

  /// 带 span 包裹的句子（原版 encapsulateSentenceWithSpan）
  static String encapsulateSentenceWithSpan(String str) {
    if (StrUtils.isEmpty(str)) return str;

    var startTag = '___b1___';
    var endTag = '___b2___';
    if (!str.contains('__b1___')) {
      startTag = '<b>';
      endTag = '</b>';
    }

    // 收集高亮单词集合
    final highlightWords = <String>{};
    var searchStart = 0;
    while (true) {
      final si = str.indexOf(startTag, searchStart);
      if (si < 0) break;
      final ei = str.indexOf(endTag, si);
      if (ei <= si) break;
      highlightWords.add(str.substring(si + startTag.length, ei));
      searchStart = ei;
    }

    final tokens = WordTokenizer.tokenize(encapsulateHighlightSentence(str), keepNonAlpha: true);
    final sb = StringBuffer('<span></span>');

    for (final token in tokens) {
      if (WordTokenizer.isValidSpanValue(token)) {
        if (highlightWords.contains(token)) {
          sb.write("<span class='b'>$token</span>");
        } else {
          sb.write('<span>$token</span>');
        }
      } else {
        sb.write(token);
      }
    }

    return sb.toString();
  }

  // ---------------------------------------------------------------------------
  // JSON / HTML 解析（原版 changedHtml2Elements / covertJson2SentenceData / changedSentenceData）
  // ---------------------------------------------------------------------------

  /// 将 HTML 字符串解析为 <h4> 元素列表（原版 changedHtml2Elements）
  /// 返回 [h4Element, contentElement, h4Element, contentElement, ...] 交替排列
  static List<String> parseHtmlToElements(String html) {
    if (html.isEmpty) return [];
    // 简单解析 <h4> 标签（原版用 Jsoup，这里用正则简化）
    final sanitized = html.replaceAll('<b>', '___b1___').replaceAll('</b>', '___b2___');
    final regex = RegExp(r'<h4[^>]*>(.*?)</h4>', dotAll: true);
    final matches = regex.allMatches(sanitized).toList();
    return matches.map((m) => m.group(0) ?? '').toList();
  }

  /// 从 JSON 解析例句数据（原版 covertJson2SentenceData）
  static List<AcceptationSentence> parseJsonToSentenceData(dynamic jsonData) {
    final result = <AcceptationSentence>[];
    if (jsonData == null) return result;

    try {
      final map = jsonData is String ? jsonDecode(jsonData) : jsonData;
      if (map is Map<String, dynamic> && map['v'] != null && map['v'] == 1 && map['data'] != null) {
        final data = map['data'] as List;
        for (final item in data) {
          final sentence = NormalAcceptationSentence.fromJson(item as Map<String, dynamic>);
          result.add(sentence);
        }
      }
    } catch (_) {
      // 解析失败返回空
    }
    return result;
  }

  /// 解析例句数据（兼容 HTML 和 JSON 格式，原版 changedSentenceData）
  static List<AcceptationSentence> parseSentenceData(String? rawData, List<Interpret>? interprets) {
    final result = <AcceptationSentence>[];
    if (rawData == null || rawData.isEmpty) {
      result.add(OldAcceptationSentence.create(interprets, []));
      return result;
    }

    // HTML 格式（旧版 <h4> 标签）
    if (rawData.trim().startsWith('<h4')) {
      final elements = parseHtmlToElements(rawData);
      final sentences = <SentenceData>[];
      for (var i = 0; i < elements.length ~/ 2; i++) {
        final h4 = elements[i * 2];
        final content = elements[i * 2 + 1];
        final sentence = SentenceData();
        // 从 h4 标签提取属性
        sentence.sid = _extractAttr(h4, 'sentid');
        sentence.u = _extractAttr(h4, 'url');
        sentence.b = _extractAttr(h4, 'book');
        sentence.i = _extractAttr(h4, 'img');
        sentence.e = _extractText(h4);
        if (sentence.sid.length > 5) {
          sentence.eid = sentence.sid.substring(0, sentence.sid.length - 5);
        }
        sentence.c = _extractText(content);
        sentences.add(sentence);
      }
      result.add(OldAcceptationSentence.create(interprets, sentences));
      return result;
    }

    // JSON 格式
    try {
      final parsed = parseJsonToSentenceData(rawData);
      result.addAll(parsed);
      for (final item in result) {
        if (item.type == AcceptationSentence.typeOld && item is OldAcceptationSentence) {
          item.interprets = interprets;
        }
      }
      if (result.isEmpty) {
        result.add(OldAcceptationSentence.create(interprets, []));
      }
    } catch (_) {
      result.add(OldAcceptationSentence.create(interprets, []));
    }
    return result;
  }

  /// 获取第一条例句数据（原版 getFirstSentenceData）
  static SentenceData? getFirstSentenceData(String? rawData) {
    if (rawData == null || rawData.isEmpty) return null;

    if (rawData.trim().startsWith('<h4')) {
      final elements = parseHtmlToElements(rawData);
      if (elements.length < 2) return null;
      final h4 = elements[0];
      final content = elements[1];
      final sentence = SentenceData();
      sentence.sid = _extractAttr(h4, 'sentid');
      sentence.u = _extractAttr(h4, 'url');
      sentence.b = _extractAttr(h4, 'book');
      sentence.i = _extractAttr(h4, 'img');
      sentence.e = _extractText(h4);
      if (sentence.sid.length > 5) {
        sentence.eid = sentence.sid.substring(0, sentence.sid.length - 5);
      }
      sentence.c = _extractText(content);
      return sentence;
    }

    try {
      final list = parseJsonToSentenceData(rawData);
      for (final item in list) {
        final allSent = item.getAllSentence();
        if (allSent.isNotEmpty) return allSent.first;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// 从例句数据中获取第一个释义（原版 getFirstInterpretFromExample）
  static Interpret? getFirstInterpretFromExample(String example, String interpret) {
    try {
      final list = parseJsonToSentenceData(example);
      if (list.isNotEmpty) {
        final sentence = list.first;
        final interp = sentence.getInterpret();
        if (interp is Acceptation) {
          return Interpret(
            p: interp.wordProperty,
            i: interp.chInterpret,
            ei: interp.enInterpret,
            bCi: sentence.type == AcceptationSentence.typeOld,
          );
        }
        List<Interpret>? interprets;
        if (interp is List<Interpret>) {
          interprets = interp;
        }
        interprets ??= _parseInterpretList(interpret);
        if (interprets != null && interprets.isNotEmpty) {
          return interprets.first;
        }
      }
    } catch (_) {
      // fall through
    }
    final fallback = _parseInterpretList(interpret);
    return (fallback != null && fallback.isNotEmpty) ? fallback.first : null;
  }

  /// 解析释义字符串为 Interpret 列表
  static List<Interpret>? _parseInterpretList(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.map((e) => Interpret.fromJson(e as Map<String, dynamic>)).toList();
      }
    } catch (_) {
      // 不是 JSON，按纯文本处理
    }
    return null;
  }

  // HTML 属性提取辅助
  static String _extractAttr(String tag, String attr) {
    final regex = RegExp('$attr=["\']([^"\']*)["\']');
    final match = regex.firstMatch(tag);
    return match?.group(1) ?? '';
  }

  static String _extractText(String html) {
    return html.replaceAll(RegExp(r'<[^>]*>'), '').replaceAll('___b1___', '<b>').replaceAll('___b2___', '</b>').trim();
  }
}

/// 高亮区间
class _HighlightRange {
  final int start;
  final int end;
  _HighlightRange(this.start, this.end);
}

/// 简单模板格式化（替换 %s 占位符）
String _fmt(String template, List<dynamic> args) {
  var result = template;
  for (final arg in args) {
    result = result.replaceFirst('%s', arg.toString());
  }
  return result;
}
