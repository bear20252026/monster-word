// 由 Claude 团队生成 | 移植自 v3.2 events/ 授权/绑定相关事件
// 授权模块事件：柯林斯授权、词根授权、装备授权、平台绑定、音标变更

// ============================================================
// GetCollinsGrantedEvent — 柯林斯词典授权事件
// 原版：events/GetCollinsGrantedEvent.java（空类，仅作信号）
// 触发源：付费模块 → 监听者：柯林斯视图
// ============================================================
class GetCollinsGrantedEvent {
  const GetCollinsGrantedEvent();
}

// ============================================================
// GetWordRootGrantedEvent — 词根授权事件
// 原版：events/GetWordRootGrantedEvent.java（空类，仅作信号）
// 触发源：付费模块 → 监听者：词根视图
// ============================================================
class GetWordRootGrantedEvent {
  const GetWordRootGrantedEvent();
}

// ============================================================
// EquipProductGrantInfoChangedEvent — 装备授权变更事件
// 原版：events/EquipProductGrantInfoChangedEvent.java（空类，仅作信号）
// 触发源：装备模块 → 监听者：装备界面
// ============================================================
class EquipProductGrantInfoChangedEvent {
  const EquipProductGrantInfoChangedEvent();
}

// ============================================================
// PlatformBindEvent — 平台绑定状态事件
// 原版：events/PlatformBindEvent.java（空类，仅作信号）
// 触发源：社交模块 → 监听者：设置界面
// ============================================================
class PlatformBindEvent {
  const PlatformBindEvent();
}

// ============================================================
// PhoneticTypeChangedEvent — 音标类型变更事件
// 原版：events/PhoneticTypeChangedEvent.java（空类，仅作信号）
// 触发源：设置模块 → 监听者：词典视图
// ============================================================
class PhoneticTypeChangedEvent {
  const PhoneticTypeChangedEvent();
}
