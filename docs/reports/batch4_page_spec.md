# Batch 4 页面层实施规格：13 活页面三小批拆分

> 项目：Monster Word（word_app）
> 日期：2026-08-24
> 前置依赖：Batch 2（Token 层）+ Batch 3（组件层）完成后方可实施
> 前置参考：`docs/live_route_map.md`、`docs/live_pages_hardcode_map.md`、`docs/component_spec.md`、`docs/starbucks_tokens_draft.md`、`docs/motion_spec.md`、`docs/page_wireframe_specs.md`

---

## 一、分批策略

### 1.1 分批原则

1. **依赖分层**：壳层（Shell）→ 一级页面（Tab）→ 二级页面（子页）→ 三级页面（深层）
2. **每批可独立验收**：批内页面完成后即可进行该层视觉验收
3. **风险递增**：先做简单页面积累经验，再攻重灾区

### 1.2 三小批总览

| 批次 | 定位 | 页面数 | 颜色改动 | 估算总工时 |
|------|------|--------|----------|-----------|
| **4a** | 壳层 + Tab 页 | 4 | 81 处 | ~265 min（4.4h） |
| **4b** | 二级子页 | 6 | 31 处 | ~180 min（3.0h） |
| **4c** | 三级深层页 | 3 | 4 处 | ~105 min（1.75h） |
| **合计** | — | **13** | **~116 处**（word_machine 24 处豁免） | **~550 min（9.2h）** |

---

## 二、Batch 4a：壳层 + Tab 页（第一批）

> 范围：用户冷启动直接看到的 4 个页面，决定第一印象。

### 2.1 页面清单

| # | 文件 | 行数 | 角色 | 颜色改动 | 估算 |
|---|------|------|------|----------|------|
| 1 | `shell/main_shell.dart` | 199 | 三 Tab 框架 + 底部导航 | 5 处 | 30 min |
| 2 | `screens/home_screen.dart` | 288 | Tab1 学习首页 | 15 处 | 75 min |
| 3 | `pages/lib_select_page.dart` | 441 | Tab2 词库选择 | 4 处 | 40 min |
| 4 | `screens/profile_screen.dart` | 319 | Tab3 我的（⚠️ 重灾区） | 27 处 | 120 min |

### 2.2 逐页实施规格

#### ① main_shell.dart（30 min）

**硬编码替换**：

| 行号 | 现状 | 替换为 | 说明 |
|------|------|--------|------|
| 138 | `Color(0xFF1F1F1F)` | `ThemeVars.accent`（`#006241` 星巴克绿） | 选中 tab 图标色（线框图指定） |
| 139 | `Color(0xFF999999)` | `ThemeVars.text3` | 未选中 tab 图标色 |
| 155-156 | `Colors.white` | `ThemeVars.onGlassText1` | 悬浮底栏文字/图标 |
| 185 | `Colors.transparent` | 保留 | 无语义 |
| 186 | `BorderRadius.circular(1)` | 保留 | 像素风指示条 |

**组件替换**：
- 底栏容器 → 无（现有实现已足够）
- Tab 指示器动画 → 统一为 `MotionDurations.base` + `MotionCurves.standard`（250ms → 200ms）

**动效改造**：
- Tab 图标弹跳：350ms `SpringCurve` → 300ms `SpringCurve`（收敛时长，保留仪式性弹性）
- Tab 指示器滑动：250ms `standardCurve` → `MotionDurations.base` + `MotionCurves.standard`

**跨页影响**：底栏样式变更影响所有三个 Tab 页面的底部安全区。
- 底栏背景：透明→奶油画布 `#F2F0EB` 实心 + 顶部发丝线 `rgba(0,0,0,0.08)`（线框图规格）

#### ② home_screen.dart（75 min）

**硬编码替换**：

| 行号 | 现状 | 替换为 | 说明 |
|------|------|--------|------|
| 58, 60 | `Colors.white` | `ThemeVars.onGlassText1/2` | 玻璃打卡卡文本 |
| 127 | `Color(0xFF9BBC0F)` | `GameBoyPalette.screenBg` | 单词机入口 GB 绿 |
| 131 | `Colors.black` | `GameBoyPalette.screenDark` | GB 屏文字 |
| 144 | `Color(0xFF0F380F)` | `GameBoyPalette.screenDark` | GB 屏深绿 |
| 166 | `Color(0xFFFFF3CD)` | `StarGold.cream` | 打卡卡奶黄底 |
| 169 | `Color(0xFF8B6914)` | `StarGold.bronze` | 打卡卡图标金 |
| 187 | `Colors.black` | `ThemeVars.text1` | 文字 |
| 194-228 | `Colors.white` ×7 | 按语境 `ThemeVars.canvas` / `onGlassText1` | 快捷入口卡 |
| 236 | `Color(0xFFFFCC80)` | `StarGold.glow` | 触摸图标色 |

**结构性改动**（线框图指定）：
- 壁纸背景 → 奶油画布 `#F2F0EB`（方案C：画布归品牌，移除壁纸系统）
- 签到卡：毛玻璃 `BackdropFilter` → `ContentCard` 白卡 12px 双层影
- Learn/Review 入口：`GlassEntryCard` 毛玻璃 → `ContentCard` 白卡

**组件替换**：
- 打卡卡区域 → `StreakBanner`（component_spec §4）或保留自定义实现（打卡卡已有横幅逻辑，按需决定是否统一）
- 「开始学习」入口 → `FrapFab`（component_spec §3）
- 快捷入口卡 → `ContentCard`（component_spec §2）
- 进度条 → `SbLinearProgress`（component_spec §10）

**动效改造**：
- 打卡卡入场：保留现有逻辑，统一曲线引用 `MotionCurves.standard`
- 快捷入口卡按压：统一为 `ScaleDownOnPress`，`MotionDurations.fast` + `MotionPress.scale`

#### ③ lib_select_page.dart（40 min）

**硬编码替换**：

| 行号 | 现状 | 替换为 | 说明 |
|------|------|--------|------|
| 152, 190, 323 | `Colors.white` | `ThemeVars.canvas` / `text1` 按语境 | 封面字/标题 |
| 145 | `Colors.transparent` | 保留 | — |
| 303, 315, 345 等 | `AppColors.*` | 迁移到 `MistralColors` / `ThemeVars` | legacy token 迁移 |

**组件替换**：
- 搜索框 → `FloatingLabelField`（component_spec §6）或保留现有实现
- 词库卡片 → `ContentCard`（component_spec §2）
- 书单 tile 按压 → `ScaleDownOnPress`

**动效改造**：
- 卡片入场：保留现有逻辑，统一曲线引用
- 搜索框聚焦：`MotionDurations.base` 浮动标签

#### ④ profile_screen.dart（120 min）⚠️ 重灾区

**硬编码替换**（27 处）：

| 行号 | 现状 | 替换为 | 说明 |
|------|------|--------|------|
| 76-78 | 渐变 `[FFF3CD, FFF8E1, F5F5F5]` | `[StarGold.cream, StarGold.soft, ThemeVars.pageBg]` | 头部渐变 |
| 99 | 卡片渐变 `[FFF3CD, FFE0B2]` | `[StarGold.cream, StarGold.light]` | 用户卡片 |
| 104 | `Color(0xFFFFCC80).withValues(alpha:0.3)` | 移除（过度装饰，线框图指定） | 描边光晕 |
| 110 | `Color(0xFF8B6914)` | `StarGold.bronze` | 图标金 |
| 119 | `Color(0xFF4A6741)` | `ThemeVars.accent` | 深绿按钮 |
| 144 | `Color(0xFFFFE8CC).withValues(alpha:0.6)` | `StarGold.halo` | 装饰光晕 |
| 152, 156, 251, 294 | `Color(0xFFCC8800)` | `StarGold.gold` | 酷币金 |
| 176 | `Color(0xFF4CAF50)` | `MistralColors.success` | 菜单图标绿 |
| 182 | `Color(0xFF9C27B0)` | `FuncColors.purple` | 紫色 |
| 184 | `Color(0xFF2196F3)` | `FuncColors.info` | 蓝色 |
| 248 | `Color(0xFFFFCC80)` | `StarGold.glow` | 金色 |
| 294-300 | 装备图标 4 组色 | `EquipBadge` token | 装备徽章 |
| 101, 121, 125 | `Colors.white` | `onPrimary` / `canvas` | 按语境 |

**结构性改动**（线框图指定）：
- 头部渐变 `[FFF3CD, FFF8E1, F5F5F5]` → 奶油画布 `#F2F0EB` 纯色（移除渐变）
- 头像框：金色渐变→白框 + 绿色 VIP 徽章
- 酷币/装备卡：金色渐变底→`ContentCard` 白卡 + 金色数字 `#CBA258`

**组件替换**：
- 用户信息卡 → `ContentCard` + `GoldPillBadge`（酷币/成就）
- 菜单列表项 → 统一图标色映射（`FuncColors` 系列）
- 装备徽章 → 新建 `EquipBadge` 组件（4 组底/图标色 token）

**动效改造**：
- 头部渐变：保留静态（渐变不做动画）
- 菜单项按压：`ScaleDownOnPress`
- 成就徽章出现：`MotionCurves.springPop`（选中确认感）

### 2.3 Batch 4a 验收标准

- [ ] 底部导航栏选中/未选中色跟随主题切换
- [ ] 首页打卡卡在浅色/深色模式下显示正确
- [ ] 首页快捷入口卡按压反馈统一（scale 0.95, 150ms）
- [ ] Tab2 词库页面卡片在奶油色画布上"浮起"感正确
- [ ] Tab3 个人页头部渐变金色系正确，菜单图标色统一
- [ ] 所有 `Colors.white` 替换为语义 token（无裸 Material 色残留）
- [ ] 所有 `fontSize` 裸数值替换为 `StarbucksTypography` 对应档位
- [ ] 动效时长统一引用 `MotionDurations`，曲线引用 `MotionCurves`
- [ ] 浅色/深色模式切换无色块闪烁或布局跳动

---

## 三、Batch 4b：二级子页（第二批）

> 范围：从 Tab 页导航进入的 6 个二级页面。

### 3.1 页面清单

| # | 文件 | 行数 | 角色 | 颜色改动 | 估算 |
|---|------|------|------|----------|------|
| 5 | `pages/search_page.dart` | 379 | 查词 | 9 处 | 45 min |
| 6 | `pages/dictionary_page.dart` | 584 | 词典结果（✅ 最干净） | 1 处 | 15 min |
| 7 | `pages/word_machine_page.dart` | 770 | 单词机游戏（🎨 像素风豁免） | 24 处豁免 | 45 min |
| 8 | `pages/immersive_swipe_page.dart` | 332 | 沉浸滑卡 | 2 处 | 25 min |
| 9 | `pages/appearance_page.dart` | 288 | 外观设置 | 25 处 | 50 min |
| 10 | `pages/more_settings_page.dart` | 322 | 更多设置 | 9 处 | 30 min |

### 3.2 逐页实施规格

#### ⑤ search_page.dart（45 min）

**硬编码替换**：

| 行号 | 现状 | 替换为 |
|------|------|--------|
| 108 | `Color(0xFFF0F0F0)` | `ThemeVars.cardBgAlt` |
| 113, 139 | `Color(0xFF999999)` | `ThemeVars.text3` |
| 122 | `Color(0xFFBBBBBB)` | `MistralColors.muted` |
| 142 | `Color(0xFF666666)` | `MistralColors.slate` |
| 151 | `Color(0xFF1F1F1F)` | `MistralColors.ink` |
| 212 | `Colors.amber` | `MistralColors.warning` |
| 294, 303 | `Colors.white` | `ThemeVars.canvas` |

**组件替换**：
- 搜索框 → `FloatingLabelField`（component_spec §6）
- 搜索结果列表 → `ContentCard` 包裹

**动效改造**：
- 搜索框胶囊圆角 → `StarbucksShape.radiusPill`
- 搜索结果淡入 → `MotionDurations.base` + `Curves.easeIn`

#### ⑥ dictionary_page.dart（15 min）

**硬编码替换**：

| 行号 | 现状 | 替换为 |
|------|------|--------|
| 448 | `Colors.white` | `ThemeVars.canvas` |

**组件替换**：
- Tab 切换（释义/同反义/词根）→ `SbSegmented`（component_spec §9）

**动效改造**：
- 无额外改造（已是 token 引用）

#### ⑦ word_machine_page.dart（45 min）🎨 像素风豁免

**特殊处理**：
- 24 处硬编码颜色**豁免换肤**（Game Boy 复古像素风是刻意设计）
- 改造范围仅限：
  - `_PixelColors` 整体上移为 `lib/tokens/gameboy.dart` 共享 `GameBoyPalette`
  - 消除 Material 色混用（`Color(0xFF4CAF50)` / `Colors.red` → 并入 `_PixelColors`）
  - 黑/白/透明裸色并入 `_PixelColors` 对应槽位
- **不改动**：圆角、字号阶梯、间距（像素风设计语言）

**组件替换**：无（像素风专用组件）

**动效改造**：
- 入场动画：保留 600ms `SpringCurve`
- 抖动反馈：保留 300ms `Curves.elasticIn`
- 步骤延迟：保留 800/1200ms

#### ⑧ immersive_swipe_page.dart（25 min）

**硬编码替换**：

| 行号 | 现状 | 替换为 |
|------|------|--------|
| 138 | `Colors.white` | `ThemeVars.canvas` |
| 236 | `Colors.black` | `ThemeVars.text1` |

**组件替换**：无（滑卡交互为自定义实现）

**动效改造**：
- 滑入/滑出：保留 300ms `Curves.easeOut` / 200ms `Curves.easeIn`，改引 `MotionDurations.slow` + `MotionCurves.standard` / `MotionCurves.exit`
- 圆角统一：`StarbucksShape.radiusXxl` (20) / `radiusLg` (12)

#### ⑨ appearance_page.dart（50 min）

**硬编码替换**（25 处）：

| 行号 | 现状 | 替换为 |
|------|------|--------|
| 81, 253, 279 | `Color(0xFF1A1A1A)` | `ThemeVars.text1` |
| 103 | 天空场景渐变 `[87CEEB, B0C4DE, F5F5F5]` | 保留（场景插画色） |
| 163 | `Color(0xFFD6E6F2)` | 保留（预览容器底） |
| 217, 223 | `Color(0xFFFF6800)` | `MistralColors.primary`（待裁定） |
| 259 | `Color(0xFFE8913A)` | `MistralColors.primary`（同值直替） |
| 261 | `Color(0xFFE0E0E0)` | `MistralColors.hairline` |
| 281, 283 | `Color(0xFF999999)` | `ThemeVars.text3` |
| 113-273 | `Colors.white` ×11 | 按语境 `ThemeVars.cardBg` / `text1` |

**组件替换**：
- 主题预览卡 → `ContentCard`
- 开关控件 → 保留现有，统一动效参数

**动效改造**：
- 主题切换预览：`MotionDurations.slow` + `MotionCurves.standard`
- 开关状态：`MotionDurations.base`

#### ⑩ more_settings_page.dart（30 min）

**硬编码替换**（9 处）：

| 行号 | 现状 | 替换为 |
|------|------|--------|
| 56 | `Color(0xFF4A90E2)` | `MistralColors.link` |
| 70 | `Color(0xFF4CAF50)` | `MistralColors.success` |
| 77 | `Color(0xFFFFB83E)` | `MistralColors.warning` |
| 85 | `Color(0xFF2196F3)` | `FuncColors.info` |
| 92 | `Color(0xFF9C27B0)` | `FuncColors.purple` |
| 103 | `Color(0xFFFF6800)` | `MistralColors.primary` |
| 110 | `Color(0xFFE3303B)` | `MistralColors.danger` |
| 313, 315 | `Colors.white` | `ThemeVars.canvas` / `onPrimary` |

**组件替换**：
- 底部弹窗 → `sbShowSheet`（component_spec §8）
- 下拉选择器 → `SbDropdown`（component_spec §7）

**动效改造**：
- 底部弹窗出入：`MotionDurations.slow` + `MotionCurves.standard`（进入），`MotionDurations.fast` + `MotionCurves.exit`（退出）

### 3.3 Batch 4b 验收标准

- [ ] 搜索页输入框在奶油色画布上视觉正确
- [ ] 词典页 Tab 切换使用 `SbSegmented` 组件
- [ ] 单词机页面像素风不变，`GameBoyPalette` 已抽取为共享 token
- [ ] 沉浸滑卡滑入/滑出动效使用统一 token
- [ ] 外观设置页主题预览卡在浅色/深色下均正确
- [ ] 更多设置页底部弹窗使用 `sbShowSheet`，图标色统一
- [ ] 所有页面按压反馈统一为 `ScaleDownOnPress`

---

## 四、Batch 4c：三级深层页（第三批）

> 范围：最深层的学习/复习/详情页面，核心学习流程。

### 4.1 页面清单

| # | 文件 | 行数 | 角色 | 颜色改动 | 估算 |
|---|------|------|------|----------|------|
| 11 | `pages/learn_page.dart` | 362 | 4选1 学习流程（核心） | 17 处 | 60 min |
| 12 | `screens/review_session.dart` | 347 | 复习会话（✅ 最规范） | 0 处 | 20 min |
| 13 | `pages/word_detail_page.dart` | 651 | 单词详情 | 2 处 | 25 min |

### 4.2 逐页实施规格

#### ⑪ learn_page.dart（60 min）

**硬编码替换**（17 处）：

| 行号 | 现状 | 替换为 |
|------|------|--------|
| 123-214 | `Colors.white` ×11 | 底→`ThemeVars.cardBg`，字→`text1`，主按钮字→`onPrimary` |
| 49 | `Colors.black` | `Colors.black.withValues(alpha:)` 保留 |
| 151 | `Colors.amber` | `MistralColors.warning` |
| 324-325 | `Color(0xFFE8A0A0)` | `ThemeVars.quizWrongBg` / `quizWrongText` |
| 327-328, 347 | `Colors.white` | `onPrimary` / `text1` |

**结构性改动**（线框图指定）：
- 壁纸背景 → 奶油画布 `#F2F0EB`（移除遮罩）
- 选项卡：白底→`ContentCard`（12px + 双层影）
- 底部三键：下划线→`PillButton` 描边款

**组件替换**：
- 选项卡 → `ContentCard` 包裹
- 进度指示 → `SbLinearProgress`（component_spec §10）
- 正确/错误反馈 → 统一使用 `ThemeVars.quizCorrectBg/WrongBg`

**动效改造**（核心答题流程）：
- 答错标红：`MotionDurations.base` + `MotionCurves.standard`（200ms 变色）
- 答错微抖：由 ±6px/400ms 收敛为 **±3px / `MotionDurations.slow`(300ms)** / 单周期
- 答错降权：opacity 1→0.55，`MotionDurations.base`
- 答对确认：对勾 scale 0.6→1.0，`MotionDurations.base` + `MotionCurves.springPop`
- 答对弹跳：`BounceWidget` 幅度由 1.08 降为 **1.04**
- 后续跳转：保持 400ms 延迟

#### ⑫ review_session.dart（20 min）

**硬编码替换**：0 处（全 glass_widgets + skin，已是 token 引用 ✅）

**结构性改动**（线框图指定）：
- 壁纸背景 → 奶油画布 `#F2F0EB`
- 选项卡：毛玻璃→`ContentCard` 白卡
- 底部三键：下划线→`PillButton` 描边款

**组件替换**：无（已使用 glass_widgets 体系，但需替换为 ContentCard）

**动效改造**：
- 间距归档：`SizedBox` 6→`AppleSpacing.xs8`（机械替换）
- 现有动效已规范，无需额外改造

#### ⑬ word_detail_page.dart（25 min）

**硬编码替换**：

| 行号 | 现状 | 替换为 |
|------|------|--------|
| 245 | `Colors.white` | `ThemeVars.canvas` |
| 626 | `Colors.red` | `MistralColors.danger` |

**组件替换**：
- 星标单词 → `GoldPillBadge`（component_spec §5）
- 单词大字 → `StarbucksTypography.heroWord`

**动效改造**：
- 详情页入场：保留现有 1s 动效，统一曲线引用
- 间距归档：`SizedBox` 20→`AppleSpacing.xl20`，8→`xs8`

### 4.3 Batch 4c 验收标准

- [ ] 学习页 4 选项答题流程完整：标红→微抖→降权→重选→正确确认
- [ ] 答错动效克制（±3px，不循环，不阻断操作）
- [ ] 答对动效有确认感（springPop 曲线，BounceWidget 1.04）
- [ ] 复习会话页零改动（已是 token 引用），验证无回归
- [ ] 单词详情页星标使用 `GoldPillBadge`
- [ ] 全部 13 页浅色/深色模式切换无异常

---

## 五、跨页面共享改动清单

以下改动影响多个页面，需在 Batch 4 开工前或 Batch 4a 阶段完成：

### 5.1 Token 层前置（Batch 2 产出，Batch 4 消费）

| Token 组 | 文件 | 落地页面 |
|----------|------|----------|
| `StarGold`（cream/soft/light/glow/halo/gold/bronze） | `lib/tokens/star_gold.dart` | home_screen, profile_screen |
| `GameBoyPalette`（screenBg/screenDark/…） | `lib/tokens/gameboy.dart` | word_machine_page, home_screen |
| `FuncColors`（info/purple） | `lib/tokens/func_colors.dart` | profile_screen, more_settings_page |
| `EquipBadge`（4 组底/图标色） | `lib/tokens/equip_badge.dart` | profile_screen |

### 5.2 组件层前置（Batch 3 产出，Batch 4 消费）

| 组件 | 文件 | 使用页面 |
|------|------|----------|
| `PillButton` | `lib/widgets/pill_button.dart` | 全局（StreakBanner CTA、设置确认等） |
| `ContentCard` | `lib/widgets/content_card.dart` | home, lib_select, search, appearance, more_settings |
| `FrapFab` | `lib/widgets/frap_fab.dart` | home_screen |
| `StreakBanner` | `lib/widgets/streak_banner.dart` | home_screen |
| `GoldPillBadge` | `lib/widgets/gold_pill_badge.dart` | profile, word_detail, home |
| `FloatingLabelField` | `lib/widgets/floating_label_field.dart` | search, lib_select |
| `SbDropdown` | `lib/widgets/sb_dropdown.dart` | more_settings, appearance |
| `SbModal` / `sbShowSheet` | `lib/widgets/sb_dialog.dart` | home, more_settings |
| `SbSegmented` | `lib/widgets/sb_segmented.dart` | dictionary, learn/review |
| `SbProgress` | `lib/widgets/sb_progress.dart` | home, learn, review |

### 5.3 动效 Token 前置

| Token | 文件 | 说明 |
|-------|------|------|
| `MotionDurations`（fast/base/slow/expressive） | `lib/theme/motion_tokens.dart` | 全部 13 页 |
| `MotionCurves`（standard/accordion/springPop/exit/elastic） | 同上 | 全部 13 页 |
| `MotionPress.scale` (0.95) | 同上 | 全部按压组件 |

### 5.4 main_shell 底部导航（Batch 4a 内跨页改动）

- 底栏背景色：玻璃层 `glassBg` / `glassBgStrong`（跟随主题）
- 选中/未选中图标色：`tabBarIcon` / `text3`
- Tab 指示器：`accent` 色
- 底栏入场动画：`expressive` 档（仪式性时刻白名单）

### 5.5 全局主题切换

- 所有页面需支持 `ThemeVars` 读取（已由 `skin_system.dart` 提供）
- 切换主题时无闪烁：确保 `ThemePreset` 切换是原子操作
- 深色模式三层深绿体系：canvas `#101B17` / surface `#1E3932` / surfaceHigh `#274A40`

---

## 六、风险点与回滚方案

### 6.1 风险矩阵

| 风险 | 概率 | 影响 | 缓解措施 |
|------|------|------|----------|
| Token 层（Batch 2）未按时完成 | 中 | Batch 4 全部阻塞 | 4a 可先用 `AppColors` 占位，后统一迁移 |
| 组件层（Batch 3）质量不达标 | 低 | 页面接入时发现组件 bug | 每个组件单独验收，不合格打回 Batch 3 |
| profile_screen 改造超时 | 高 | 4a 整批延迟 | 预留 20% 缓冲（120→144 min）；必要时拆为 4a/4b 两次提交 |
| word_machine 像素风改动破坏设计 | 中 | 用户体验回退 | 仅做 token 上移，不改视觉表现；改动前后截图对比 |
| 动效收敛引起体感差异 | 低 | 用户觉得"变慢/变快" | 时长变化 ≤50ms 的体感差异极小，验收时实际设备测试 |
| 深色模式 A11y 不达标 | 中 | 文字不可读 | 严格遵循 `starbucks_tokens_draft.md` A11y 验证值 |

### 6.2 回滚方案

**回滚粒度**：每个页面独立提交，可按页面粒度回滚。

| 回滚级别 | 触发条件 | 操作 |
|----------|----------|------|
| 单页回滚 | 某页面改造后功能异常 | `git revert` 该页面的提交 |
| 批次回滚 | 整批改造引起系统性问题 | `git revert` 该批次所有提交 |
| Token 回滚 | Token 值导致全局色偏 | 修改 `starbucks_tokens_draft.md` 对应值，重新生成 |

**回滚前检查清单**：
1. 确认问题确实由本次改造引入（非既有 bug）
2. 检查是否有其他页面依赖已改动的 token
3. 回滚后运行 `flutter analyze` 确保无编译错误

### 6.3 灰度策略（可选）

- **Phase 1**：仅启用 `starbucks_cream` 浅色主题，深色保持现状
- **Phase 2**：启用 `starbucks_dark` 深色主题
- **Phase 3**：清理旧主题预设（`bright` / `dark` / `pure_black`）

---

## 七、排期汇总

### 7.1 甘特图（建议）

```
Week 1:
  Mon-Tue  Batch 4a (265 min ≈ 1.5 天)
  Wed      Batch 4a 验收 + Bug 修复

Week 2:
  Mon-Tue  Batch 4b (180 min ≈ 1 天)
  Wed      Batch 4b 验收 + Bug 修复

Week 3:
  Mon      Batch 4c (105 min ≈ 0.5 天)
  Tue      全量回归测试
  Wed      收尾 + 文档更新
```

### 7.2 工时明细

| 批次 | 颜色替换 | 组件接入 | 动效改造 | 自测缓冲(20%) | 总计 |
|------|----------|----------|----------|---------------|------|
| 4a | 120 min | 80 min | 65 min | 53 min | **318 min** |
| 4b | 80 min | 40 min | 60 min | 36 min | **216 min** |
| 4c | 30 min | 20 min | 55 min | 21 min | **126 min** |
| **合计** | 230 min | 140 min | 180 min | 110 min | **660 min ≈ 11h ≈ 1.5 人天** |

---

*制定人：BrandEngineer（【重构58】）· 2026-08-24*
