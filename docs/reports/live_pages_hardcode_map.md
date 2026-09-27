# 活页面硬编码地图：13 页逐行替换指南

> 范围：【重构25】live_route_map 判定的 **13 个运行时可达页面**。
> 方法：只读静态提取，逐行定位 `Color(0x…)` 字面量、Flutter `Colors.*`、`fontSize:`、`BorderRadius.circular()`、`SizedBox/EdgeInsets` 魔法数。
> 用途：星巴克改造施工弹药库——每处给出精确行号、现状片段与替换目标。

---

## 一、口径说明（与 Architect ~40 处 / Surveyor ~153 处的对齐）

| 口径 | 数值 | 统计范围与规则 |
|---|---|---|
| Surveyor【重构4】 | ~153 处 | **全部 58 个 UI 文件**（含 45 个死页面）的 `Color(0x…)` 字面量出现次数 |
| Architect 报告 | ~40 处 | 推测为**去重后的语义色值**数（同一颜色多处出现只计一次）或仅核心冲突色，待 BuildScout 全局裁定 |
| 本文 | **140 处颜色引用**（74 处 `Color(0x…)` + 66 处 Flutter 裸 `Colors.*`） | 仅 13 个活页面；`AppColors.*`/`MistralColors.*`/`ThemeVars.*` 引用**不计入**（已是 token）；`_PixelColors.*` 为页面本地调色板单独归类 |

本文在活页面内的进一步细分：
- **word_machine_page 豁免域 24 处**（本地 Game Boy 调色板 9 + 其 Material 色混用 9 + 散点字面量 6）：复古像素风是刻意设计，不换肤，仅收敛归位；
- **实际需处理 ≈116 处**：其中纯白/黑/透明等机械替换约 52 处（低风险批量操作），语义色需映射决策约 64 处。

> BuildScout 正在做全局 token 裁定；本文只负责活页面部分的**行级精确化**，文中「🆕」标记的新 token 名为建议名，最终以全局裁定为准。

---

## 二、跨页面重复硬编码值（应提升为共享 Token）⭐

| 重复值 | 出现位置 | 建议 |
|---|---|---|
| 🥇 **奶油金系** `FFF3CD / FFF8E1 / FFE0B2 / FFCC80 / FFE8CC / CC8800 / 8B6914` | profile_screen×12、home_screen×3 | 🆕 `StarGold` 组（cream/soft/light/glow/halo/gold/bronze）。这是金色头部+打卡卡的灵魂色，也是与星巴克绿冲突最直接的色系，必须全局一处定义 |
| 🥈 **Game Boy 四绿** `9BBC0F / 0F380F`（+`306230 / 8BAC0F`） | word_machine:21-22（定义）、home_screen:127/:144（**重复字面量**） | 把 `_PixelColors` 上移为 `lib/tokens/gameboy.dart` 共享 `GameBoyPalette`，home_screen 改为 import 引用 |
| 🥉 **Material 功能三原色** `4CAF50 / 2196F3 / 9C27B0` | more_settings:70/:85/:92、profile_screen:176/:182/:184、word_machine:221 | 🆕 `FuncColors.info/.purple`；success 直接用现有 `MistralColors.success`（同为 4CAF50 系） |
| `999999` 中性灰 | main_shell:139、search:113/:139、appearance:281/:283 | `ThemeVars.text3`（已有） |
| `1F1F1F` 主墨色 | main_shell:138、search:151 | `MistralColors.ink`（同值，直接替换） |
| `FF6800` 强调橙 | more_settings:103、appearance:217/:223 | `MistralColors.primary`(E8913A) 近似归一，是否允许色差请 BuildScout 裁定 |
| `E3303B` 危险红 | more_settings:110 | `MistralColors.danger`（同值，直接替换） |
| `E8913A` 品牌橙 | appearance:259 | 即 `MistralColors.primary` 原值，直接替换 |
| 裸 `Colors.white` ×~48 | 全部 13 页 | 按语境映射：玻璃面上→`ThemeVars.onGlassText1`；普通卡片→`ThemeVars.cardBg`/`canvas`；主按钮字→`onPrimary` |
| 圆角 `R16 / R20` 高频 | 各页 | 已有 `AppleRadius.xl16 / xxl20`，无需新 token |

---

## 三、逐页地图（13 页）

### 1. shell/main_shell.dart（199 行）｜估算 ⏱ 30 分钟

| 行号 | 现状代码片段 | 类型 | 建议替换目标 |
|---|---|---|---|
| 138 | `static const Color _selectedColor = Color(0xFF1F1F1F)` | 颜色 | `ThemeVars.text1`（选中 tab 图标色，建议改由 skin 下发以随主题） |
| 139 | `static const Color _unselectedColor = Color(0xFF999999)` | 颜色 | `ThemeVars.text3` |
| 155-156 | `color: Colors.white`（悬浮底栏文字/图标） | 颜色 | `ThemeVars.onGlassText1 / onGlassText2` |
| 185 | `Colors.transparent` | 颜色 | 保留（无语义） |
| 186 | `BorderRadius.circular(1)` | 圆角 | 像素风指示条，保留 |

### 2. screens/home_screen.dart（288 行）｜估算 ⏱ 75 分钟

| 行号 | 现状代码片段 | 类型 | 建议替换目标 |
|---|---|---|---|
| 58, 60 | `Colors.white`（玻璃打卡卡文本） | 颜色 | `onGlassText1 / onGlassText2` |
| 127 | `const Color(0xFF9BBC0F)`（单词机入口 GB 绿） | 颜色 | 🆕 `GameBoyPalette.screenBg`（与 word_machine 同源） |
| 131 | `Colors.black`（GB 屏文字） | 颜色 | `GameBoyPalette.screenDark` |
| 144 | `Color(0xFF0F380F)`（GB 屏深绿） | 颜色 | `GameBoyPalette.screenDark` |
| 166 | `Color(0xFFFFF3CD)`（打卡卡奶黄底） | 颜色 | 🆕 `StarGold.cream` |
| 169 | `Icon(..., color: Color(0xFF8B6914))` | 颜色 | 🆕 `StarGold.bronze` |
| 187 | `Colors.black` | 颜色 | `ThemeVars.text1` |
| 194-228 | `Colors.white` ×7（快捷入口卡文本/图标） | 颜色 | 按面语境 `canvas / onGlassText1` |
| 236 | `Icon(Icons.touch_app, color: const Color(0xFFFFCC80))` | 颜色 | 🆕 `StarGold.glow` |
| 68, 194 | `fontSize: 16` | 字号 | `MistralTypography.bodyMd` |
| 71, 142 | `fontSize: 14` | 字号 | `bodySm` |
| 51, 59, 181, 188 | `BorderRadius.circular(20)` | 圆角 | `AppleRadius.xxl20` |
| 202 | `BorderRadius.circular(16)` | 圆角 | `AppleRadius.xl16` |
| 212, 215, 218 | `BorderRadius.circular(3)`（进度条像素块） | 圆角 | 保留（像素风） |
| 229 | `BorderRadius.circular(8)` | 圆角 | `AppleRadius.md8` |
| 66, 69, 99, 195, 213, 216 | `SizedBox(h10/h4/w12/h16/h8)` | 间距 | `AppleSpacing` 就近档位（xs8/sm12/md16） |

### 3. pages/lib_select_page.dart（441 行）｜估算 ⏱ 40 分钟

| 行号 | 现状代码片段 | 类型 | 建议替换目标 |
|---|---|---|---|
| 152, 190, 323 | `Colors.white`（封面字/标题） | 颜色 | `canvas` / `text1` 按语境 |
| 145 | `Colors.transparent` | 颜色 | 保留 |
| 303, 315, 345, 357, 367-385 | `AppColors.dividerGrey/mainBgTop/mainBgBottom/black/successGreen/textTertiary` | 颜色 | ✅ 已是 token；建议从 legacy `AppColors` 迁移到 `MistralColors/ThemeVars` 语义名（dividerGrey→divider 等） |
| 90, 343 | `fontSize: 16`；:151/:356/:367/:377 `fontSize: 12`；:324/:432 `fontSize: 11`；:383 `fontSize: 14` | 字号 | `bodyMd / caption / captionBold / bodySm` |
| 146 | `BorderRadius.circular(16)`；:317 `circular(4)` | 圆角 | `AppleRadius.xl16 / xs4`（4dp 封面注释表明刻意小圆角，可保留） |
| 85, 331, 363, 379, 428 | `SizedBox(w4/w16/h8/w5/h4)` | 间距 | `xxs4 / sm12 / xs8` |

### 4. screens/profile_screen.dart（319 行）｜⚠️ 重灾区｜估算 ⏱ 120 分钟

| 行号 | 现状代码片段 | 类型 | 建议替换目标 |
|---|---|---|---|
| 76-78 | 头部渐变 `[FFF3CD, FFF8E1, F5F5F5]` | 颜色 | 🆕 `StarGold.cream / StarGold.soft` + `MistralColors.cream` |
| 99 | 卡片渐变 `[Color(0xFFFFF3CD), Color(0xFFFFE0B2)]` | 颜色 | 🆕 `StarGold.cream / StarGold.light` |
| 104 | `Color(0xFFFFCC80).withValues(alpha: 0.3)`（描边光晕） | 颜色 | 🆕 `StarGold.glow` |
| 110 | `Icon(..., color: Color(0xFF8B6914))` | 颜色 | 🆕 `StarGold.bronze` |
| 119 | `color: const Color(0xFF4A6741)`（深绿按钮） | 颜色 | `ThemeVars.accent`（星巴克化后即品牌绿） |
| 144 | `Color(0xFFFFE8CC).withValues(alpha: 0.6)` | 颜色 | 🆕 `StarGold.halo` |
| 152, 156, 251, 294 | `Color(0xFFCC8800)`（酷币金） | 颜色 | 🆕 `StarGold.gold`（或 `vipGoldText`） |
| 176 | `const Color(0xFF4CAF50)`（菜单图标绿） | 颜色 | `MistralColors.success` |
| 182 | `const Color(0xFF9C27B0)` | 颜色 | 🆕 `FuncColors.purple` |
| 184 | `const Color(0xFF2196F3)` | 颜色 | 🆕 `FuncColors.info` |
| 248 | `color: Color(0xFFFFCC80)` | 颜色 | 🆕 `StarGold.glow` |
| 294-300 | 装备图标 4 组 `[FFE0B2/CC8800, BBDEFB/1976D2, E8F5E9/388E3C, F3E5F5/7B1FA2]` | 颜色 | 🆕 `EquipBadge` 四组底/图标色 token（与 more_settings 菜单色板共用） |
| 101, 121, 125 | `Colors.white` | 颜色 | `onPrimary / canvas` 按语境 |
| 126 | `fontSize: 9`（角标） | 字号 | `MistralTypography.micro` |
| 145 | `BorderRadius.circular(20)`；:171/:228/:275 `circular(16)`；:203 `circular(10)`；:314 `circular(7)` | 圆角 | `xxl20 / xl16 / lg12(就近) / md8(就近)` |
| 42-54, 135-155, 241-299 | `SizedBox` 20/16/12/10/8/6/4 组 | 间距 | `AppleSpacing` 档位归一（6→xs8、10→sm12 就近取整） |

### 5. pages/search_page.dart（379 行）｜估算 ⏱ 45 分钟

| 行号 | 现状代码片段 | 类型 | 建议替换目标 |
|---|---|---|---|
| 108 | `color: const Color(0xFFF0F0F0)`（搜索框底） | 颜色 | `ThemeVars.cardBgAlt` |
| 113, 139 | `Icon(..., color: Color(0xFF999999))` | 颜色 | `ThemeVars.text3` |
| 122 | `Color(0xFFBBBBBB)`（占位字） | 颜色 | `MistralColors.muted` |
| 142 | `Color(0xFF666666)`（扫码图标） | 颜色 | `MistralColors.slate` |
| 151 | `TextStyle(fontSize: 16, color: Color(0xFF1F1F1F))` | 颜色+字号 | `MistralColors.ink` + `bodyMd` |
| 212 | `Colors.amber`（历史星标） | 颜色 | `MistralColors.warning` 或 legacy `highlightOrange` |
| 294, 303 | `Colors.white` | 颜色 | `canvas` 按语境 |
| 109 | `BorderRadius.circular(20)`（搜索框胶囊） | 圆角 | `AppleRadius.pill9999` |
| 123 | `fontSize: 15` | 字号 | `bodyMd`（15→16 归档） |

### 6. pages/dictionary_page.dart（584 行）｜✅ 最干净｜估算 ⏱ 15 分钟

| 行号 | 现状代码片段 | 类型 | 建议替换目标 |
|---|---|---|---|
| 108, 160 | `MistralColors.primary / success` | 颜色 | ✅ 已是 token |
| 448 | `Colors.white` | 颜色 | 按语境 `canvas` |
| 97 | `fontSize: 17`；:177 `fontSize: 11` | 字号 | `heading5 / captionBold` |
| 91 | `SizedBox(width: 4)` | 间距 | `AppleSpacing.xxs4` |

### 7. pages/word_machine_page.dart（770 行）｜🎨 像素风豁免域｜估算 ⏱ 45 分钟

| 行号 | 现状代码片段 | 类型 | 建议替换目标 |
|---|---|---|---|
| 21-29 | `_PixelColors` 本地调色板 9 色（GB 四绿+机身灰×3+A紫+B红） | 颜色 | **豁免换肤**；建议整体上移 🆕 `lib/tokens/gameboy.dart` 供 home_screen 复用 |
| 157 | `backgroundColor: const Color(0xFF2C2C2C)`（暂停对话框底） | 颜色 | 并入 `_PixelColors`（如 `dialogBg`）保持像素风一致 |
| 221, 226 | `Color(0xFF4CAF50)` / `Colors.red`（开始键状态） | 颜色 | 并入 `_PixelColors.startGo/startStop`，去除 Material 色混用 |
| 535-536, 585 | `Color(0xFF5A1010) / Color(0xFFFF6666)`（答错红屏） | 颜色 | 并入 `_PixelColors.errorBg/errorText` |
| 179, 287, 616, 653 | `Colors.black`；:629/:666 `Colors.white`；:549 `transparent` | 颜色 | 并入 `_PixelColors` 对应槽位 |
| 176 | `BorderRadius.circular(20)`（机身）；其余 R4/R5/R8/R1 像素钮 | 圆角 | 保留（设计语言） |
| 324-498 | `fontSize` 36/28/18/16/14/12/11/10 阶梯 | 字号 | 保留（像素屏字体阶梯） |
| — | 间距若干 | 间距 | 保留 |

### 8. pages/immersive_swipe_page.dart（332 行）｜估算 ⏱ 25 分钟

| 行号 | 现状代码片段 | 类型 | 建议替换目标 |
|---|---|---|---|
| 138 | `Colors.white` | 颜色 | `canvas` 按语境 |
| 236 | `Colors.black` | 颜色 | `ThemeVars.text1` |
| 195, 232 | `BorderRadius.circular(20)` | 圆角 | `AppleRadius.xxl20` |
| 275, 292 | `BorderRadius.circular(12)` | 圆角 | `AppleRadius.lg12` |
| 128-133, 201-211, 258-281, 322-326 | `SizedBox` 16/8/24/12/4/48 组 | 间距 | `AppleSpacing` 档位（48→xxl32+sm12 或保留特例） |

### 9. pages/learn_page.dart（362 行）｜核心学习流程｜估算 ⏱ 60 分钟

| 行号 | 现状代码片段 | 类型 | 建议替换目标 |
|---|---|---|---|
| 123-214 | `Colors.white` ×11（选项卡底/字、顶部栏） | 颜色 | 底→`ThemeVars.cardBg`，字→`text1`，主按钮字→`onPrimary` |
| 49 | `Colors.black`（阴影/遮罩） | 颜色 | `Colors.black.withValues(alpha:)` 保留或 `wallpaperScrim` |
| 151 | `Colors.amber`（星标） | 颜色 | `MistralColors.warning` |
| 324-325 | `Color(0xFFE8A0A0).withOpacity(0.6)` / `Color(0xFFE8A0A0)`（答错卡 bg/边框） | 颜色 | `ThemeVars.quizWrongBg / quizWrongText` 体系（与新复习流程对齐） |
| 327-328, 347 | `Colors.white`（选项文字） | 颜色 | `onPrimary` / `text1` |
| 192 | `fontSize: 40`（单词大字） | 字号 | `MistralTypography.heroDisplay` |
| 127, 346 | `fontSize: 16`；:214 `14`；:303 `13` | 字号 | `bodyMd / bodySm / caption` |
| 137 | `BorderRadius.circular(2)`；:340 `circular(14)` | 圆角 | 保留 / `lg12(就近)` 或新增 `radius14` 由裁定 |
| 128, 147, 198, 212, 307 | `SizedBox(w8/h8/w8/h8/h12)` | 间距 | `AppleSpacing.xs8 / sm12` |

### 10. screens/review_session.dart（347 行）｜✅ 最规范｜估算 ⏱ 20 分钟

| 行号 | 现状代码片段 | 类型 | 建议替换目标 |
|---|---|---|---|
| — | 颜色 0 处硬编码（全 glass_widgets + skin） | 颜色 | ✅ 无需处理 |
| 168-334 | `SizedBox` h8/h32/h16/h24/h6 若干 | 间距 | `AppleSpacing` 档位（6→xs8 归档） |

### 11. pages/appearance_page.dart（288 行）｜估算 ⏱ 50 分钟

| 行号 | 现状代码片段 | 类型 | 建议替换目标 |
|---|---|---|---|
| 81, 253, 279 | `TextStyle(..., color: Color(0xFF1A1A1A))` | 颜色 | `ThemeVars.text1` |
| 103 | 天空场景预览渐变 `[87CEEB, B0C4DE, F5F5F5]` | 颜色 | 🎨 场景插画色，建议保留或入 🆕 `WallpaperPalette`（随壁纸体系重构一并决策） |
| 163 | `Color(0xFFD6E6F2)`（预览容器底） | 颜色 | 同上 |
| 217, 223 | `isSelected ? Color(0xFFFF6800) : preset.vars.divider` / `Icon(check, color: Color(0xFFFF6800))` | 颜色 | `MistralColors.primary`（FF6800→E8913A 归一，待裁定） |
| 259 | `activeTrackColor: const Color(0xFFE8913A)` | 颜色 | `MistralColors.primary`（同值直替） |
| 261 | `inactiveTrackColor: const Color(0xFFE0E0E0)` | 颜色 | `MistralColors.hairline` |
| 281, 283 | `Color(0xFF999999)`（value 文字/箭头） | 颜色 | `ThemeVars.text3` |
| 113-273 | `Colors.white` ×11、:148 `Colors.black` | 颜色 | 卡底 `cardBg` / 文字 `text1` 按语境 |
| 81, 253, 279 | `fontSize: 16`；:230 `13`；:281 `14` | 字号 | `bodyMd / caption / bodySm` |
| 99, 162, 200, 248, 274 | `BorderRadius.circular(16)`；:114 `8`；:125/:132 `6`；:171 `4`；:181 `3` | 圆角 | `xl16 / md8 / sm6(就近) / xs4 / 保留` |
| 40-55, 84-156, 173-282 | `SizedBox` 20/24/16/32/48/12/8/4 组 | 间距 | `AppleSpacing` 档位 |

### 12. pages/more_settings_page.dart（322 行）｜估算 ⏱ 30 分钟

| 行号 | 现状代码片段 | 类型 | 建议替换目标 |
|---|---|---|---|
| 56 | `iconColor: const Color(0xFF4A90E2)`（账号） | 颜色 | `MistralColors.link`（同值） |
| 70 | `iconColor: const Color(0xFF4CAF50)` | 颜色 | `MistralColors.success` |
| 77 | `iconColor: const Color(0xFFFFB83E)` | 颜色 | `MistralColors.warning`(F59E0B 就近) 或保留专色 |
| 85 | `iconColor: const Color(0xFF2196F3)` | 颜色 | 🆕 `FuncColors.info` |
| 92 | `iconColor: const Color(0xFF9C27B0)` | 颜色 | 🆕 `FuncColors.purple` |
| 103 | `iconColor: const Color(0xFFFF6800)` | 颜色 | `MistralColors.primary`（归一待裁定） |
| 110 | `iconColor: const Color(0xFFE3303B)`（退出登录） | 颜色 | `MistralColors.danger`（同值直替） |
| 313, 315 | `Colors.white` | 颜色 | `canvas / onPrimary` 按语境 |
| 50-115, 141-160 | `SizedBox` h16×4、h32×2；:186/:246/:294 w4/w14 | 间距 | `AppleSpacing.md16 / xxl32 / xxs4`（w14→sm12 归档） |

### 13. pages/word_detail_page.dart（651 行）｜估算 ⏱ 25 分钟

| 行号 | 现状代码片段 | 类型 | 建议替换目标 |
|---|---|---|---|
| 184-199, 342-344, 587-589 | `MistralColors.cream / beigeDeep / creamLight` | 颜色 | ✅ 已是 token |
| 245 | `Colors.white` | 颜色 | 按语境 `canvas` |
| 626 | `Colors.red`（错误提示） | 颜色 | `MistralColors.danger` |
| 352 | `fontSize: 40`（单词大字） | 字号 | `heroDisplay` |
| 147-218 | `SizedBox(h20/h8)` 区块节奏组 | 间距 | `lg20 / xs8` |

---

## 四、排期汇总

| # | 页面 | 颜色处数(C0x/Material) | 估算 |
|---|---|---|---|
| 1 | main_shell | 2 / 3 | 30 min |
| 2 | home_screen | 5 / 10 | 75 min |
| 3 | lib_select | 0 / 4 | 40 min |
| 4 | **profile_screen** | **24 / 3** | **120 min** |
| 5 | search_page | 6 / 3 | 45 min |
| 6 | dictionary_page | 0 / 1 | 15 min |
| 7 | word_machine（豁免域） | 15 / 9 | 45 min |
| 8 | immersive_swipe | 0 / 2 | 25 min |
| 9 | learn_page | 2 / 15 | 60 min |
| 10 | review_session | 0 / 0 | 20 min |
| 11 | appearance_page | 13 / 12 | 50 min |
| 12 | more_settings | 7 / 2 | 30 min |
| 13 | word_detail | 0 / 2 | 25 min |
| | **合计** | **74 / 66** | **580 min ≈ 9.7 人时**（+20% 自测缓冲 ≈ **11.6 人时 / 约 1.5 人天**） |

施工顺序建议：先落共享 token（StarGold/GameBoyPalette/FuncColors，见第二节，约 1 小时）→ 再按 4(profile)→9(learn)→2(home) 重灾区顺序开工 → 干净页（6/10/13）随手收尾。
