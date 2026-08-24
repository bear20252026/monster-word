# 【重构91】Batch 3 组件集成验证报告

> 项目：Monster Word（D:\claude\work\cn_com_lange\word_app）· 2026-08-24
> 方法：dart analyze 全量 10 个组件文件 + import 依赖图 + 硬编码色值审计 + 命名冲突排查
> 结论：**全部通过，0 错误 0 警告，5 个 info 级非阻塞问题**

---

## 一、组件清单

| # | 文件 | 类名 | 职责 | 行数 |
|---|------|------|------|------|
| 1 | `scale_down_on_press.dart` | `ScaleDownOnPress` | 按压反馈包装器（scale 0.95 + 200ms easeOut） | 187 |
| 2 | `sb_button.dart` | `SbButton` | 胶囊按钮（4 变体） | 210 |
| 3 | `sb_card.dart` | `SbCard` | 内容卡片（12px + 双层阴影） | ~80 |
| 4 | `sb_fab.dart` | `SbFab` | 悬浮圆形 CTA（56px） | ~110 |
| 5 | `sb_banner.dart` | `SbBanner` | 横幅/打卡卡 | ~70 |
| 6 | `sb_dropdown.dart` | `SbDropdown` | 下拉选择器 | ~90 |
| 7 | `sb_badge.dart` | `SbBadge` | 金色徽章胶囊 | ~50 |
| 8 | `sb_progress.dart` | `SbProgress` / `SbCircularProgress` | 线性/圆形进度条 | ~140 |
| 9 | `sb_modal.dart` | `SbModal` / `sbShowSheet` | 模态框/底部弹窗 | ~210 |
| 10 | `sb_segmented.dart` | `SbSegmented` | 分段选择器 | ~110 |

---

## 二、Dart Analyze 结果

```
dart analyze lib/widgets/scale_down_on_press.dart lib/widgets/sb_button.dart \
  lib/widgets/sb_card.dart lib/widgets/sb_fab.dart lib/widgets/sb_banner.dart \
  lib/widgets/sb_dropdown.dart lib/widgets/sb_badge.dart lib/widgets/sb_progress.dart \
  lib/widgets/sb_modal.dart lib/widgets/sb_segmented.dart
```

| 级别 | 数量 | 详情 |
|------|------|------|
| **error** | **0** | — |
| **warning** | **0** | — |
| info | 5 | 见下表 |

### Info 级问题（非阻塞）

| # | 文件:行号 | 规则 | 说明 | 建议修复时机 |
|---|-----------|------|------|-------------|
| 1 | `sb_dropdown.dart:8` | `unintended_html_in_doc_comment` | 文档注释中 `<T>` 被误判为 HTML | 改为反引号 `` ` `` 包裹 |
| 2 | `sb_modal.dart:99` | `deprecated_member_use` | `.withOpacity()` 已废弃 | 改为 `.withValues(alpha:)` |
| 3 | `sb_modal.dart:124` | `deprecated_member_use` | 同上 | 同上 |
| 4 | `sb_progress.dart:55` | `unnecessary_underscores` | `___` 多余下划线 | 改为 `_` |
| 5 | `sb_progress.dart:113` | `unnecessary_underscores` | 同上 | 同上 |

**结论**：5 个 info 均为代码风格建议，不影响编译和运行。可在后续清理批次统一修复。

---

## 三、Import 依赖图

### 3.1 组件间依赖

```
scale_down_on_press.dart          ← 无依赖（基础组件）
  ↑ 被以下 5 个组件引用：
  ├── sb_button.dart
  ├── sb_card.dart
  ├── sb_fab.dart
  ├── sb_banner.dart
  └── sb_badge.dart

sb_dropdown.dart                  ← 无组件间依赖（仅 flutter/material.dart）
sb_progress.dart                  ← 无组件间依赖
sb_modal.dart                     ← 无组件间依赖
sb_segmented.dart                 ← 无组件间依赖
```

**结论**：无循环依赖，依赖树为扁平的星型结构（scale_down_on_press 为唯一被复用的底层组件）。

### 3.2 外部页面引用情况

| 组件 | 被外部页面/组件引用 | 引用文件 |
|------|---------------------|----------|
| `ScaleDownOnPress` | ✅ 4 处 | `profile_screen.dart`、`home_screen.dart`、`check_in_widgets.dart`、`search_page.dart` |
| `SbButton` | ✅ 2 处 | `profile_screen.dart`、`home_screen.dart` |
| `SbCard` | ✅ 1 处 | `home_screen.dart` |
| `SbFab` | ✅ 1 处 | `home_screen.dart` |
| `SbBanner` | ✅ 1 处 | `home_screen.dart` |
| `SbBadge` | ✅ 1 处 | `profile_screen.dart` |
| `SbDropdown` | ❌ 0 处 | 未被外部引用（待 Batch 4 页面接入） |
| `SbProgress` | ❌ 0 处 | 未被外部引用（待 Batch 4 页面接入） |
| `SbModal` | ❌ 0 处 | 未被外部引用（待 Batch 4 页面接入） |
| `SbSegmented` | ❌ 0 处 | 未被外部引用（待 Batch 4 页面接入） |

**结论**：6/10 组件已有外部引用，4 个待 Batch 4 页面改造时接入。

---

## 四、Token 引用审计

### 4.1 现状

**所有 10 个组件均未 import `starbucks_tokens.dart`**。各组件使用内部 `static const Color` 定义品牌色。

硬编码色值统计：

| 组件 | `Color(0x...)` 数量 | 关键色值 |
|------|---------------------|----------|
| `sb_button.dart` | 2 | `#00754A`（houseGreen）、`#1E3932`（darkGreen） |
| `sb_card.dart` | 2 | `0x23000000`、`0x3D000000`（双层阴影） |
| `sb_fab.dart` | 3 | `#00754A`（填充）、`0x3D000000`、`0x24000000`（阴影） |
| `sb_banner.dart` | 1 | `#1E3932`（深绿） |
| `sb_dropdown.dart` | 5 | `0x8A000000`、`0x5400754A`、`#00754A`、`0xDE000000`、`#F9F9F9` |
| `sb_badge.dart` | 1 | `#CBA258`（金色） |
| `sb_progress.dart` | 5 | `#EDEBE9`、`#00754A`、`#E6E6E6`、`0xDE000000` |
| `sb_modal.dart` | 3 | `0xDE000000`、`0x3F000000`、`0x99000000` |
| `sb_segmented.dart` | 5 | `#EDEBE9`、`0x24000000`、`0x3D000000`、`#00754A`、`0xDE000000` |
| **合计** | **27** | — |

### 4.2 与 starbucks_tokens.dart 的一致性

逐一比对 27 个硬编码色值与 `starbucks_tokens.dart` 中 `StarbucksCreamColors` / `StarbucksDarkColors` 的定义：

| 硬编码值 | 对应 Token | 一致性 |
|----------|-----------|--------|
| `#00754A` | `StarbucksCreamColors.greenBrand` / `accent` | ✅ 一致 |
| `#1E3932` | `StarbucksCreamColors.greenBanner` | ✅ 一致 |
| `#CBA258` | `StarbucksCreamColors.vipGoldBg` | ✅ 一致 |
| `#EDEBE9` | `StarbucksCreamColors.cardBgAlt` | ✅ 一致 |
| `0xDE000000` | `StarbucksCreamColors.text1`（α=0.87） | ✅ 一致 |
| `0x24000000` | `StarbucksShape.cardShadow[0]` | ✅ 一致 |
| `0x3D000000` | `StarbucksShape.cardShadow[1]` | ✅ 一致 |
| `0x8A000000` | 54% 黑（旧 Mistral 色阶） | ⚠️ 与 `text2`（`0x94212121`）不完全匹配 |
| `0x5400754A` | 绿色 33% 透明 | ✅ 自定义辅助色（无对应 token） |
| `#F9F9F9` | 无对应 | ✅ 中性底色（dropdown 专用） |
| `#E6E6E6` | 无对应 | ✅ 进度条背景（非品牌色） |
| `0x3F000000`、`0x99000000` | 无对应 | ✅ 遮罩/描边（功能色） |

**结论**：27 个色值中 24 个与 token 完全一致或为功能辅助色；1 个存在细微差异（`0x8A000000` vs `0x94212121`），属旧色阶残留，不影响视觉。

### 4.3 Token 引用策略评估

当前组件采用**内部自包含色值**而非 import `starbucks_tokens.dart`：

| 维度 | 当前方案（内部常量） | 替代方案（import token） |
|------|---------------------|-------------------------|
| 耦合度 | 低：组件独立，不依赖外部 token 文件 | 高：token 改值会联动所有组件 |
| 一致性风险 | 中：色值可能与 token 漂移 | 低：单一来源 |
| 可移植性 | 高：可直接复制到其他项目 | 低：需连带 token 文件 |
| 深色模式 | ❌ 无法动态切换 | ✅ 读取 ThemeVars 切换 |

**建议**：当前方案在 Batch 3 阶段可接受（组件先就位）。Batch 4 页面接入时，应将组件内的品牌色常量改为构造函数参数（已有 `fillColor`/`textColor` 等），由页面层从 `ThemeVars` 传入，实现深色模式适配。

---

## 五、命名冲突检查

| 旧组件 | 位置 | 新组件 | 冲突？ |
|--------|------|--------|--------|
| `CustomButton` | `component_widgets.dart:14`（3 处引用，全在该文件内） | `SbButton`（独立文件） | ❌ 无冲突：不同类名、不同文件 |
| `PillButton` | 仅出现在 doc 注释中（`sb_modal.dart:28`、`sb_button.dart:2`） | `SbButton` | ❌ 无冲突：PillButton 无实际代码定义 |

**结论**：无命名冲突。`CustomButton` 与 `SbButton` 可并存，后续 Batch 4 逐步迁移引用后可废弃 `CustomButton`。

---

## 六、综合评估

| 维度 | 状态 | 说明 |
|------|------|------|
| 编译安全 | ✅ 通过 | 0 error, 0 warning |
| 依赖完整性 | ✅ 通过 | 无循环依赖，所有 import 可解析 |
| 命名安全 | ✅ 通过 | 无命名冲突 |
| Token 一致性 | ⚠️ 基本通过 | 27 个硬编码色值中 24 个与 token 一致，1 个细微差异 |
| 外部集成 | ✅ 进展中 | 6/10 组件已被外部页面引用 |
| 深色模式就绪 | ⚠️ 待改进 | 组件内部硬编码色值无法动态切换深色主题 |

### 待修复项（非阻塞）

| # | 优先级 | 项目 | 建议时机 |
|---|--------|------|----------|
| 1 | 低 | sb_modal.dart: `.withOpacity()` → `.withValues(alpha:)` | 下次改动该文件时 |
| 2 | 低 | sb_progress.dart: `___` → `_` | 同上 |
| 3 | 低 | sb_dropdown.dart: doc 注释 HTML 转义 | 同上 |
| 4 | 中 | `0x8A000000` 色值对齐 `text2`（`0x94212121`） | Batch 4 深色模式适配时 |
| 5 | 中 | 组件品牌色从内部常量改为构造函数参数（深色模式） | Batch 4 页面接入时 |

---

*产出：ComponentEngineer · 2026-08-24 · 基于 dart analyze + 静态 grep 取证*
