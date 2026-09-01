/// 学习提醒调度端口（settings/application）。
///
/// 真实现位于 data/local_study_reminder_service.dart（flutter_local_notifications）。
/// 设置页只依赖本端口，测试注入 Fake。
abstract class StudyReminderService {
  /// 请求通知权限（Android 13+ 运行时权限；桌面端视为已授权）。
  /// 返回 false 表示用户拒绝，页面应诚实提示而非继续调度。
  Future<bool> requestPermission();

  /// 安排每日 [hour]:[minute]（24 小时制）的学习提醒。
  /// 幂等：重复调用以最后一次的时间为准。
  Future<void> scheduleDaily({required int hour, required int minute});

  /// 取消已安排的学习提醒。
  Future<void> cancelDaily();
}
