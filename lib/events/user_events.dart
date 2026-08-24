// 由 Claude 团队生成 | 移植自 v3.2 events/ 用户相关事件
// 用户模块事件：登出、邮箱变更、昵称变更、头像变更、配额变更、数据更新

// ============================================================
// LogoutEvent — 用户登出事件
// 原版：events/LogoutEvent.java（空类，仅作信号）
// 触发源：登录模块 → 监听者：全局（所有页面应清理状态）
// ============================================================
class LogoutEvent {
  const LogoutEvent();
}

// ============================================================
// EmailChangeEvent — 邮箱变更事件
// 原版：events/EmailChangeEvent.java
// 触发源：设置模块 → 监听者：用户模块
// ============================================================
class EmailChangeEvent {
  final String email;
  const EmailChangeEvent({required this.email});
}

// ============================================================
// NicknameChangeEvent — 昵称变更事件
// 原版：events/NicknameChangeEvent.java
// 触发源：用户模块 → 监听者：界面模块
// ============================================================
class NicknameChangeEvent {
  final String newNickname;
  const NicknameChangeEvent({required this.newNickname});
}

// ============================================================
// UserAvatarChangeEvent — 头像变更事件
// 原版：events/UserAvatarChangeEvent.java（空类，仅作信号）
// 触发源：用户模块 → 监听者：界面模块
// ============================================================
class UserAvatarChangeEvent {
  const UserAvatarChangeEvent();
}

// ============================================================
// UserDateUpdateEvnet — 用户数据更新事件
// 原版：events/UserDateUpdateEvnet.java（注意原版拼写错误 Evnet→Event）
// 触发源：统计模块 → 监听者：仪表盘
// ============================================================
class UserDateUpdateEvent {
  const UserDateUpdateEvent();
}

// ============================================================
// UserQuotaNumChangedEvent — 配额数量变更事件
// 原版：events/UserQuotaNumChangedEvent.java
// 触发源：配额模块 → 监听者：界面模块
// ============================================================
class UserQuotaNumChangedEvent {
  final int quotaNum;
  const UserQuotaNumChangedEvent({this.quotaNum = -1});
}
