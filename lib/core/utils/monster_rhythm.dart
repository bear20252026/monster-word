// MonsterRhythm：怪兽的昼夜节律（W4.5 宠物化「它真的活了」）。
//
// 宠物感的最大缺口不是新系统，是「它有自己的作息」：22:00–06:00 它在小屋
// 睡觉（闭眼 + Zzz + 夜色），点击只会说睡话。窗口与 SfxPlayer 的夜间
// -6dB（h>=22 || h<6）刻意对齐——「夜里它睡了、声音也轻」是同一个节律，
// 不引入第二套时间口径。
//
// 可测性：静态时钟注入缝（nowOverride），测试 pin 到白天/夜晚定点，
// 杜绝「CI 在 22 点后跑就假红」的时间依赖。
class MonsterRhythm {
  MonsterRhythm._();

  /// 入睡时刻（含）。
  static const int sleepStartHour = 22;

  /// 醒来时刻（不含）。
  static const int wakeHour = 6;

  static const String windowLabel = '22:00 ~ 6:00';

  static DateTime Function()? _nowOverride;

  /// 节律时钟（默认真实墙钟）。
  static DateTime now() => _nowOverride?.call() ?? DateTime.now();

  /// 注入缝（测试 pin 到白天/夜晚定点；生产禁用）。
  static set nowOverride(DateTime Function()? fn) => _nowOverride = fn;

  /// 测试隔离：清除时钟注入（setUp/tearDown 调用）。
  static void resetForTest() => _nowOverride = null;

  /// 此刻怪兽是否在睡觉。窗口 [22:00, 次日 06:00)。
  static bool isSleepTime([DateTime? at]) {
    final t = at ?? now();
    return t.hour >= sleepStartHour || t.hour < wakeHour;
  }
}
