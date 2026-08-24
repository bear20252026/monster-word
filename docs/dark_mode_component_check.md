# 组件深色模式兼容性检查报告

> 任务：【重构127】。检查所有 sb_*.dart 新建组件的深色模式兼容性。
> 检查时间：2026-08-24
> 检查者：PhoneticsEngineer (Monster world)

---

## 1. 检查范围

| # | 文件 | 行数 | 组件 | 用途 |
|---|---|---|---|---|
| 1 | sb_card.dart | 100 | SbCard | 卡片容器 |
| 2 | sb_fab.dart | 147 | SbFab | 悬浮按钮 |
| 3 | sb_button.dart | 211 | SbButton | 胶囊按钮 |
| 4 | sb_banner.dart | 145 | SbBanner | 深绿横幅 |
| 5 | sb_dropdown.dart | 87 | showSbDropdown | 下拉菜单 |
| 6 | sb_badge.dart | 83 | SbBadge | 金色徽章 |
| 7 | sb_progress.dart | 145 | SbLinearProgress / SbRingProgress | 进度指示 |
| 8 | sb_segmented.dart | 117 | SbSegmented | 分段控件 |
| 9 | sb_modal.dart | 214 | SbModal | 模态框 |

---

## 2. 逐组件分析

### 2.1 SbCard（sb_card.dart）

| 颜色引用 | 值 | 用途 | 深色模式风险 |
|---|---|---|---|
| `Colors.white` | #FFFFFF | 默认背景色 | ⚠️ 高：深色画布上白卡突兀 |

**分析：** 背景色可通过 `color` 参数覆盖，调用方可传入 `colors.cardBg`。但默认值 `Colors.white` 在深色模式下会形成强烈对比。阴影色（`0x23000000` / `0x3D000000`）在深色背景上几乎不可见。

**建议：** 默认值改为 `ThemeVars.cardBg`，或在文档中明确要求调用方传入主题色。

### 2.2 SbFab（sb_fab.dart）

| 颜色引用 | 值 | 用途 | 深色模式风险 |
|---|---|---|---|
| `Color(0xFF00754A)` | House Green | 默认填充色 | ✅ 低：品牌绿在深色底上可辨识 |
| `Colors.white` | #FFFFFF | 默认图标色 | ✅ 低：白图标在绿底上对比度充足 |

**分析：** FAB 的绿底白字配色在深色模式下仍然可读。可通过 `fillColor` / `iconColor` 参数覆盖。

**建议：** 无需改动，品牌色在两种主题下均可用。

### 2.3 SbButton（sb_button.dart）

| 颜色引用 | 值 | 用途 | 深色模式风险 |
|---|---|---|---|
| `Color(0xFF00754A)` | House Green | primary/dark 变体描边 | ✅ 低 |
| `Color(0xFF1E3932)` | 墨绿 | dark 变体填充 | ⚠️ 中：深色画布上可能与背景混淆 |
| `Colors.white` | #FFFFFF | primary/dark 文字、inverse 填充 | ⚠️ 中：inverse 变体白底在深色模式下突兀 |
| `Colors.transparent` | — | outlined 填充 | ✅ 无风险 |

**分析：** 四变体中，`dark` 变体的 `#1E3932` 在深色画布 `#101B17` 上对比度较低；`inverse` 变体的白底在深色模式下视觉突兀。`primary` 和 `outlined` 变体表现良好。

**建议：** `dark` 变体在深色模式下考虑提亮至 `#2b5148`；`inverse` 变体在深色模式下应自动切换为深色底+浅色字。

### 2.4 SbBanner（sb_banner.dart）

| 颜色引用 | 值 | 用途 | 深色模式风险 |
|---|---|---|---|
| `Color(0xFF1E3932)` | 墨绿 | 默认背景 | ⚠️ 中：与深色画布 `#101B17` 对比度低 |
| `Colors.white` | #FFFFFF | 标题/副标题文字 | ✅ 低：白字在深绿底上对比度充足 |

**分析：** 横幅的深绿底在深色画布上可能"消失"。可通过 `backgroundColor` 参数覆盖。

**建议：** 深色模式下默认背景提亮至 `#2b5148`，或要求调用方传入主题适配色。

### 2.5 showSbDropdown（sb_dropdown.dart）

| 颜色引用 | 值 | 用途 | 深色模式风险 |
|---|---|---|---|
| `Color(0xFFF9F9F9)` | 浅灰 | 弹出菜单背景 | 🔴 高：深色模式下纯白菜单刺眼 |
| `Color(0x5400754A)` | 绿 33% | 选中项底色 | ✅ 低 |
| `Color(0xFF00754A)` | House Green | 选中项文字 | ✅ 低 |
| `Color(0xDE000000)` | 黑 87% | 未选中项文字 | 🔴 高：深色模式下黑字不可见 |
| `Color(0x8A000000)` | 黑 54% | label 文字 | 🔴 高：深色模式下不可见 |

**分析：** 下拉菜单是深色模式兼容性最差的组件。背景、文字色全部硬编码，深色模式下菜单将完全不可用。

**建议：** 需要接入 ThemeVars，将背景改为 `colors.cardBg`，文字改为 `colors.text1/text2`。

### 2.6 SbBadge（sb_badge.dart）

| 颜色引用 | 值 | 用途 | 深色模式风险 |
|---|---|---|---|
| `Color(0xFFCBA258)` | 品牌金 | 描边/文字/图标 | ✅ 低：金色在深色底上醒目 |
| `Colors.transparent` | — | 背景 | ✅ 无风险 |

**分析：** 金色徽章在深色模式下表现良好，金色本身就是高对比度的强调色。

**建议：** 无需改动。

### 2.7 SbLinearProgress / SbRingProgress（sb_progress.dart）

| 颜色引用 | 值 | 用途 | 深色模式风险 |
|---|---|---|---|
| `Color(0xFF00754A)` | House Green | 进度前景 | ✅ 低 |
| `Color(0xFFEDEBE9)` | ceramic | 细线轨道 | ⚠️ 中：深色画布上轨道过亮 |
| `Color(0xFFE6E6E6)` | 浅灰 | 环形轨道 | ⚠️ 中：同上 |
| `Color(0xDE000000)` | 黑 87% | 环形中心文字 | 🔴 高：深色模式下不可见 |

**分析：** 进度条前景（绿色）在深色模式下可辨识，但轨道背景在深色画布上过亮形成突兀条带。环形进度的中心文字黑字在深色底上不可见。

**建议：** 轨道色需暗化（深色模式下用 `rgba(255,255,255,0.12)` 等）；中心文字改为 `colors.text1`。

### 2.8 SbSegmented（sb_segmented.dart）

| 颜色引用 | 值 | 用途 | 深色模式风险 |
|---|---|---|---|
| `Color(0xFFEDEBE9)` | ceramic | 轨道背景 | ⚠️ 中：深色画布上过亮 |
| `Colors.white` | #FFFFFF | 选中滑块 | ⚠️ 中：白块在深色轨道上突兀 |
| `Color(0xFF00754A)` | House Green | 选中文字 | ✅ 低 |
| `Color(0xDE000000)` | 黑 87% | 未选中文字 | 🔴 高：深色模式下不可见 |

**分析：** 轨道和滑块颜色在深色模式下不协调，未选中文字不可见。

**建议：** 轨道改为深色中性色，滑块改为 `colors.cardBg`，未选中文字改为 `colors.text2`。

### 2.9 SbModal（sb_modal.dart）

| 颜色引用 | 值 | 用途 | 深色模式风险 |
|---|---|---|---|
| `Colors.white` | #FFFFFF | 弹窗背景 | ⚠️ 中：深色模式下白弹窗突兀 |
| `Colors.black.withValues(alpha: 0.55)` | 黑 55% | 遮罩 | ✅ 无风险 |
| `Color(0xDE000000)` | 黑 87% | 标题文字 | 🔴 高：深色模式下不可见 |
| `Color(0x3F000000)` | 黑 25% | 关闭按钮描边 | ⚠️ 中：深色模式下不可见 |
| `Color(0x99000000)` | 黑 60% | 关闭图标 | ⚠️ 中：深色模式下不可见 |

**分析：** 弹窗背景和文字色全部硬编码。标题和关闭按钮在深色模式下不可见。

**建议：** 背景改为 `colors.cardBg`，标题文字改为 `colors.text1`，关闭按钮描边/图标改为 `colors.text3`。

---

## 3. 风险汇总

### 3.1 按严重度分级

| 严重度 | 组件 | 问题 |
|---|---|---|
| 🔴 高 | sb_dropdown | 背景+文字全部硬编码，深色模式完全不可用 |
| 🔴 高 | sb_modal | 标题+关闭按钮深色模式不可见 |
| 🔴 高 | sb_segmented | 未选中文字深色模式不可见 |
| 🔴 高 | sb_progress (Ring) | 中心文字深色模式不可见 |
| ⚠️ 中 | sb_card | 默认白背景在深色模式下突兀 |
| ⚠️ 中 | sb_button (dark) | 墨绿底与深色画布混淆 |
| ⚠️ 中 | sb_banner | 墨绿底与深色画布混淆 |
| ⚠️ 中 | sb_progress (轨道) | 轨道背景过亮 |
| ✅ 低 | sb_fab | 品牌绿白字在两种主题下均可用 |
| ✅ 低 | sb_badge | 金色在深色底上醒目 |

### 3.2 核心问题

**所有 9 个组件均未使用 ThemeVars token，全部采用硬编码颜色值。**

这是一个系统性问题：组件层在 Batch 3 创建时，ThemeVars 体系尚未完全落地，因此组件使用了硬编码的星巴克品牌色常量。这些颜色在亮色主题下表现正确，但在深色主题下会出现对比度不足、元素不可见等问题。

---

## 4. 修复建议

### 4.1 优先级排序

| 优先级 | 组件 | 修复方案 |
|---|---|---|
| P0 | sb_dropdown | 接入 ThemeVars（背景/文字/选中色） |
| P0 | sb_modal | 背景→cardBg，标题→text1，关闭钮→text3 |
| P0 | sb_segmented | 轨道→深中性色，滑块→cardBg，文字→text1/text2 |
| P0 | sb_progress (Ring) | 中心文字→text1 |
| P1 | sb_card | 默认背景→cardBg |
| P1 | sb_button | dark 变体深色模式提亮 |
| P1 | sb_banner | 深色模式背景提亮 |
| P1 | sb_progress (轨道) | 轨道色暗化 |

### 4.2 推荐接入模式

组件不应直接 import skin_system.dart（会增加耦合），推荐两种方案：

**方案 A：BuildContext 扩展（推荐）**
```dart
// 在组件 build 方法中通过 context 读取主题
final colors = Theme.of(context).extension<ThemeVars>()!;
```

**方案 B：参数注入**
```dart
// 调用方传入主题色，组件不感知主题系统
SbCard(color: context.skin.cardBg, ...)
```

当前组件已有 `color`/`fillColor`/`backgroundColor` 等参数覆盖机制，方案 B 改动最小。

---

## 5. 综合结论

| 维度 | 状态 |
|---|---|
| 组件数量 | 9 个 sb_*.dart 文件 |
| 使用 ThemeVars | ❌ 0/9（全部硬编码） |
| 亮色主题兼容 | ✅ 9/9 正常 |
| 深色主题兼容 | 🔴 4 个高风险 + 4 个中风险 + 2 个低风险 |
| 参数覆盖机制 | ✅ 大部分组件支持 color/fillColor 参数 |

**结论：** 所有新建组件在亮色主题下表现正确，但深色模式兼容性存在系统性缺陷——全部使用硬编码颜色而非 ThemeVars。建议 P0 组件优先修复，其余可通过调用方传入主题色临时规避。

---

*检查者：PhoneticsEngineer (Monster world)*
*检查时间：2026-08-24*
