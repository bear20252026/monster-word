// 由 Claude 团队生成 | Monster Word App

// 翻译自 util/GsonUtils.java, WordTokenizer.java, FileUtils.java
// 数据处理工具

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// JSON 工具（翻译自 GsonUtils.java）
class GsonUtils {
  static String toJson(Object? obj) => jsonEncode(obj);

  static T fromJson<T>(String str) => jsonDecode(str) as T;

  static Map<String, dynamic> toMap(String str) {
    return jsonDecode(str) as Map<String, dynamic>;
  }

  static List<dynamic> toList(String str) {
    return jsonDecode(str) as List<dynamic>;
  }
}

/// 文件工具（翻译自 FileUtils.java）
class FileUtils {
  /// 写入本地文件（从 InputStream 翻译为 bytes）
  static Future<bool> writeLocalFile(Uint8List bytes, String path) async {
    try {
      final file = File(path);
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// 写入文件（字节数组）
  static Future<void> writeFile(String path, Uint8List bytes) async {
    final file = File(path);
    if (!await file.exists()) {
      await file.parent.create(recursive: true);
    }
    await file.writeAsBytes(bytes);
  }

  /// 写入文件（字符串）
  static Future<void> writeString(String path, String content, {String encoding = 'utf-8'}) async {
    final file = File(path);
    if (!await file.exists()) {
      await file.parent.create(recursive: true);
    }
    await file.writeAsString(content);
  }

  /// 获取文件夹大小
  static Future<int> getFolderSize(String path) async {
    final dir = Directory(path);
    if (!await dir.exists()) return 0;
    int size = 0;
    await for (final entity in dir.list(recursive: true)) {
      if (entity is File) {
        size += await entity.length();
      }
    }
    return size;
  }

  /// 删除文件夹内所有文件
  static Future<void> deleteFolder(String path, {bool deleteSelf = false}) async {
    final dir = Directory(path);
    if (!await dir.exists()) return;
    await dir.delete(recursive: true);
    if (!deleteSelf) {
      await dir.create();
    }
  }

  /// 删除文件
  static Future<void> deleteFile(String path) async {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }

  /// 创建目录
  static Future<void> mkdirs(String path) async {
    await Directory(path).create(recursive: true);
  }

  /// 复制文件
  static Future<void> copyFile(String from, String to) async {
    await File(from).copy(to);
  }

  /// 移动文件
  static Future<void> moveFile(String from, String to) async {
    await File(from).rename(to);
  }

  /// 获取文件名
  static String getFileName(String path) {
    final idx = path.lastIndexOf(Platform.pathSeparator);
    return idx == -1 ? path : path.substring(idx + 1);
  }

  /// 获取文件目录
  static String getFileDir(String path) {
    final idx = path.lastIndexOf(Platform.pathSeparator);
    return idx == -1 ? path : path.substring(0, idx + 1);
  }

  /// 获取文件基础名（不含扩展名）
  static String getFileBaseName(String path) {
    var name = getFileName(path);
    final dotIdx = name.lastIndexOf('.');
    return dotIdx == -1 ? name : name.substring(0, dotIdx);
  }

  /// 获取文件扩展名
  static String? getFileExt(String path) {
    var name = getFileName(path);
    final dotIdx = name.lastIndexOf('.');
    return dotIdx == -1 ? null : name.substring(dotIdx + 1);
  }

  /// 是否有指定扩展名
  static bool hasExt(String path, String ext) {
    return path.toLowerCase().endsWith(ext.toLowerCase());
  }

  /// 改变扩展名
  static String changeExt(String path, String newExt) {
    final ext = getFileExt(path);
    if (ext == null) return '$path.$newExt';
    return '${path.substring(0, path.length - ext.length)}$newExt';
  }

  /// 格式化文件大小（翻译自 Tools.getSizeDes）
  static String getSizeDes(int bytes) {
    final mb = bytes / 1048576.0;
    return '${mb.toStringAsFixed(2)}MB';
  }
}

/// 单词分词器（翻译自 WordTokenizer.java）
class WordTokenizer {
  static final _specialQuoteWords = {
    "'cause", "'cos", "'cuz", "'mongst", "'tis", "'twas", "'twill", "'twould",
  };

  static final _splitSymbolChars = '!?,;:"""(){}[]<>#&+=|/…*–—';

  static final _threeHyphenWords = {
    "all-you-can-eat", "babe-in-a-cradle", "bats-in-the-belfry",
    "cat-o'-nine-tails", "catch-as-catch-can", "cock-a-doodle-doo",
    "cock-of-the-rock", "cut-and-come-again", "cut-out-and-keep",
    "dyed-in-the-wool", "first-past-the-post", "flame-of-the-forest",
    "flower-of-an-hour", "fly-on-the-wall", "get-up-and-go",
    "glory-of-the-snow", "hail-fellow-well-met", "high-muck-a-muck",
    "hole-in-the-wall", "jack-by-the-hedge", "jack-in-the-box",
    "jack-in-the-green", "jack-in-the-pulpit", "jack-of-all-trades",
    "knock-down-drag-out", "love-in-a-mist", "middle-of-the-road",
    "mind-your-own-business", "one-of-a-kind", "one-size-fits-all",
    "out-of-the-way", "pay-as-you-go", "pay-as-you-throw",
    "rag-and-bone-man", "rat-a-tat-tat", "ring-around-the-rosy",
    "run-of-the-mill", "snow-on-the-mountain", "spur-of-the-moment",
    "state-of-the-art", "stick-in-the-mud", "stick-to-it-iveness",
    "theatre-in-the-round", "toad-in-the-hole", "top-of-the-range",
    "turn-of-the-century", "up-to-the-minute", "will-o'-the-wisp",
  };

  static bool _isSpecialQuoteWord(String str) => _specialQuoteWords.contains(str);
  static bool _isThreeHyphenWord(String str) => _threeHyphenWords.contains(str);
  static bool _isPureLetterAndDigit(String str) => RegExp(r'^[a-zA-Z0-9]+$').hasMatch(str);

  static bool isValidSpanValue(String str) {
    return RegExp(r'[0-9a-zA-Z]').hasMatch(str);
  }

  /// 分词（翻译自 tokenLi1st）
  static List<String> tokenize(String text, {bool keepNonAlpha = false}) {
    final cleaned = text.replaceAll('<b>', '').replaceAll('</b>', '');
    final tokens = _pTokenList(cleaned);
    if (!keepNonAlpha) {
      tokens.removeWhere((t) => !isValidSpanValue(t));
    }
    return tokens;
  }

  static List<String> _pTokenList(String text) {
    final result = <String>[];
    final tokens = text.split(RegExp(r'\s+'));

    for (var token in tokens) {
      if (token.isEmpty) continue;
      final length = token.length;

      if (_isPureLetterAndDigit(token)) {
        result.add(token);
        result.add(' ');
      } else if (length <= 1) {
        result.add(token);
        result.add(' ');
      } else if (_splitSymbolChars.split('').any((c) => token.contains(c))) {
        if (RegExp(r'^[0-9:.]+$').hasMatch(token) && !token.startsWith(':') && !token.endsWith(':')) {
          if (token.endsWith('.')) {
            result.add(token.substring(0, length - 1));
            result.add('.');
            result.add(' ');
          } else {
            result.add(token);
            result.add(' ');
          }
        } else {
          // Split by symbol chars
          final splitPattern = RegExp('[${RegExp.escape(_splitSymbolChars)}]');
          final parts = token.split(splitPattern);
          for (var part in parts) {
            if (part.isNotEmpty) {
              result.addAll(_pTokenList(part));
            }
          }
          result.add(' ');
        }
      } else {
        // Handle dots
        if (token.endsWith('.')) {
          final match = RegExp(r'(.+?)(\.+)$').firstMatch(token);
          if (match != null) {
            result.addAll(_pTokenList(match.group(1)!));
            result.add(match.group(2)!);
            result.add(' ');
          }
        }

        // Handle leading quotes
        if (token.startsWith("'")) {
          if (_isSpecialQuoteWord(token.toLowerCase())) {
            result.add(token);
            result.add(' ');
          } else {
            result.add("'");
            result.addAll(_pTokenList(token.substring(1)));
            result.add(' ');
          }
        } else if (token.startsWith('-')) {
          result.add('-');
          result.addAll(_pTokenList(token.substring(1)));
          result.add(' ');
        } else if (token.endsWith("'")) {
          result.addAll(_pTokenList(token.substring(0, length - 1)));
          result.add("'");
          result.add(' ');
        } else if (token.endsWith('-')) {
          result.addAll(_pTokenList(token.substring(0, length - 1)));
          result.add('-');
          result.add(' ');
        } else {
          // Handle double dots
          if (token.contains('..')) {
            final match = RegExp(r'(.+[.]{2,})(.+)').firstMatch(token);
            if (match != null) {
              result.addAll(_pTokenList(match.group(1)!));
              result.addAll(_pTokenList(match.group(2)!));
              result.add(' ');
            }
          }

          // Handle multi-hyphen words
          if (token.contains('-') && _countMatches(token, '-') >= 3) {
            if (_isThreeHyphenWord(token.toLowerCase())) {
              result.add(token);
              result.add(' ');
            } else {
              final parts = token.split('-');
              for (var i = 0; i < parts.length; i++) {
                result.add(parts[i]);
                if (i < parts.length - 1) result.add('-');
              }
              result.add(' ');
            }
          } else {
            result.add(token);
            result.add(' ');
          }
        }
      }
    }

    if (result.isNotEmpty && result.last == ' ') {
      result.removeLast();
    }
    return result;
  }

  static int _countMatches(String str, String sub) {
    if (str.isEmpty || sub.isEmpty) return 0;
    int count = 0;
    int idx = 0;
    while ((idx = str.indexOf(sub, idx)) != -1) {
      count++;
      idx += sub.length;
    }
    return count;
  }
}
