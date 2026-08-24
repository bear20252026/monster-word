# 【重构53】Batch 2 实施规格：Token 层落地

> 输入：`docs/starbucks_tokens_draft.md` + `lib/tokens/design_tokens.dart` + `lib/theme/skin_system.dart`
> 性质：**操作级实施规格**，所有改动点精确到 文件:行号
> 依赖：Batch 1 已完成（亮度拆分/持久化/跟随系统）

---

## 一、任务总览

Batch 2 目标：将 `starbucks_tokens_draft.md` 的两套 ThemeVars 落地为可运行代码。

**改动范围**（共 3 个文件）：

| 文件 | 动作 | 说明 |
|---|---|---|
| `lib/tokens/starbucks_tokens.dart` | **新建** | 星巴克专用颜色/形状/文字常量 |
| `lib/tokens/design_tokens.dart` | **修改** | 添加过渡期别名，指向新 token |
| `lib/theme/skin_system.dart` | **修改** | 新增 `starbucks_cream` / `starbucks_dark` 预设 |

---

## 二、新建 `lib/tokens/starbucks_tokens.dart`

### 2.1 文件结构

```dart
// lib/tokens/starbucks_tokens.dart
// 星巴克双主题 Token 集 — 方案C（画布归品牌，装饰归个性）
// 来源：docs/starbucks_tokens_draft.md
import 'package:flutter/material.dart';

/// 星巴克奶油主题颜色
class StarbucksCreamColors {
  // ... 按草案 2.1 节填写
}

/// 星巴克深绿主题颜色
class StarbucksDarkColors {
  // ... 按草案 2.2 节填写
}

/// 形状系统
class StarbucksShape {
  // ... 按草案第四节填写
}

/// 文字样式集
class StarbucksTypography {
  // ... 按草案第三节填写（含 _fallback 回退链）
}
```

### 2.2 字段清单（对齐 ThemeVars 30 个字段）

**starbucks_cream 预设值**（来源：`starbucks_tokens_draft.md` §5.1）：

| ThemeVars 字段 | 类型 | 新值 | 旧值（bright） | 变化说明 |
|---|---|---|---|---|
| `pageBg` | Color | `0xFFF2F0EB` | `0xFFF5F5F5` | 奶油画布 |
| `cardBg` | Color | `0xFFFFFFFF` | `0xFFFFFFFF` | 不变 |
| `cardBgAlt` | Color | `0xFFEDEBE9` | `0xFFF5F5F5` | 陶瓷画布 |
| `text1` | Color | `0xDE212121` | `0xDE000000` | #212121 替换纯黑 |
| `text2` | Color | `0x94212121` | `0x8A000000` | α 0.54→0.58 AA |
| `text3` | Color | `0x73212121` | `0x61000000` | α 0.38→0.45 |
| `divider` | Color | `0x14000000` | `0x14000000` | 不变 |
| `accent` | Color | `0xFF00754A` | `0xFFE8913A` | 品牌绿替换橙 |
| `success` | Color | `0xFF4CAF50` | `0xFF4CAF50` | 不变 |
| `danger` | Color | `0xFFE3303B` | `0xFFE3303B` | 不变 |
| `teal` | Color | `0xFF00754A` | `0xFF4A90E2` | 品牌绿替换蓝 |
| `tabBarIcon` | Color | `0xDE212121` | `0xDE000000` | 同 text1 |
| `onGlassText1` | Color | `0xDE212121` | — | 新增显式值 |
| `onGlassText2` | Color | `0x94212121` | — | 新增显式值 |
| `onGlassAccent` | Color | `0xFF00754A` | — | 新增显式值 |
| `glassBg` | Color | `0xFFFFFFFF` | — | 同 cardBg |
| `glassBgStrong` | Color | `0xFFFFFFFF` | — | 同 cardBg |
| `glassBorder` | Color | `0x14000000` | — | 同 divider |
| `wallpaperScrim` | Color | `0xFFF2F0EB` | — | 同 pageBg |
| `modalGlassBg` | Color | `0xFFFFFFFF` | — | 同 cardBg |
| `modalText1` | Color | `0xDE212121` | — | 同 text1 |
| `modalText2` | Color | `0x94212121` | — | 同 text2 |
| `quizCorrectBg` | Color | `0xFFD1FAE5` | `0xFFD1FAE5` | 不变 |
| `quizCorrectText` | Color | `0xFF4CAF50` | `0xFF4CAF50` | 不变 |
| `quizWrongBg` | Color | `0xFFFEE2E2` | `0xFFFEE2E2` | 不变 |
| `quizWrongText` | Color | `0xFFE3303B` | `0xFFE3303B` | 不变 |
| `vipGoldBg` | Color | `0xFFCBA258` | `0xFFFFD06A` | 品牌金 |
| `vipGoldText` | Color | `0xFFFFFFFF` | `0xFF1F1F1F` | 白字 |
| `profileDecor` | List | `[#D4E9E2, #EDEBE9]` | `[#F5F5F5, #E8E8E8]` | 浅绿+陶瓷 |

**starbucks_dark 预设值**（来源：`starbucks_tokens_draft.md` §5.2）：

| ThemeVars 字段 | 类型 | 新值 | 旧值（dark） | 变化说明 |
|---|---|---|---|---|
| `pageBg` | Color | `0xFF101B17` | `0xFF212532` | 墨绿近黑 |
| `cardBg` | Color | `0xFF1E3932` | `0xFF2E344A` | 深绿表面 |
| `cardBgAlt` | Color | `0xFF274A40` | `0xFF292F44` | 二级浮层 |
| `text1` | Color | `0xDEFFFFFF` | `0xDEFFFFFF` | 不变 |
| `text2` | Color | `0xFFA9BCB5` | `0x8AFFFFFF` | 固定色值（A11y 修正） |
| `text3` | Color | `0x73FFFFFF` | `0x61FFFFFF` | α 0.38→0.45 |
| `divider` | Color | `0x1FFFFFFF` | `0x33FFFFFF` | 12%→20% 白 |
| `accent` | Color | `0xFF00A862` | `0xFFF4A100` | 薄荷绿替换金 |
| `success` | Color | `0xFF22A18B` | `0xFF22A18B` | 不变 |
| `danger` | Color | `0xFFC64354` | `0xFFC64354` | 不变 |
| `teal` | Color | `0xFF00A862` | `0xFF4A90E2` | 薄荷绿替换蓝 |
| `tabBarIcon` | Color | `0xDEFFFFFF` | `0xDEFFFFFF` | 不变 |
| `onGlassText1` | Color | `0xDEFFFFFF` | `0xDEFFFFFF` | 不变 |
| `onGlassText2` | Color | `0xFFA9BCB5` | `0x8AFFFFFF` | 同 text2 |
| `onGlassAccent` | Color | `0xFF00A862` | `0xFFF4A100` | 同 accent |
| `glassBg` | Color | `0xFF1E3932` | — | 同 cardBg |
| `glassBgStrong` | Color | `0xFF274A40` | — | 浮层 |
| `glassBorder` | Color | `0x1FFFFFFF` | — | 同 divider |
| `wallpaperScrim` | Color | `0xFF101B17` | — | 同 pageBg |
| `modalGlassBg` | Color | `0xFF274A40` | — | 浮层 |
| `modalText1` | Color | `0xDEFFFFFF` | — | 同 text1 |
| `modalText2` | Color | `0xFFA9BCB5` | — | 同 text2 |
| `quizCorrectBg` | Color | `0xFF1A3D2E` | `0xFF1A3D2E` | 不变 |
| `quizCorrectText` | Color | `0xFF22A18B` | `0xFF22A18B` | 不变 |
| `quizWrongBg` | Color | `0xFF3D1A2E` | `0xFF3D1A2E` | 不变 |
| `quizWrongText` | Color | `0xFFC64354` | `0xFFC64354` | 不变 |
| `vipGoldBg` | Color | `0xFFCBA258` | `0xFFFFD06A` | 品牌金 |
| `vipGoldText` | Color | `0xFFFFFFFF` | `0xFF1F1F1F` | 白字 |
| `profileDecor` | List | `[#101B17, #1E3932]` | `[#212532, #292F44]` | 深绿体系 |

---

## 三、`lib/tokens/design_tokens.dart` 迁移方案

### 3.1 策略：过渡期别名

**原则**：63 个文件 import design_tokens.dart，不能一次性全部改动。采用**别名过渡期**：

1. 保留 `design_tokens.dart` 中所有旧类名（`MistralColors`、`AppleRadius` 等）
2. 旧类内部实现改为指向新 token
3. 新代码统一 import `starbucks_tokens.dart`

### 3.2 改动点清单

#### 3.2.1 `MistralColors` 类（design_tokens.dart:5-50）

| 旧字段 | 旧值 | 新值 | 说明 |
|---|---|---|---|
| `primary` | `0xFFE8913A` | `StarbucksCreamColors.greenBrand` | 过渡期指向品牌绿 |
| `primaryDeep` | `0xFFCC7A2E` | `0xFF006241` | 深绿 |
| `onPrimary` | `0xFFFFFFFF` | `0xFFFFFFFF` | 不变 |
| `primaryLight` | `0xFFE8913A` | `0xFF00754A` | 品牌绿 |
| `primaryDark` | `0xFFF4A100` | `0xFF00A862` | 薄荷绿 |
| `sunshine300` | `0xFFFFD06A` | `0xFFCBA258` | 品牌金 |
| `sunshine500` | `0xFFF4A100` | `0xFF00A862` | 薄荷绿 |
| `sunshine700` | `0xFFCC960C` | `0xFF006241` | 深绿 |
| `sunshine900` | `0xFFFF8A00` | `0xFF00754A` | 品牌绿 |
| `cream` | `0xFFF5F5F5` | `0xFFF2F0EB` | 奶油画布 |
| `creamLight` | `0xFFF5F5F5` | `0xFFF2F0EB` | 同上 |
| `creamDeeper` | `0xFFE8E8E8` | `0xFFEDEBE9` | 陶瓷画布 |
| `beigeDeep` | `0xFFE6D5A8` | `0xFFD4E9E2` | 浅绿 |
| `ink` | `0xFF1F1F1F` | `0xFF212121` | 正文黑 |
| `inkTint` | `0xFF3D3D3D` | `0xFF1E3932` | 深绿 |
| `charcoal` | `0xFF212532` | `0xFF101B17` | 墨绿近黑 |
| `slate` | `0xFF4A4A4A` | `0xFF274A40` | 浮层绿 |
| `steel` | `0xFF6A6A6A` | `0xFFA9BCB5` | 雾绿 |
| `stone` | `0xFF8A8A8A` | `0xFFA9BCB5` | 同上 |
| `muted` | `0xFFA8A8A8` | `0xFFD4E9E2` | 浅绿 |
| `hairline` | `0xFFE5E5E5` | `0x14000000` | 分割线 |
| `hairlineSoft` | `0xFFEDEDED` | `0x14000000` | 同上 |
| `canvas` | `0xFFFFFFFF` | `0xFFF2F0EB` | 奶油画布 |
| `surfaceCode` | `0xFF040404` | `0xFF101B17` | 墨绿 |
| `success` | `0xFF4CAF50` | `0xFF4CAF50` | 不变 |
| `successDark` | `0xFF22A18B` | `0xFF22A18B` | 不变 |
| `danger` | `0xFFE3303B` | `0xFFE3303B` | 不变 |
| `dangerDark` | `0xFFC64354` | `0xFFC64354` | 不变 |
| `warning` | `0xFFF59E0B` | `0xFFF59E0B` | 不变 |
| `link` | `0xFF4A90E2` | `0xFF00754A` | 品牌绿 |

#### 3.2.2 `AppleRadius` / `AppRadius` 类

无变化，圆角值已符合星巴克规范。

#### 3.2.3 `AppleSpacing` / `AppSpacing` 类

无变化，间距值已符合星巴克规范。

#### 3.2.4 `MistralTypography` / `AppTypography` 类

改动点：

| 旧字段 | 改动 | 说明 |
|---|---|---|
| 全部 TextStyle | 添加 `fontFamilyFallback: _fallback` | 中西文混排（来源 font_strategy.md） |
| `heroWord` | `color: Color(0xFF006241)` | 标题绿 |
| `heading1` | `color: Color(0xFF006241)` | 标题绿 |
| `heading2` | `color: Color(0xFF006241)` | 标题绿 |
| `body` / `bodyMd` | `color: Color(0xFF212121)` | 正文黑 |
| `bodySm` | `color: Color(0xFF212121)` | 正文黑 |
| `buttonMd` | `color: Color(0xFFFFFFFF)` | 按钮白字（暗色下用 onAccent） |

**letterSpacing 规则**：
- 纯西文 token（`heroWord`、音标）：`letterSpacing: -fontSize × 0.01`
- 含中文 token：不加 letterSpacing（避免汉字粘连）

#### 3.2.5 `AppColors` 兼容类

| 旧字段 | 新值 | 说明 |
|---|---|---|
| `successGreen` | `0xFF4CAF50` | 不变 |
| `highlightOrange` | `0xFF00754A` | 改为品牌绿 |
| `errorRed` | `0xFFE3303B` | 不变 |
| `black87` | `0xFF212121` | 正文黑 |
| `black54` | `0x94212121` | α=0.58 |
| `black12` | `0x14000000` | 8% 黑 |
| `white100` | `0xFFFFFFFF` | 不变 |
| `mainBgTop` | `0xFFF2F0EB` | 奶油画布 |
| `mainBgBottom` | `0xFFF2F0EB` | 同上 |
| `cardBg` | `0xFFFFFFFF` | 不变 |
| `dividerGrey` | `0x14000000` | 不变 |
| `textTertiary` | `0xFFA9BCB5` | 雾绿 |
| `checkInBg` | `0x3300754A` | 品牌绿 20% |
| `checkInAccent` | `0xFF00A862` | 薄荷绿 |
| `primary` | `0xFF00754A` | 品牌绿 |

---

## 四、`lib/theme/skin_system.dart` 扩展方案

### 4.1 新增两套预设

在 `themes` 表（:100-173）末尾追加：

```dart
// skin_system.dart:172 后追加
'starbucks_cream': ThemePreset(
  id: 'starbucks_cream',
  name: '星巴克奶油',
  uiBrightness: Brightness.light,
  statusBarBrightness: Brightness.dark,
  vars: ThemeVars(
    pageBg:       const Color(0xFFF2F0EB),
    cardBg:       const Color(0xFFFFFFFF),
    cardBgAlt:    const Color(0xFFEDEBE9),
    text1:        const Color(0xDE212121),
    text2:        const Color(0x94212121),
    text3:        const Color(0x73212121),
    divider:      const Color(0x14000000),
    accent:       const Color(0xFF00754A),
    success:      const Color(0xFF4CAF50),
    danger:       const Color(0xFFE3303B),
    teal:         const Color(0xFF00754A),
    tabBarIcon:   const Color(0xDE212121),
    onGlassText1: const Color(0xDE212121),
    onGlassText2: const Color(0x94212121),
    onGlassAccent: const Color(0xFF00754A),
    glassBg:      const Color(0xFFFFFFFF),
    glassBgStrong: const Color(0xFFFFFFFF),
    glassBorder:  const Color(0x14000000),
    wallpaperScrim: const Color(0xFFF2F0EB),
    modalGlassBg: const Color(0xFFFFFFFF),
    modalText1:   const Color(0xDE212121),
    modalText2:   const Color(0x94212121),
    quizCorrectBg:   const Color(0xFFD1FAE5),
    quizCorrectText: const Color(0xFF4CAF50),
    quizWrongBg:     const Color(0xFFFEE2E2),
    quizWrongText:   const Color(0xFFE3303B),
    vipGoldBg:    const Color(0xFFCBA258),
    vipGoldText:  const Color(0xFFFFFFFF),
    profileDecor: const [Color(0xFFD4E9E2), Color(0xFFEDEBE9)],
  ),
),
'starbucks_dark': ThemePreset(
  id: 'starbucks_dark',
  name: '星巴克深绿',
  uiBrightness: Brightness.dark,
  statusBarBrightness: Brightness.light,
  vars: ThemeVars(
    pageBg:       const Color(0xFF101B17),
    cardBg:       const Color(0xFF1E3932),
    cardBgAlt:    const Color(0xFF274A40),
    text1:        const Color(0xDEFFFFFF),
    text2:        const Color(0xFFA9BCB5),
    text3:        const Color(0x73FFFFFF),
    divider:      const Color(0x1FFFFFFF),
    accent:       const Color(0xFF00A862),
    success:      const Color(0xFF22A18B),
    danger:       const Color(0xFFC64354),
    teal:         const Color(0xFF00A862),
    tabBarIcon:   const Color(0xDEFFFFFF),
    onGlassText1: const Color(0xDEFFFFFF),
    onGlassText2: const Color(0xFFA9BCB5),
    onGlassAccent: const Color(0xFF00A862),
    glassBg:      const Color(0xFF1E3932),
    glassBgStrong: const Color(0xFF274A40),
    glassBorder:  const Color(0x1FFFFFFF),
    wallpaperScrim: const Color(0xFF101B17),
    modalGlassBg: const Color(0xFF274A40),
    modalText1:   const Color(0xDEFFFFFF),
    modalText2:   const Color(0xFFA9BCB5),
    quizCorrectBg:   const Color(0xFF1A3D2E),
    quizCorrectText: const Color(0xFF22A18B),
    quizWrongBg:     const Color(0xFF3D1A2E),
    quizWrongText:   const Color(0xFFC64354),
    vipGoldBg:    const Color(0xFFCBA258),
    vipGoldText:  const Color(0xFFFFFFFF),
    profileDecor: const [Color(0xFF101B17), Color(0xFF1E3932)],
  ),
),
```

### 4.2 旧预设保留/删除决策

| 预设 | 动作 | 理由 |
|---|---|---|
| `bright` | **保留** | 过渡期兼容，Batch 3+ 再决定是否删除 |
| `dark` | **保留** | 过渡期兼容 |
| `pure_black` | **保留** | 过渡期兼容 |

**迁移策略**：新预设追加到 `themes` 表，旧预设暂不删除，由产品决定何时下线。

### 4.3 `effectiveThemeId` 映射更新

skin_system.dart:218 的跟随系统映射需更新：

```dart
// 现有代码
String get effectiveThemeId {
  if (!_followSystem) return _themeId;
  return _systemBrightness == Brightness.dark ? 'pure_black' : 'bright';
}

// 改为（指向新预设）
String get effectiveThemeId {
  if (!_followSystem) return _themeId;
  return _systemBrightness == Brightness.dark ? 'starbucks_dark' : 'starbucks_cream';
}
```

---

## 五、验收标准

### 5.1 静态检查

```bash
flutter analyze --no-fatal-infos --no-fatal-warnings
# 期望：ERROR = 0
```

### 5.2 对比度测试

```bash
flutter test test/contrast_guard_test.dart
# 期望：全部通过
```

测试覆盖项：
- 亮色主题 7 组关键组合（cream 画布 + 白卡片）
- 暗色主题 6 组关键组合（三层深绿）
- α 红线验证（α<0.55 的组合应被拒绝）

### 5.3 视觉验收

| # | 验收项 | 操作 | 判据 |
|---|---|---|---|
| V1 | 亮色主题渲染 | 设置页选择「星巴克奶油」 | 奶油画布 #F2F0EB、品牌绿 CTA、标题绿 H1 |
| V2 | 暗色主题渲染 | 设置页选择「星巴克深绿」 | 三层深绿体系、薄荷绿强调、雾绿次要文字 |
| V3 | 跟随系统 | 打开跟随系统 → 切换系统深浅色 | 自动切换到 starbucks_cream / starbucks_dark |
| V4 | 旧预设兼容 | 选择「明亮」/「深邃」/「极夜」 | 仍可正常使用（过渡期） |

### 5.4 编译验证

```bash
# Windows 桌面
flutter build windows --debug
# Android
flutter build apk --debug
```

---

## 六、风险点与回滚方案

| # | 风险 | 影响 | 缓解/回滚 |
|---|---|---|---|
| R1 | **63 个文件 import design_tokens.dart**，别名改错导致编译失败 | 高 | 别名策略保证旧类名不变；编译失败即回滚 design_tokens.dart |
| R2 | **text2 暗色版改用固定色值 #A9BCB5**，但旧代码假设 text2 是半透明 | 中 | 新旧预设并存，旧代码走旧预设不受影响 |
| R3 | **followSystem 映射改到新预设**，但新预设可能还未被 AppearancePage 显示 | 中 | Batch 3 外观页改造时同步处理；暂不影响功能 |
| R4 | **vipGoldText 从黑字改白字**，成就页可能有硬编码背景色 | 低 | 对比度已验证 5.25:1 AA 达标 |
| R5 | **MistralTypography 改动范围大**，加 fontFamilyFallback 可能影响布局 | 中 | 逐页面走查，重点检查 heroWord（38-40px）和按钮 |
| R6 | **contrast_guard_test 可能需要更新阈值** | 低 | 测试文件位于 test/，改动不影响生产代码 |

### 回滚方案

1. **快速回滚**：`git revert` 最后 1-3 个 commit
2. **分层回滚**：
   - 只回滚 `skin_system.dart`：删除新增的 `starbucks_cream` / `starbucks_dark` 预设
   - 只回滚 `design_tokens.dart`：恢复旧色值
   - `starbucks_tokens.dart` 可独立删除（无其他文件依赖）
3. **数据兼容**：新预设 ID 不与旧预设冲突，用户已选的旧主题不受影响

---

## 七、实施顺序建议

| 步骤 | 文件 | 动作 | 依赖 |
|---|---|---|---|
| 1 | `lib/tokens/starbucks_tokens.dart` | 新建 | 无 |
| 2 | `lib/theme/skin_system.dart` | 新增预设 + 更新 effectiveThemeId | 步骤 1 |
| 3 | `lib/tokens/design_tokens.dart` | 添加别名 | 步骤 1 |
| 4 | 运行 `flutter analyze` | 验证 ERROR=0 | 步骤 1-3 |
| 5 | 运行 `flutter test test/contrast_guard_test.dart` | 验证对比度 | 步骤 1-3 |
| 6 | 视觉走查 | 选择新预设验证渲染 | 步骤 1-3 |

**预估工时**：2-3 小时（含测试和走查）

---

## 八、后续批次依赖

| 批次 | 依赖本批次的内容 |
|---|---|
| Batch 3 | 外观页显示新预设选项 |
| Batch 4+ | 页面代码迁移：`context.skin.colors.accent` → `StarbucksCreamColors.greenBrand` |

---

*规格制定人：TokenEngineer · 2026-08-24*
*基于 commit 实测行号，若 Batch 1 已合码请先校准行号偏移*
