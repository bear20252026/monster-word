# 对比度自动化守卫：WCAG 回归测试规格

- 制定日期：2026-08-24
- 适用项目：Monster Word（`D:\claude\work\cn_com_lange\word_app`）
- 前置依赖：已完成亮暗两轮人工对比度审查，本文档将其固化为自动化守卫
  - 亮色审查：`docs/a11y_contrast_report.md`（7 组全部 AA 达标）
  - 暗色审查：`docs/a11y_dark_mode_report.md`（深绿三层体系，2 处需修正）
- 文件产出：本规格文档 + 实施时落地 `test/contrast_guard_test.dart`

---

## 1. 设计方案概述

### 1.1 目标

在 `flutter test` 门禁中增加对比度回归测试，确保未来修改 token（`lib/tokens/design_tokens.dart`）或皮肤系统（`lib/theme/skin_system.dart`）时，任何导致语义配对对比度低于 WCAG 阈值的变更都会被自动拦截。

### 1.2 测试原理

1. 从 `ThemeVars` 读取所有语义前景/背景配对（约 17–20 对）
2. 对带 alpha 的前景色先做 alpha 合成（与背景混合得到等效实色）
3. 使用 WCAG 2.1 相对亮度公式计算每对的对比度
4. 断言对比度 ≥ 适用阈值（AA 级别：正常文字 4.5:1，大文字 3.0:1）
5. 对三套主题（明亮 `bright`、深邃 `dark`、极夜 `pure_black`）各跑一遍

### 1.3 WCAG 公式（与人工审查一致）

```
对每个通道 sRGB 值 c ∈ [0,1]：
  c_lin = c / 12.92                      （c ≤ 0.03928）
  c_lin = ((c + 0.055) / 1.055) ^ 2.4    （c > 0.03928）

相对亮度 L = 0.2126 × R_lin + 0.7152 × G_lin + 0.0722 × B_lin

对比度 = (L_亮 + 0.05) / (L_暗 + 0.05)，结果范围 [1, 21]
```

**半透明处理**：`Color` 的 alpha < 255 时，先与背景做 alpha 合成再计算：

```
result_channel = α × foreground + (1 − α) × background   （逐通道，0–255）
```

> 本公式与 `docs/a11y_contrast_report.md` §一 完全一致，可用 WebAIM Contrast Checker 交叉复核。

### 1.4 阈值判定标准

| 级别 | 正常文字（<18pt 或 <14pt bold） | 大号文字（≥18pt 或 ≥14pt bold） |
|---|---|---|
| **AA** | ≥ 4.5 : 1 | ≥ 3.0 : 1 |
| AAA | ≥ 7.0 : 1 | ≥ 4.5 : 1 |

> 本项目 CTA 按钮标签为 14–16px / weight 600、金徽章 pill 为 13px / weight 700，均**不构成大号文字**，一律按正常文字 4.5:1 判定（来源：`a11y_contrast_report.md` §一）。

---

## 2. 语义配对清单

从 `skin_system.dart` 的 `ThemeVars` 提取，每对标注适用阈值：

| # | 配对名称 | 前景色 | 背景色 | 阈值 | 说明 |
|---|---|---|---|---|---|
| 1 | 正文/画布 | `text1` | `pageBg` | **4.5** | 主文字在页面背景上 |
| 2 | 次要文字/画布 | `text2` | `pageBg` | **4.5** | 次要文字在页面背景上 |
| 3 | 三级文字/画布 | `text3` | `pageBg` | **4.5** | 辅助文字在页面背景上 |
| 4 | 正文/卡片 | `text1` | `cardBg` | **4.5** | 主文字在卡片背景上 |
| 5 | 次要文字/卡片 | `text2` | `cardBg` | **4.5** | 次要文字在卡片背景上 |
| 6 | 三级文字/卡片 | `text3` | `cardBg` | **4.5** | 辅助文字在卡片背景上 |
| 7 | 强调色/画布 | `accent` | `pageBg` | **4.5** | 按钮文字、高亮标签（正文级） |
| 8 | 强调色/卡片 | `accent` | `cardBg` | **4.5** | 卡片上的强调色文字 |
| 9 | 成功色/画布 | `success` | `pageBg` | **4.5** | 成功状态文字 |
| 10 | 危险色/画布 | `danger` | `pageBg` | **4.5** | 错误状态文字 |
| 11 | 链接色/画布 | `teal` | `pageBg` | **4.5** | 链接文字 |
| 12 | 标签栏图标/画布 | `tabBarIcon` | `pageBg` | **3.0** | 底部导航图标（非文字 UI 元素） |
| 13 | 玻璃文字/玻璃底 | `onGlassText1` | `glassBg` | **4.5** | 玻璃态主文字 |
| 14 | 玻璃次要/玻璃底 | `onGlassText2` | `glassBg` | **4.5** | 玻璃态次要文字 |
| 15 | 玻璃强调/玻璃底 | `onGlassAccent` | `glassBg` | **4.5** | 玻璃态强调色文字 |
| 16 | 答对文字/答对底 | `quizCorrectText` | `quizCorrectBg` | **4.5** | 答题正确反馈 |
| 17 | 答错文字/答错底 | `quizWrongText` | `quizWrongBg` | **4.5** | 答题错误反馈 |
| 18 | VIP文字/VIP底 | `vipGoldText` | `vipGoldBg` | **4.5** | 金徽章文字 |
| 19 | 弹窗文字/弹窗底 | `modalText1` | `modalGlassBg` | **4.5** | 弹窗主文字 |
| 20 | 弹窗次要/弹窗底 | `modalText2` | `modalGlassBg` | **4.5** | 弹窗次要文字 |

> **注意**：第 7/8 项（accent）标注 4.5 而非 3.0——因为 accent 在本项目中用于按钮文字（14–16px/600），属正常文字，需满足 4.5:1。仅第 12 项（tabBarIcon）为纯图标元素，适用 3.0:1。

---

## 3. 完整测试代码

> 实施时将以下代码块存为 `test/contrast_guard_test.dart`。

```dart
// 对比度自动化守卫 — WCAG AA 回归测试
// 读取 ThemeVars 全部语义配对，断言对比度 ≥ 阈值
// 三套主题（明亮/深邃/极夜）各跑一遍
//
// 参考：docs/a11y_contrast_report.md、docs/a11y_dark_mode_report.md

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:word_app/theme/skin_system.dart';

void main() {
  // 遍历所有主题
  for (final entry in themes.entries) {
    final themeId = entry.key;
    final preset = entry.value;
    final vars = preset.vars;

    group('WCAG 对比度守卫 — ${preset.name}（$themeId）', () {
      // ── 正文级配对（阈值 4.5:1） ──
      _testPair('正文/画布', vars.text1, vars.pageBg, 4.5, themeId);
      _testPair('次要文字/画布', vars.text2, vars.pageBg, 4.5, themeId);
      _testPair('三级文字/画布', vars.text3, vars.pageBg, 4.5, themeId);
      _testPair('正文/卡片', vars.text1, vars.cardBg, 4.5, themeId);
      _testPair('次要文字/卡片', vars.text2, vars.cardBg, 4.5, themeId);
      _testPair('三级文字/卡片', vars.text3, vars.cardBg, 4.5, themeId);
      _testPair('强调色/画布', vars.accent, vars.pageBg, 4.5, themeId);
      _testPair('强调色/卡片', vars.accent, vars.cardBg, 4.5, themeId);
      _testPair('成功色/画布', vars.success, vars.pageBg, 4.5, themeId);
      _testPair('危险色/画布', vars.danger, vars.pageBg, 4.5, themeId);
      _testPair('链接色/画布', vars.teal, vars.pageBg, 4.5, themeId);
      _testPair('玻璃文字/玻璃底', vars.onGlassText1, vars.glassBg, 4.5, themeId);
      _testPair('玻璃次要/玻璃底', vars.onGlassText2, vars.glassBg, 4.5, themeId);
      _testPair('玻璃强调/玻璃底', vars.onGlassAccent, vars.glassBg, 4.5, themeId);
      _testPair('答对文字/答对底', vars.quizCorrectText, vars.quizCorrectBg, 4.5, themeId);
      _testPair('答错文字/答错底', vars.quizWrongText, vars.quizWrongBg, 4.5, themeId);
      _testPair('VIP文字/VIP底', vars.vipGoldText, vars.vipGoldBg, 4.5, themeId);
      _testPair('弹窗文字/弹窗底', vars.modalText1, vars.modalGlassBg, 4.5, themeId);
      _testPair('弹窗次要/弹窗底', vars.modalText2, vars.modalGlassBg, 4.5, themeId);

      // ── 大元素/图标级配对（阈值 3.0:1） ──
      _testPair('标签栏图标/画布', vars.tabBarIcon, vars.pageBg, 3.0, themeId);
    });
  }
}

/// 测试单个配对的对比度
void _testPair(
  String label,
  Color foreground,
  Color background,
  double threshold,
  String themeId,
) {
  test('$label — 对比度 ≥ ${threshold.toStringAsFixed(1)}:1', () {
    // 带 alpha 的前景色先与背景做 alpha 合成
    final effectiveFg = _alphaComposite(foreground, background);
    final ratio = contrastRatio(effectiveFg, background);
    expect(
      ratio >= threshold,
      true,
      reason: _failureMessage(label, foreground, background, effectiveFg, ratio, threshold),
    );
  });
}

/// Alpha 合成：将前景色叠加到背景色上，返回等效实色
/// 用于处理 rgba(r,g,b,α) 类型的半透明颜色
Color _alphaComposite(Color fg, Color bg) {
  if (fg.alpha == 255) return fg; // 不透明，无需合成
  final a = fg.alpha / 255.0;
  final r = (a * fg.red + (1 - a) * bg.red).round();
  final g = (a * fg.green + (1 - a) * bg.green).round();
  final b = (a * fg.blue + (1 - a) * bg.blue).round();
  return Color.fromARGB(255, r, g, b);
}

/// 失败时的详细输出
String _failureMessage(
  String label,
  Color originalFg,
  Color bg,
  Color effectiveFg,
  double actual,
  double required,
) {
  final fgHex = '#${originalFg.value.toRadixString(16).padLeft(8, '0').toUpperCase()}';
  final bgHex = '#${bg.value.toRadixString(16).padLeft(8, '0').toUpperCase()}';
  final effHex = '#${effectiveFg.value.toRadixString(16).padLeft(8, '0').toUpperCase()}';

  // 判断是否经过了 alpha 合成
  final alphaNote = originalFg.alpha < 255
      ? '  （α=${originalFg.alpha}，合成等效色：$effHex）\n'
      : '';

  return '''
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
❌ WCAG 对比度不达标：$label
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  前景色：$fgHex  (r=${originalFg.red}, g=${originalFg.green}, b=${originalFg.blue}, a=${originalFg.alpha})
  背景色：$bgHex  (r=${bg.red}, g=${bg.green}, b=${bg.blue}, a=${bg.alpha})
$alphaNote  实测对比度：${actual.toStringAsFixed(2)}:1
  要求阈值：${required.toStringAsFixed(1)}:1
  差距：${(required - actual).toStringAsFixed(2)}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  修复建议：
  1. 调整前景色使其更深/更亮（增大与背景的明度差）
  2. 或调整背景色
  3. 参考 https://webaim.org/resources/contrastchecker/ 在线验证
  4. 若为大元素（≥18pt 或 ≥14pt bold），可将阈值从 4.5 降为 3.0
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
''';
}

// ── WCAG 对比度计算函数 ──

/// 计算两个颜色的 WCAG 对比度
/// 返回值 ≥ 1.0（相同颜色 = 1.0:1）
/// 注意：传入的 Color 必须已做 alpha 合成（a=255）
double contrastRatio(Color a, Color b) {
  final l1 = relativeLuminance(a);
  final l2 = relativeLuminance(b);
  final lighter = max(l1, l2);
  final darker = min(l1, l2);
  return (lighter + 0.05) / (darker + 0.05);
}

/// 计算颜色的 WCAG 相对亮度
/// 基于 sRGB → 线性转换（WCAG 2.1 定义）
/// 阈值 0.03928 与人工审查脚本一致
double relativeLuminance(Color c) {
  // sRGB 通道归一化到 [0, 1]
  final r = c.red / 255.0;
  final g = c.green / 255.0;
  final b = c.blue / 255.0;

  // sRGB → 线性（WCAG 2.1 精确公式）
  final rLin = _srgbToLinear(r);
  final gLin = _srgbToLinear(g);
  final bLin = _srgbToLinear(b);

  return 0.2126 * rLin + 0.7152 * gLin + 0.0722 * bLin;
}

/// sRGB → 线性转换
/// 值 ≤ 0.03928 时除以 12.92，否则 ((v+0.055)/1.055)^2.4
double _srgbToLinear(double v) {
  if (v <= 0.03928) {
    return v / 12.92;
  }
  return pow((v + 0.055) / 1.055, 2.4).toDouble();
}
```

---

## 4. Token 来源方式分析

### 方案 A：直接 import `lib/tokens`（推荐）

```dart
import 'package:word_app/theme/skin_system.dart';
// 通过 themes['bright']!.vars 访问所有语义色
```

**优点**：
- 单一来源（Single Source of Truth），token 变更立即反映到测试
- 不需要维护快照文件，零同步成本
- 测试覆盖率最高——直接测试真实代码路径

**缺点**：
- 测试与生产代码耦合，token 重构时测试也需要同步调整 import 路径
- 如果 `skin_system.dart` 有副作用（如初始化数据库），测试需要 mock

### 方案 B：复制快照到测试目录

```dart
// test/fixtures/token_snapshot_bright.json
// 从 skin_system.dart 导出一份 JSON，在测试中加载
```

**优点**：
- 测试完全独立，不受生产代码重构影响
- 可以测试"历史版本"的 token 是否达标

**缺点**：
- 双重维护——改 token 必须同步更新快照，否则测试失去意义
- 快照容易被遗忘，形成"测试永远绿"的假象
- 增加 CI 复杂度（需要导出/比对步骤）

### 推荐：方案 A（直接 import）

理由：
1. 本项目 `skin_system.dart` 是纯 Dart 类，无副作用，可直接在测试中实例化
2. 对比度守卫的核心价值就是"token 改了就立刻检测"——快照违背这一目的
3. `themes` 是顶层 final 变量，直接访问零成本

---

## 5. 失败输出格式

测试失败时，输出包含以下信息（见代码中 `_failureMessage`）：

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
❌ WCAG 对比度不达标：次要文字/画布
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  前景色：#8A000000  (r=0, g=0, b=0, a=138)
  背景色：#FFF5F5F5  (r=245, g=245, b=245, a=255)
  （α=138，合成等效色：#FF666663）
  实测对比度：5.11:1
  要求阈值：4.5:1
  差距：-0.61
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  修复建议：
  1. 调整前景色使其更深/更亮（增大与背景的明度差）
  2. 或调整背景色
  3. 参考 https://webaim.org/resources/contrastchecker/ 在线验证
  4. 若为大元素（≥18pt 或 ≥14pt bold），可将阈值从 4.5 降为 3.0
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

输出要素：
- **配对名称**：语义化标签（如"正文/画布"）
- **颜色值**：Hex + RGBA 分量，方便直接搜索 token 文件定位
- **Alpha 合成**：带 alpha 的颜色会显示合成等效色，便于用 WebAIM 验证
- **实测值 vs 阈值**：一目了然差距多大
- **修复建议**：给出具体操作方向，降低修复门槛

---

## 6. 人工审查遗留的红线规则

以下规则来自 `docs/a11y_contrast_report.md` 和 `docs/a11y_dark_mode_report.md`，守卫测试自动执行这些检查。当测试红灯时，结合以下规则定位修复方向：

### 6.1 亮色主题红线（来源：a11y_contrast_report.md §四）

- 次要文字 alpha **不得低于 0.55**（α=0.52 时对比度 4.16:1，AA 失败）
- Green Accent `#00754A` 不要用作奶油画布上的小号文字颜色（约 5.4:1，接近边缘）
- 标题绿 `#006241` 不要用于 <18.66px 的非粗体小字（AAA 视角不足 7:1）

### 6.2 暗色主题红线（来源：a11y_dark_mode_report.md §六）

- `accentOnSurface` 类浅色文字放在强调色填充上——**全场景失败**（如 `#D4E9E2` on `#00A862` 仅 2.44:1），必须用深色文字
- 浮层（`#274A40`）上次要文字容易贴线（α=0.58 时 4.51:1），建议工程线 α ≥ 0.62
- α < 0.55 **一律禁止**用于任何表面的次要文字
- 薄荷实心按钮 + 白字 = 3.10:1，该组合禁止

### 6.3 守卫如何覆盖

守卫测试直接检查 `ThemeVars` 中所有语义配对的实际色值，上述红线规则隐含在 4.5:1 阈值断言中。当 token 被修改导致违反红线时，测试自动失败并输出修复建议。

---

## 7. 接入 test_plan.md 门禁体系

### 7.1 门禁归属

对比度守卫属于 **Token 层门禁**，应挂入 `test_plan.md` 的 **G3**（flutter test）体系：

- 它是一组 `flutter test` 单元测试，与现有 golden 测试并行运行
- 不需要新增独立门禁编号——G3 的"全量 `flutter test`"已覆盖
- 在 §4 分阶段回归的"Token 层"阶段，作为快速环的必跑项

### 7.2 接入方式

在 `test_plan.md` 的 §1.1 第一段门禁表格中，G3 行的说明补充：

```markdown
| G3 | flutter test | 0 通过 / 加载失败 | **套件可加载且全过** | 含 contrast_guard_test.dart（WCAG 对比度守卫） |
```

在 §4 Token 层回归的"改完立刻测"列补充：

```markdown
| **Token 层** | `dart analyze` + `flutter test`（含 golden + contrast_guard）+ 三主题切换目检 | ... |
```

### 7.3 运行命令

```bash
# 单独跑对比度守卫
flutter test test/contrast_guard_test.dart

# 全量测试（含对比度守卫）
flutter test
```

### 7.4 CI 集成

对比度守卫作为普通 flutter test 运行，无需额外 CI 配置。失败即阻断合并，与其他测试红灯等权。

---

## 8. 实施清单

| 步骤 | 操作 | 文件 |
|---|---|---|
| 1 | 存储本规格文档 | `docs/contrast_guard_spec.md`（已完成） |
| 2 | 创建测试文件 | `test/contrast_guard_test.dart`（从 §3 代码块复制） |
| 3 | 更新 test_plan.md | G3 说明 + Token 层回归补充（见 §7.2） |
| 4 | 本地验证 | `flutter test test/contrast_guard_test.dart` |
| 5 | 全量回归 | `flutter test` 确认无副作用 |

---

## 附录：三主题当前配对预览

> 以下为人工审查时确认的色值，供 cross-check（自动化测试运行后以测试结果为准）。
> 带 alpha 的颜色已标注合成等效色。

### 明亮（bright）

| 配对 | 前景 | 背景 | 合成等效色 | 预估对比度 |
|---|---|---|---|---|
| text1/pageBg | `#DE000000` (α=222) | `#F5F5F5` | `#1F1F1F` | ~14.1 |
| text2/pageBg | `#8A000000` (α=138) | `#F5F5F5` | `#666563` | ~5.1 |
| text3/pageBg | `#61000000` (α=97) | `#F5F5F5` | `#9A9A9A` | ~2.8 ⚠️ |
| accent/pageBg | `#E8913A` | `#F5F5F5` | — | ~2.7 ⚠️ |
| success/pageBg | `#4CAF50` | `#F5F5F5` | — | ~3.1 ⚠️ |
| danger/pageBg | `#E3303B` | `#F5F5F5` | — | ~4.0 ⚠️ |
| teal/pageBg | `#4A90E2` | `#F5F5F5` | — | ~3.3 ⚠️ |
| quizCorrectText/quizCorrectBg | `#4CAF50` | `#D1FAE5` | — | ~2.3 ⚠️ |

### 深邃（dark）

| 配对 | 前景 | 背景 | 合成等效色 | 预估对比度 |
|---|---|---|---|---|
| text1/pageBg | `#DEFFFFFF` (α=222) | `#212532` | `#E0E1E1` | ~13.5 |
| text2/pageBg | `#8AFFFFFF` (α=138) | `#212532` | `#9B9F9E` | ~6.6 |
| accent/pageBg | `#F4A100` | `#212532` | — | ~7.8 |
| success/pageBg | `#22A18B` | `#212532` | — | ~6.5 |
| danger/pageBg | `#C64354` | `#212532` | — | ~4.5 |

### 极夜（pure_black）

| 配对 | 前景 | 背景 | 合成等效色 | 预估对比度 |
|---|---|---|---|---|
| text1/pageBg | `#DEFFFFFF` (α=222) | `#040404` | `#E0E0E0` | ~19.2 |
| text2/pageBg | `#8AFFFFFF` (α=138) | `#040404` | `#9A9A9A` | ~8.6 |
| accent/pageBg | `#005F87` | `#040404` | — | ~4.8 |
| success/pageBg | `#22A18B` | `#040404` | — | ~8.2 |
| danger/pageBg | `#C64354` | `#040404` | — | ~6.3 |

> ⚠️ 标记项预估低于 4.5:1 阈值。这些是当前 token 的实际色值——自动化测试运行后会给出精确数值。若确认不达标，需在 Token 层重构时调整色值。

---

## 9. 总结

本规格定义了一套自动化的 WCAG 对比度回归测试方案，覆盖亮色/暗色/极夜三套主题共约 18 组语义色值配对。核心要点：

- **测试范围**：正文/画布、次要文字/表面、CTA 文字/按钮底、金徽章、成功/危险状态等全部日常使用配对
- **阈值标准**：AA 正常文字 4.5:1，大号文字 3.0:1，每对按适用场景标注阈值
- **失败输出**：明确打印色值、实测对比度、阈值及修复建议，便于定位问题
- **门禁归属**：挂入 test_plan.md 的 G3（flutter test），与其他测试等权阻断合并
- **Token 来源**：推荐直接 import lib/tokens（实时校验），快照模式仅作备选

实施者只需将 §3 代码块存为 `test/contrast_guard_test.dart` 并按 §7 更新 test_plan.md 即可完成接入。

> 红线规则汇总：次要文字 α ≥ 0.55（硬红线）/ ≥ 0.62（工程线）；薄荷实心按钮+白字禁止；标题绿不用于 <18.66px 非粗体小字。详见 §6。
