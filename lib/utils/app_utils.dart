// 由账号4生成
// 工具层：翻译自 util/（v3.2 源码 1:1）
// 文件：SecurityUtils（加密）+ StrUtils（字符串）+ DateUtils（日期）+ Tools（工具）

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;

/// 加密工具（翻译自 SecurityUtils.java）
class SecurityUtils {
  /// MD5 hex 字符串（原版 md5String）
  static String md5String(String input) {
    final bytes = utf8.encode(input);
    return crypto.md5.convert(bytes).toString();
  }

  /// MD5 hex 字符串（字节数组版本）
  static String md5Bytes(List<int> bytes) {
    return crypto.md5.convert(bytes).toString();
  }

  /// URL 编码（原版 urlEncode）
  static String urlEncode(String str) {
    return Uri.encodeComponent(str);
  }

  /// URL 解码（原版 urlDecode）
  static String urlDecode(String str) {
    return Uri.decodeComponent(str);
  }
}

/// 字符串工具（翻译自 StrUtils.java）
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
    return SecurityUtils.md5Bytes(bytes);
  }

  /// 是否为空（原版 isEmpty）
  static bool isEmpty(String? str) => str == null || str.isEmpty;

  /// 首字符是否为汉字（原版 isFirstCharHanZi）
  static bool isFirstCharHanZi(String str) {
    if (str.isEmpty) return false;
    final code = str.codeUnitAt(0);
    return code >= 19968 && code < 40869;
  }

  /// 是否为字母数字（原版 isAlphanumericCode）
  static bool isAlphanumericCode(String str) {
    return RegExp(r'^[a-zA-Z0-9]+$').hasMatch(str);
  }

  /// 集合用分隔符连接（原版 componentsJoinedByString）
  static String join(Iterable<String> collection, String separator) {
    return collection.join(separator);
  }

  /// 字符串相等（原版 isStringEqual：都空=true，一空=false）
  static bool isStringEqual(String? a, String? b) {
    if (isEmpty(a) && isEmpty(b)) return true;
    if (isEmpty(a) || isEmpty(b)) return false;
    return a == b;
  }
}

/// 日期工具（翻译自 DateUtils.java）
class DateUtils {
  /// yyyyMMdd（原版 shortFormat）
  static String shortFormat(DateTime date) {
    return '${date.year}'
        '${date.month.toString().padLeft(2, '0')}'
        '${date.day.toString().padLeft(2, '0')}';
  }

  /// yyyyMMddHHmmss（原版 format）
  static String format(DateTime date) {
    return '${shortFormat(date)}'
        '${date.hour.toString().padLeft(2, '0')}'
        '${date.minute.toString().padLeft(2, '0')}'
        '${date.second.toString().padLeft(2, '0')}';
  }

  /// yyyy年MM月dd日（原版 NYRFormat）
  static String nyrFormat(DateTime date) {
    return '${date.year}年${date.month}月${date.day}日';
  }

  /// yyyy-MM-dd HH:mm:ss（原版 SQLiteFormat）
  static String sqliteFormat(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}:'
        '${date.second.toString().padLeft(2, '0')}';
  }

  /// 当前时间 yyyyMMddHHmmss（原版 currentTimeStr）
  static String currentTimeStr() => format(DateTime.now());

  /// 今天 yyyyMMdd（原版 todayStr）
  static String todayStr() => shortFormat(DateTime.now());

  /// 未来 N 天 yyyyMMdd（原版 todayAfterStr）
  static String todayAfterStr(int days) {
    return shortFormat(DateTime.now().add(Duration(days: days)));
  }

  /// 只保留数字（原版 timeStrOnlyNumerals）
  static String timeStrOnlyNumerals(String str) {
    return str.replaceAll(RegExp(r'[^\d]'), '');
  }

  /// 从日期字符串解析（原版 dateFromDateStr，补齐位数）
  static DateTime dateFromDateStr(String str) {
    var s = timeStrOnlyNumerals(str);
    if (s.length <= 8) {
      while (s.length < 8) {
        s += '0';
      }
      return DateTime.parse(
          '${s.substring(0, 4)}-${s.substring(4, 6)}-${s.substring(6, 8)}');
    }
    while (s.length < 14) {
      s += '0';
    }
    return DateTime.parse(
        '${s.substring(0, 4)}-${s.substring(4, 6)}-${s.substring(6, 8)} '
        '${s.substring(8, 10)}:${s.substring(10, 12)}:${s.substring(12, 14)}');
  }
}

/// 通用工具（翻译自 Tools.java 核心方法）
class Tools {
  static final Random _random = Random();

  /// 随机范围（原版 randomWithRange，含两端）
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
}

/// Base64 编解码（翻译自 Base64.java 相关）
class CodeDeal {
  static String encode(List<int> bytes) => base64Encode(bytes);
  static Uint8List decode(String str) => base64Decode(str);
}
