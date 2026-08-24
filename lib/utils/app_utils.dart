// 由 Claude 团队生成 | Monster Word App

// 翻译自 util/SecurityUtils.java, StrUtils.java, DateUtils.java, Tools.java
// 以及其他轻量工具类
// 核心工具层

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter/services.dart';

/// 字符串工具（翻译自 StrUtils.java，增强版）
class StrUtils {
  /// 密码哈希（原版 getPasswordHash：XOR 混淆后 MD5）
  static String getPasswordHash(String str) {
    final bytes = utf8.encode(str).toList();
    final length = bytes.length;
    final b = (length * 73) & 0xFF;
    for (var i = 0; i < length; i++) {
      bytes[i] = (bytes[i] ^ b) & 0xFF;
      if (bytes[i] == 0) bytes[i] = 1;
    }
    return _md5Bytes(bytes);
  }

  static String _md5Bytes(List<int> bytes) {
    return crypto.md5.convert(bytes).toString();
  }

  /// 是否为空
  static bool isEmpty(String? str) => str == null || str.isEmpty;

  /// 是否全部是字母（原版 isAll26Letters）
  static bool isAll26Letters(String str) {
    return RegExp(r'^[a-zA-Z]+$').hasMatch(str);
  }

  /// 首字符是否为汉字
  static bool isFirstCharHanZi(String str) {
    if (str.isEmpty) return false;
    final code = str.codeUnitAt(0);
    return code >= 19968 && code < 40869;
  }

  /// 是否为字母数字
  static bool isAlphanumericCode(String str) {
    return RegExp(r'^[a-zA-Z0-9]+$').hasMatch(str);
  }

  /// 集合用分隔符连接
  static String join(Iterable<String> collection, String separator) {
    return collection.join(separator);
  }

  /// 字符串相等（都空=true，一空=false）
  static bool isStringEqual(String? a, String? b) {
    if (isEmpty(a) && isEmpty(b)) return true;
    if (isEmpty(a) || isEmpty(b)) return false;
    return a == b;
  }

  /// 是否包含中文字符（原版 isContainChineseCharater）
  static bool isContainChineseCharacter(String str) {
    return !isEmpty(str) && RegExp(r'[一-龥]').hasMatch(str);
  }
}

/// 通用工具（翻译自 Tools.java，增强版）
class Tools {
  static final Random _random = Random();

  /// 随机范围（含两端）
  static int randomWithRange(int min, int max) {
    if (max <= min) return min;
    return min + _random.nextInt(max - min + 1);
  }

  /// 随机打乱
  static List<T> shuffle<T>(List<T> list) {
    final copy = List<T>.from(list);
    copy.shuffle(_random);
    return copy;
  }

  /// 字符串转 int（容错）
  static int stringToInt(String str, int def) {
    return int.tryParse(str) ?? def;
  }

  /// 列表是否为空
  static bool isEmptyList(List? list) => list == null || list.isEmpty;

  /// 在列表中随机取 N 个
  static List<T> randomPick<T>(List<T> list, int n) {
    if (list.isEmpty) return [];
    final shuffled = shuffle(list);
    return shuffled.take(min(n, list.length)).toList();
  }

  /// dp 转 px（需要 MediaQuery）
  static double dp2px(double dp, double devicePixelRatio) {
    return dp * devicePixelRatio;
  }

  /// px 转 dp
  static double px2dp(double px, double devicePixelRatio) {
    return px / devicePixelRatio;
  }

  /// sp 转 px
  static double sp2px(double sp, double textScaleFactor, double devicePixelRatio) {
    return sp * textScaleFactor * devicePixelRatio;
  }

  /// 复制文本到剪贴板
  static Future<void> copyText2Clipboard(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
  }

  /// 正则查找位置
  static int indexOf(String str, String pattern) {
    final match = RegExp(pattern).firstMatch(str);
    if (match != null) {
      return match.end;
    }
    return -1;
  }

  /// 颜色改变 alpha
  static int changeColor(int color, double alpha) {
    return (color & 0x00FFFFFF) | (((alpha * 255).toInt() & 0xFF) << 24);
  }

  /// 获取图片 URL（带尺寸，翻译自 getImageUrlWithSize）
  static String getImageUrlWithSize(String path, int width, int height) {
    final url = 'http://img.beingfine.cn/$path';
    final process = 'x-oss-process=image/resize,m_mfit,w_$width,h_$height,limit_1';
    return url.contains('?') ? '$url&$process' : '$url?$process';
  }

  /// 获取图片 URL（带宽度）
  static String getImageUrlWithWidth(String path, int width) {
    final url = 'http://img.beingfine.cn/$path';
    final process = 'x-oss-process=image/resize,w_$width,limit_1';
    return url.contains('?') ? '$url&$process' : '$url?$process';
  }

  /// 高亮文本转换（翻译自 convertHighlightTextWithHighLightColor）
  static String convertHighlightText(String html, String highlightColor) {
    return html
        .replaceAll('<b>', '<font color=#$highlightColor>')
        .replaceAll('</b>', '</font>');
  }

  /// 是否是短语（包含空格）
  static bool isPhraseWord(String str) {
    if (str.isEmpty) return false;
    return str.trim().contains(' ');
  }
}

/// 发音工具（翻译自 PronounceUtils.dart）
class PronounceUtils {
  static const int PRON_US = 1;
  static const int PRON_UK = 2;

  static String getChineseName(int type) => type == PRON_UK ? '英' : '美';
  static String getEnglishName(int type) => type == PRON_UK ? 'UK' : 'US';
}

/// Base64 编解码（兼容旧接口）
class CodeDeal {
  static String encode(List<int> bytes) => base64Encode(bytes);
  static Uint8List decode(String str) => base64Decode(str);
}
