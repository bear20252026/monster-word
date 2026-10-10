// 日历日运算工具：全部用「年月日分量」构造，绝不用 Duration 绝对时长。
//
// 动机（2026-10-08 审计 DST 族问题）：`a.difference(b).inDays` 与
// `date.add/subtract(Duration(days:1))` 是 24h 绝对时长运算，夏令时切换日
// 只有 23h/25h，会出现「翻页跳两天 / 连击断计 / 回家礼误判」等跳日错。
// 全库曾有 8 处同款手写，统一收口到这里。

/// 日历日前一天（分量构造，DST 安全）；保留[day]的时分秒分量。
DateTime calendarDayBefore(DateTime day) =>
    DateTime(day.year, day.month, day.day - 1, day.hour, day.minute, day.second, day.millisecond, day.microsecond);

/// 日历日后 [days] 天（分量构造，DST 安全；days 可为负）；保留[day]的时分秒分量。
///
/// 时刻分量必须保留：提醒排程等调用方传入的是「今天 20:00」这类时刻，
/// 截断到零点会把「明天 20:00」排成「明天 00:00」（回归测试锚定）。
DateTime calendarDayAdd(DateTime day, int days) => DateTime(
  day.year,
  day.month,
  day.day + days,
  day.hour,
  day.minute,
  day.second,
  day.millisecond,
  day.microsecond,
);

/// 两个时刻之间的日历日差（[to] 晚于 [from] 为正）。
///
/// 先各自截到本地日历日（零点）再取毫秒差四舍五入到天：本地零点到零点的
/// 跨度在 DST 日是 23h/25h，四舍五入（而非截断）在两端时区偏移差 <12h 的
/// 一切现实时区下都得到正确日历日差。例：
/// `calendarDaysBetween(昨天23:59, 今天00:01) == 1`。
int calendarDaysBetween(DateTime from, DateTime to) {
  final a = DateTime(from.year, from.month, from.day);
  final b = DateTime(to.year, to.month, to.day);
  final ms = b.difference(a).inMilliseconds;
  return (ms / Duration.millisecondsPerDay).round();
}
