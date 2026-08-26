// 签到模块：签到日历、签到历史、尖叫币
//
// 该模块包含：
// - SpringCheckInCalendar（签到日历组件）
// - CheckInHistoryPage（签到历史页面）
// - ScareCoinHistoryPage（尖叫币历史页面）
// - CheckInService（签到业务逻辑）
//
// 依赖：
// - UserRepository（用户数据）

/// 签到模块配置
class CheckInModule {
  CheckInModule._();

  static void register(dynamic sl) {
    // CheckInService 已在 service_locator.dart 中注册
  }
}
