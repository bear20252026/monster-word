// 由 Claude 团队生成 | Monster Word App

// 翻译自 util/DateUtils.java（完整版，包含所有方法）

/// 日期工具（翻译自 DateUtils.java）
class AppDateUtils {
  /// yyyyMMdd
  static String shortFormat(DateTime date) {
    return '${date.year}'
        '${date.month.toString().padLeft(2, '0')}'
        '${date.day.toString().padLeft(2, '0')}';
  }

  /// yyyyMMddHHmmss
  static String format(DateTime date) {
    return '${shortFormat(date)}'
        '${date.hour.toString().padLeft(2, '0')}'
        '${date.minute.toString().padLeft(2, '0')}'
        '${date.second.toString().padLeft(2, '0')}';
  }

  /// yyyyMMddHHmmssSSS
  static String longFormat(DateTime date) {
    return '${format(date)}${date.millisecond.toString().padLeft(3, '0')}';
  }

  /// yyyy年MM月dd日
  static String nyrFormat(DateTime date) {
    return '${date.year}年${date.month}月${date.day}日';
  }

  /// yyyy-MM-dd HH:mm:ss
  static String sqliteFormat(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}:'
        '${date.second.toString().padLeft(2, '0')}';
  }

  /// 当前时间 yyyyMMddHHmmss
  static String currentTimeStr() => format(DateTime.now());

  /// 今天 yyyyMMdd
  static String todayStr() => shortFormat(DateTime.now());

  /// 未来 N 天 yyyyMMdd
  static String todayAfterStr(int days) {
    return shortFormat(DateTime.now().add(Duration(days: days)));
  }

  /// 只保留数字
  static String timeStrOnlyNumerals(String str) {
    return str.replaceAll(RegExp(r'[^\d]'), '');
  }

  /// 未来很远的时间戳（2038-01-01）
  static int futureFaraway() {
    return DateTime(2038, 1, 1).millisecondsSinceEpoch;
  }

  /// 未来 N 天的时间戳
  static int futureTime(int days) {
    return DateTime.now().millisecondsSinceEpoch + (days * 86400000);
  }

  /// 从日期字符串解析
  static DateTime? dateFromDateStr(String str) {
    var s = timeStrOnlyNumerals(str);
    try {
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
    } catch (e) {
      return null;
    }
  }

  /// 日期加 N 天
  static DateTime dateAddDaysAfter(DateTime date, int days) {
    return date.add(Duration(days: days));
  }

  /// 本月第一天
  static DateTime firstDayOfMonth() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, 1);
  }

  /// 本月最后一天
  static DateTime lastDayOfMonth() {
    final now = DateTime.now();
    return DateTime(now.year, now.month + 1, 0);
  }

  /// 今天
  static DateTime today() => DateTime.now();

  /// 昨天
  static DateTime yesterday() => dateAddDaysAfter(DateTime.now(), -1);

  /// 明天
  static DateTime tomorrow() => dateAddDaysAfter(DateTime.now(), 1);

  /// 未来 N 天
  static DateTime futureDays(int days) => dateAddDaysAfter(DateTime.now(), days);

  /// 从日期创建指定时分秒的日期
  static DateTime dateFromDateWith(DateTime date, int hour, int minute, int second) {
    return DateTime(date.year, date.month, date.day, hour, minute, second);
  }

  /// 从字符串创建指定时分秒的日期
  static DateTime? dateFromDateStrWith(String str, int hour, int minute, int second) {
    final date = dateFromDateStr(str);
    if (date == null) return null;
    return dateFromDateWith(date, hour, minute, second);
  }

  /// 中国时区今天 yyyyMMdd
  static String todayChinaTimeStr() {
    final now = DateTime.now().toUtc().add(const Duration(hours: 8));
    return '${now.year}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}';
  }
}
