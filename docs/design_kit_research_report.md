# 设计套件调研报告

**日期**: 2026-08-25  
**项目**: Monster Word 背单词 App  
**调研套件**: 5 个 Penpot 设计套件

---

## 一、调研对象

| 套件 | 大小 | 格式 | 核心内容 |
|------|------|------|---------|
| Calendar Interactive UI Kit | ~2MB | ZIP (Penpot) | 日历组件（4种日历 + 4种日期单元格） |
| Ant Design System for Figma | ~15MB | ZIP (Penpot) | 完整企业级设计系统 |
| Type Scale Playground | ~500KB | ZIP (Penpot) | 字体层级系统 |
| tailwind-kit | ~3MB | 非标准 | Tailwind 风格组件 |
| @shadcn/ui Design System | ~8MB | ZIP (Penpot) | 现代无头组件库 |

---

## 二、Calendar Interactive UI Kit — 核心发现（⭐⭐⭐⭐⭐ 强烈推荐）

### 2.1 组件结构

```
Calendar UI Kit
├── Calendar (4 变体)
│   ├── Light + Double  ← 双月视图，浅色主题
│   ├── Light + Single  ← 单月视图，浅色主题
│   ├── Dark + Double   ← 双月视图，深色主题
│   └── Dark + Single   ← 单月视图，深色主题
├── Date (4 变体)
│   ├── Light / Dark    ← 主题变体
│   ├── Single / Double ← 尺寸变体
└── 配色系统
    ├── Blue 1: #2f80ed  (主色)
    ├── Brand: #072f54  (品牌深蓝)
    ├── Yellow: #f2c94c (强调/连击)
    └── Gray 1-6: 中性色阶
```

### 2.2 最值得借鉴的设计模式

| 设计模式 | 当前 app 可借鉴点 | 优先级 |
|---------|------------------|--------|
| **双月视图** | 签到历史页可同时展示两个月，一目了然 | ⭐⭐⭐⭐⭐ |
| **日期单元格状态系统** | 已签到/未签到/今日/选中/连续/禁用 — 清晰的状态视觉 | ⭐⭐⭐⭐⭐ |
| **月份切换交互** | 左右箭头 + 弹性动画 → 与现有 spring_calendar 完美融合 | ⭐⭐⭐⭐ |
| **连击徽章** | 🔥 连击 N 天的徽章设计 → 已在 app 中实现，可强化 | ⭐⭐⭐⭐ |
| **深色/浅色主题** | 自动适配 app 现有 skin_system | ⭐⭐⭐⭐ |
| **入场动画** | 弹性入场 + 单元格错落动画 | ⭐⭐⭐ |

### 2.3 配色方案可借鉴

Calendar UI Kit 使用 `#2f80ed` 作为主色，`#072f54` 作为品牌深色。  
我们的 app 使用星巴克绿 `#006241` 作为主色，**语义完全匹配**：

| Calendar UI Kit | Monster Word | 用途 |
|-----------------|--------------|------|
| Blue #2f80ed | #006241 (primary) | 主操作/选中 |
| Brand #072f54 | #1E3932 (deep) | 深色文字/背景 |
| Yellow #f2c94c | #cba258 (gold) | 连击/成就高亮 |
| Gray 5 #e0e0e0 | divider | 边框/分隔线 |

---

## 三、Ant Design System — 企业级参考（⭐⭐⭐⭐）

### 3.1 可借鉴组件

| 组件 | 我们的用途 | 借鉴点 |
|------|-----------|--------|
| **Calendar** | 签到历史页 | 更完整的日历 API（选择范围、禁用日期） |
| **DatePicker** | 学习统计筛选 | 日期范围选择器 |
| **Statistic** | 学习数据展示 | 数字 + 趋势箭头 + 单位 |
| **Timeline** | 学习时间线 | 纵向时间轴，展示学习记录 |
| **Progress** | 学习进度 | 圆形/线性进度条变体 |
| **Empty** | 空状态页 | 插画 + 操作按钮 |
| **Badge** | 连续天数 | 数字徽章 + 圆点状态 |

### 3.2 设计令牌（Design Tokens）

Ant Design 的令牌系统非常完善：

```
colorPrimary: #1677ff
colorSuccess: #52c41a
colorWarning: #faad14
colorError: #ff4d4f
colorInfo: #1677ff
borderRadius: 6px
shadow: 0 1px 2px rgba(0,0,0,0.03), 0 1px 6px -1px rgba(0,0,0,0.02), 0 2px 4px rgba(0,0,0,0.02)
```

→ 我们可直接将这些令牌映射到现有 `MistralColors` / `AppRadius`。

---

## 四、Type Scale Playground — 字体系统参考（⭐⭐⭐⭐）

### 4.1 字体层级对比

| 层级 | Calendar UI Kit | Ant Design | 我们当前 | 建议 |
|------|----------------|------------|---------|------|
| Display | 36px | 38px | 48*fontScale | 保持 |
| H1 | 28px | 30px | 32px | 统一 |
| H2 | 22px | 24px | 24px | ✅ |
| H3 | 18px | 20px | 20px | ✅ |
| Body | 14px | 14px | 16px | 微调 |
| Caption | 12px | 12px | 12px | ✅ |

→ 我们的字体层级已基本合理，可参考 Ant Design 的微调策略。

---

## 五、@shadcn/ui — 现代组件模式（⭐⭐⭐）

### 5.1 可借鉴模式

| 模式 | 说明 | 我们的用途 |
|------|------|-----------|
| **无头组件** | 逻辑与样式分离 | 日历的状态管理 |
| **变体系统** | `variant: 'default' \| 'destructive' \| 'outline'` | 按钮/卡片变体 |
| **暗色模式** | CSS 变量驱动 | 与 skin_system 融合 |
| **圆角层级** | sm(4) md(8) lg(12) xl(16) full(999) | 统一圆角规范 |

---

## 六、tailwind-kit — 工具类参考（⭐⭐）

主要提供 Tailwind CSS 风格的间距、颜色、阴影工具类。  
我们的 Flutter 项目不使用 CSS，但**间距系统**可参考：

```
4px 8px 12px 16px 24px 32px 48px 64px
```

→ 与我们的 `AppSpacing.xs/sm/md/lg/xl/2xl/3xl` 基本一致。

---

## 七、实施建议

### 7.1 Calendar 签到历史页 — 核心实施计划

```
签到历史页面
├── 顶部概览卡片
│   ├── 总天数
│   ├── 连续天数 (🔥 徽章)
│   └── 本月天数 + 进度环
├── 双月日历视图
│   ├── 上月日历（半透明）
│   ├── 当月日历（主视图）
│   └── 月份切换动画
├── 签到详情列表
│   ├── 日期分组
│   ├── 当日学习数
│   └── 成就徽章
└── 空状态引导
```

### 7.2 设计令牌映射

```dart
// Calendar UI Kit → Monster Word 映射
const Map<String, String> calendarColorMapping = {
  '#2f80ed': 'MistralColors.primary',      // 主色
  '#072f54': 'MistralColors.primaryDark',  // 深色
  '#f2c94c': 'MistralColors.accent',       // 连击高亮
  '#828282': 'MistralColors.text3',        // 次要文字
  '#e0e0e0': 'skin.colors.divider',        // 边框
  '#f2f2f2': 'skin.colors.cardBgAlt',      // 背景
};
```

---

## 八、推荐优先级

| 优先级 | 套件 | 用于 | 工作量 |
|--------|------|------|--------|
| P0 | Calendar UI Kit | 签到历史页日历组件 | 2-3 天 |
| P1 | Ant Design | 空状态/统计/时间线 | 1-2 天 |
| P2 | Type Scale | 字体层级微调 | 0.5 天 |
| P3 | shadcn/ui | 组件变体系统重构 | 持续 |
| P4 | tailwind-kit | 间距规范对齐 | 0.5 天 |

---

## 九、结论

**Calendar Interactive UI Kit 是最直接可用的资源**，其双月视图、日期单元格状态系统、连击徽章设计可直接用于签到历史页。

Ant Design 提供了最完整的组件参考，特别是空状态、统计数字、时间线等模式。

建议**优先实施 P0（Calendar 签到历史页）**，然后逐步应用其他套件的设计模式。
