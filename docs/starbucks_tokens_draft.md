# Starbucks 双主题 Token 草案

> 项目：Monster Word (word_app)
> 方案：方案C（画布归品牌，装饰归个性）—— 来源 `docs/dark_skin_strategy.md`
> 日期：2026-08-24
> 约束：本文件为草案，内嵌 dart 代码块，不创建 .dart 文件

---

## 一、设计原则

1. **画布归品牌**：页面/卡片背景使用星巴克经典色值（奶油画布 #f2f0eb / #edebe9）
2. **装饰归个性**：强调色保留用户选择的个性主题色
3. **A11y 优先**：文字透明度遵循 A11y 报告红线
   - 亮色：次要文字 α≥0.58，不低于 0.55（来源 `docs/a11y_contrast_report.md`）
   - 暗色：工程安全线 α≥0.62，禁止 α<0.55（来源 `docs/a11y_dark_mode_report.md`）
4. **昼夜语义反转**：亮色"奶油=画布、深绿=强调"；暗色"深绿=表面、奶油=前景强调"

---

## 二、颜色令牌全集

### 2.1 亮色主题（starbucks_cream）

```dart
/// 星巴克奶油主题 — 画布归品牌
class StarbucksCreamColors {
  // ─── 画布（品牌专属）──────────────────────────────────
  static const Color canvas        = Color(0xFFF2F0EB);  // 奶油画布（主背景）
  static const Color canvasAlt     = Color(0xFFEDEBE9);  // 陶瓷画布（次级/分割）
  static const Color surface       = Color(0xFFFFFFFF);  // 白卡片

  // ─── 品牌绿（四层）────────────────────────────────────
  static const Color greenLight    = Color(0xFFD4E9E2);  // 浅绿（背景/选中态）
  static const Color greenBrand    = Color(0xFF00754A);  // 品牌绿（CTA/描边/链接）
  static const Color greenTitle    = Color(0xFF006241);  // 标题绿（标题/强调文字）
  static const Color greenDark     = Color(0xFF1E3932);  // 墨绿（深底/横幅）

  // ─── 金色（成就专属）───────────────────────────────────
  static const Color gold          = Color(0xFFCBA258);  // 成就/奖励金色
  static const Color goldLight     = Color(0xFFDFC49D);  // 浅金（AAA 级深底文字）

  // ─── 文字（α 阶梯 — 亮色）────────────────────────────
  // A11y 报告红线：α≥0.58 为 AA 达标，α<0.55 禁止
  static const Color text1         = Color(0xDE212121);  // 主文字 α=0.87（14.14:1 AAA）
  static const Color text2         = Color(0x94212121);  // 次要文字 α=0.58（5.11:1 AA）
  static const Color text3         = Color(0x73212121);  // 三级文字 α=0.45（仅装饰/禁用态）

  // ─── 状态色 ─────────────────────────────────────────────
  static const Color success       = Color(0xFF4CAF50);  // 成功
  static const Color danger        = Color(0xFFE3303B);  // 错误
  static const Color warning       = Color(0xFFF59E0B);  // 警告

  // ─── 分割线/表面 ───────────────────────────────────────
  static const Color divider       = Color(0x14000000);  // 8% 黑
  static const Color dividerStrong = Color(0x29000000);  // 16% 黑

  // ─── Tab Bar ─────────────────────────────────────────────
  static const Color tabBarIcon    = text1;
}
```

**A11y 验证**（来源：`docs/a11y_contrast_report.md`）：

| 组合 | 对比度 | 判定 |
|---|---|---|
| 主文字 α=0.87 on cream | 14.14:1 | AAA ✅ |
| 次要文字 α=0.58 on cream | 5.11:1 | AA ✅ |
| 标题绿 #006241 on cream | 6.53:1 | AA ✅（大字 AAA） |
| 品牌绿 #00754A on 白 | 5.76:1 | AA ✅ |
| 金 #CBA258 on 深绿 | 5.25:1 | AA ✅ |

---

### 2.2 暗色主题（starbucks_dark）

```dart
/// 星巴克深绿主题 — 三层深绿体系
/// 设计来源：docs/dark_skin_strategy.md 第四节
class StarbucksDarkColors {
  // ─── 三层深绿体系 ─────────────────────────────────────
  static const Color canvas        = Color(0xFF101B17);  // 画布（墨绿近黑，L=0.0096）
  static const Color surface       = Color(0xFF1E3932);  // 表面/卡片（品牌深绿，L=0.0343）
  static const Color surfaceHigh   = Color(0xFF274A40);  // 二级浮层（弹窗/菜单，L=0.0570）

  // ─── 品牌绿（暗色版）──────────────────────────────────
  static const Color greenLight    = Color(0xFFD4E9E2);  // 浅绿（装饰/背景）
  static const Color greenBrand    = Color(0xFF00A862);  // 薄荷绿强调（CTA/图标/描边）
  static const Color greenTitle    = Color(0xFF006241);  // 标题绿（白底 CTA 文字）
  static const Color greenDark     = Color(0xFF1E3932);  // 墨绿（同 surface）
  static const Color greenSmall    = Color(0xFF00C77F);  // 卡片小字强调绿（AA 达标）

  // ─── 金色（成就专属）───────────────────────────────────
  static const Color gold          = Color(0xFFCBA258);  // 金色（5.25:1 on surface AA）
  static const Color goldLight     = Color(0xFFDFC49D);  // 浅金（7.42:1 AAA，浮层必用）

  // ─── 文字（固定色值 — 暗色版）────────────────────────
  // 暗色不用 α 合成，直接用 A11y 报告验证过的固定色值
  static const Color text1         = Color(0xDEFFFFFF);  // 主文字 α=0.87（画布 13.45:1 AAA）
  static const Color text2         = Color(0xFFA9BCB5);  // 次要文字（浮层 4.93:1 AA）
  static const Color text3         = Color(0x73FFFFFF);  // 三级文字 α=0.45（仅装饰）

  // ─── 强调色上的文字 ────────────────────────────────────
  // ⚠️ A11y 红线：#D4E9E2 on #00A862 = 2.44:1 ❌ 全场景失败
  // 正确方案：用深色文字 #101B17 on #00A862 = 5.69:1 ✅
  static const Color onAccent      = Color(0xFF101B17);  // 薄荷底上的文字

  // ─── 状态色（深色版）──────────────────────────────────
  static const Color success       = Color(0xFF22A18B);  // 成功（深色版青绿）
  static const Color danger        = Color(0xFFC64354);  // 错误（深色版玫红）
  static const Color warning       = Color(0xFFF59E0B);  // 警告

  // ─── 分割线/表面 ───────────────────────────────────────
  static const Color divider       = Color(0x1FFFFFFF);  // 12% 白
  static const Color dividerStrong = Color(0x33FFFFFF);  // 20% 白

  // ─── Tab Bar ─────────────────────────────────────────────
  static const Color tabBarIcon    = text1;
}
```

**暗色 A11y 验证**（来源：`docs/a11y_dark_mode_report.md`）：

| 组合 | 对比度 | 判定 |
|---|---|---|
| 主文字 α=0.87 on 画布 | 13.45:1 | AAA ✅ |
| 主文字 α=0.87 on 表面 | 9.82:1 | AAA ✅ |
| 主文字 α=0.87 on 浮层 | 7.87:1 | AAA ✅ |
| 次要文字 #A9BCB5 on 浮层 | 4.93:1 | AA ✅（原 #9DB0A9 仅 4.31 ❌） |
| 薄荷绿 #00A862 on 画布 | 5.69:1 | AA ✅ |
| 薄荷绿 #00A862 on 表面 | 4.02:1 | ❌ 仅大字/图标 |
| 白字 on 表面 | 12.45:1 | AAA ✅ |
| 金 #CBA258 on 表面 | 5.25:1 | AA ✅ |
| 浅金 #DFC49D on 浮层 | 5.85:1 | AA ✅ |

**⚠️ 暗色版必须避免的组合**：
- `#D4E9E2` on `#00A862` = 2.44:1 ❌（全场景失败）
- `#006241` on `#00A862` = 2.40:1 ❌（深绿配薄荷不行）
- 白字 on `#00A862` = 3.10:1 ❌（薄荷实心按钮禁用白字）
- `#00A862` on 表面小号文字 = 4.02:1 ❌（卡片小字用 #00C77F）

---

## 三、文字样式集

> 来源：`docs/font_strategy.md`
> 字体：Inter（已捆绑 4 字重：Regular 400 / Medium 500 / SemiBold 600 / Bold 700）
> 中文回退链：PingFang SC → Microsoft YaHei → Noto Sans SC

```dart
/// 文字样式集 — 基于 Inter
class StarbucksTypography {
  // ─── 中西文混排基础回退 ────────────────────────────────
  static const List<String> _fallback = <String>[
    'PingFang SC',        // iOS / macOS
    'Microsoft YaHei',    // Windows
    'Noto Sans SC',       // Android / Linux
    'Source Han Sans SC', // 兜底
  ];

  // ─── Display / Hero ──────────────────────────────────────
  /// 英文单词主角（40px / w700），学习/复习会话核心单词
  /// letterSpacing: -0.01em @40px = -0.40，仅西文
  static const TextStyle heroWord = TextStyle(
    fontFamily: 'Inter',
    fontFamilyFallback: _fallback,
    fontSize: 40,
    fontWeight: FontWeight.w700,
    height: 1.15,
    letterSpacing: -0.40,
  );

  /// Hero Display（52px / w700），大标题
  static const TextStyle heroDisplay = TextStyle(
    fontFamily: 'Inter',
    fontFamilyFallback: _fallback,
    fontSize: 52,
    fontWeight: FontWeight.w700,
    height: 1.10,
    letterSpacing: -0.52,
  );

  // ─── Headings ──────────────────────────────────────────────
  /// H1 标题（24px / w600），用绿色 #006241
  /// A11y：大号文字 24px/600 = 大字标准，6.53:1 满足 AAA 大字
  static const TextStyle h1 = TextStyle(
    fontFamily: 'Inter',
    fontFamilyFallback: _fallback,
    fontSize: 24,
    fontWeight: FontWeight.w600,
    height: 1.25,
    color: Color(0xFF006241),
  );

  /// H2 标题（20px / w600）
  static const TextStyle h2 = TextStyle(
    fontFamily: 'Inter',
    fontFamilyFallback: _fallback,
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 1.30,
    color: Color(0xFF006241),
  );

  /// H3 标题（18px / w600）
  static const TextStyle h3 = TextStyle(
    fontFamily: 'Inter',
    fontFamilyFallback: _fallback,
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 1.35,
  );

  /// H4 标题（16px / w600）
  static const TextStyle h4 = TextStyle(
    fontFamily: 'Inter',
    fontFamilyFallback: _fallback,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.40,
  );

  // ─── Body ──────────────────────────────────────────────────
  /// 正文（16px / w400），颜色 #212121
  static const TextStyle body = TextStyle(
    fontFamily: 'Inter',
    fontFamilyFallback: _fallback,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.55,
    color: Color(0xFF212121),
  );

  /// 正文加粗（16px / w600）
  static const TextStyle bodyBold = TextStyle(
    fontFamily: 'Inter',
    fontFamilyFallback: _fallback,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.55,
    color: Color(0xFF212121),
  );

  /// 小正文（14px / w400）
  static const TextStyle bodySm = TextStyle(
    fontFamily: 'Inter',
    fontFamilyFallback: _fallback,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.50,
  );

  // ─── Caption / Micro ──────────────────────────────────────
  /// 说明文字（13px / w400）
  static const TextStyle caption = TextStyle(
    fontFamily: 'Inter',
    fontFamilyFallback: _fallback,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.40,
  );

  /// 说明文字加粗（13px / w600）
  static const TextStyle captionBold = TextStyle(
    fontFamily: 'Inter',
    fontFamilyFallback: _fallback,
    fontSize: 13,
    fontWeight: FontWeight.w600,
    height: 1.40,
  );

  /// 微型文字（12px / w500）
  static const TextStyle micro = TextStyle(
    fontFamily: 'Inter',
    fontFamilyFallback: _fallback,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.40,
  );

  // ─── Button ────────────────────────────────────────────────
  /// 按钮文字（14px / w600）
  static const TextStyle button = TextStyle(
    fontFamily: 'Inter',
    fontFamilyFallback: _fallback,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.30,
  );

  // ─── Tab ────────────────────────────────────────────────────
  /// Tab 选中态（14px / w600）
  static const TextStyle tabActive = TextStyle(
    fontFamily: 'Inter',
    fontFamilyFallback: _fallback,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.40,
  );

  /// Tab 未选中态（14px / w400）
  static const TextStyle tabInactive = TextStyle(
    fontFamily: 'Inter',
    fontFamilyFallback: _fallback,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.40,
  );
}
```

**letterSpacing 说明**（来源：`docs/font_strategy.md`）：
- CSS `letter-spacing: -0.01em` = Flutter `letterSpacing: -fontSize × 0.01`
- **仅用于纯西文 token**（heroWord、音标等），含中文的样式不加（避免汉字粘连）
- Inter 无需放宽到 -0.005em（其本身按紧字距设计）

---

## 四、形状 / 间距 / 圆角 / 阴影

```dart
/// 形状系统 — 星巴克风格
class StarbucksShape {
  // ─── 圆角 ─────────────────────────────────────────────────
  static const double radiusXs     = 4;     // 最小组件（badge/小按钮）
  static const double radiusSm     = 6;     // 小组件（输入框/小卡片）
  static const double radiusMd     = 8;     // 中型（按钮/控件）
  static const double radiusLg     = 12;    // 大卡片圆角
  static const double radiusXl     = 16;    // 模态框/底部 sheet
  static const double radiusXxl    = 20;    // 大模态框
  static const double radiusPill   = 50;    // 胶囊（pill button/tag）
  static const double radiusFrap   = 56;    // Frap 按钮（主 CTA）

  // ─── 间距 ─────────────────────────────────────────────────
  static const double spaceXxs     = 2;     // 极小间距
  static const double spaceXs      = 4;     // 最小间距
  static const double spaceSm      = 8;     // 小间距
  static const double spaceMd      = 12;    // 中间距
  static const double spaceLg      = 16;    // 大间距（页面边距）
  static const double spaceXl      = 20;    // 特大间距
  static const double spaceXxl     = 24;    // 超大间距
  static const double spaceSection = 32;    // 章节间距

  // ─── 卡片阴影（双层）───────────────────────────────────
  /// 亮色主题卡片阴影 — 双层柔和
  static const List<BoxShadow> cardShadowLight = [
    BoxShadow(color: Color(0x0A000000), blurRadius: 6, offset: Offset(0, 2)),
    BoxShadow(color: Color(0x0F000000), blurRadius: 12, offset: Offset(0, 4)),
  ];

  /// 暗色主题卡片阴影 — 双层深绿
  static const List<BoxShadow> cardShadowDark = [
    BoxShadow(color: Color(0x1A000000), blurRadius: 6, offset: Offset(0, 2)),
    BoxShadow(color: Color(0x26000000), blurRadius: 12, offset: Offset(0, 4)),
  ];
}
```

---

## 五、皮肤预设（ThemeVars 完整字段值）

> 对齐现有 `lib/theme/skin_system.dart` 的 ThemeVars 结构（30 个语义字段）

### 5.1 starbucks_cream 预设

```dart
/// 星巴克奶油主题 — ThemeVars 完整映射
ThemePreset starbucksCream = ThemePreset(
  id: 'starbucks_cream',
  name: '星巴克奶油',
  statusBarBrightness: Brightness.dark, // 亮色用深色状态栏图标
  vars: ThemeVars(
    // ─── 画布/卡片 ────────────────────────────────────
    pageBg:       const Color(0xFFF2F0EB),   // 奶油画布
    cardBg:       const Color(0xFFFFFFFF),   // 白卡片
    cardBgAlt:    const Color(0xFFEDEBE9),   // 陶瓷画布

    // ─── 文字 ──────────────────────────────────────────
    text1:        const Color(0xDE212121),   // 主文字 α=0.87
    text2:        const Color(0x94212121),   // 次要文字 α=0.58
    text3:        const Color(0x73212121),   // 三级文字 α=0.45

    // ─── 分割线/强调 ──────────────────────────────────
    divider:      const Color(0x14000000),   // 8% 黑
    accent:       const Color(0xFF00754A),   // 品牌绿（CTA/描边）
    success:      const Color(0xFF4CAF50),   // 成功
    danger:       const Color(0xFFE3303B),   // 错误
    teal:         const Color(0xFF00754A),   // 链接/互动色

    // ─── Tab Bar ────────────────────────────────────────
    tabBarIcon:   const Color(0xDE212121),

    // ─── 玻璃层（亮色下等于卡片色）─────────────────
    onGlassText1: const Color(0xDE212121),
    onGlassText2: const Color(0x94212121),
    onGlassAccent: const Color(0xFF00754A),
    glassBg:      const Color(0xFFFFFFFF),
    glassBgStrong: const Color(0xFFFFFFFF),
    glassBorder:  const Color(0x14000000),
    wallpaperScrim: const Color(0xFFF2F0EB),

    // ─── 模态框 ─────────────────────────────────────────
    modalGlassBg: const Color(0xFFFFFFFF),
    modalText1:   const Color(0xDE212121),
    modalText2:   const Color(0x94212121),

    // ─── 测验状态 ───────────────────────────────────────
    quizCorrectBg:   const Color(0xFFD1FAE5),
    quizCorrectText: const Color(0xFF4CAF50),
    quizWrongBg:     const Color(0xFFFEE2E2),
    quizWrongText:   const Color(0xFFE3303B),

    // ─── VIP 金色（成就专属）────────────────────────────
    vipGoldBg:    const Color(0xFFCBA258),
    vipGoldText:  const Color(0xFFFFFFFF),

    // ─── 个人页装饰 ─────────────────────────────────────
    profileDecor: const [Color(0xFFD4E9E2), Color(0xFFEDEBE9)],
  ),
);
```

### 5.2 starbucks_dark 预设

```dart
/// 星巴克深绿主题 — ThemeVars 完整映射
/// 三层深绿体系：画布 #101B17 / 表面 #1E3932 / 浮层 #274A40
ThemePreset starbucksDark = ThemePreset(
  id: 'starbucks_dark',
  name: '星巴克深绿',
  statusBarBrightness: Brightness.light,
  vars: ThemeVars(
    // ─── 三层深绿体系 ─────────────────────────────────
    pageBg:       const Color(0xFF101B17),   // 画布（墨绿近黑）
    cardBg:       const Color(0xFF1E3932),   // 表面/卡片
    cardBgAlt:    const Color(0xFF274A40),   // 二级浮层

    // ─── 文字 ──────────────────────────────────────────
    text1:        const Color(0xDEFFFFFF),   // 主文字 α=0.87
    text2:        const Color(0xFFA9BCB5),   // 次要文字（浮层 4.93:1 AA）
    text3:        const Color(0x73FFFFFF),   // 三级文字 α=0.45

    // ─── 分割线/强调 ──────────────────────────────────
    divider:      const Color(0x1FFFFFFF),   // 12% 白
    accent:       const Color(0xFF00A862),   // 薄荷绿强调
    success:      const Color(0xFF22A18B),   // 成功（深色版）
    danger:       const Color(0xFFC64354),   // 错误（深色版）
    teal:         const Color(0xFF00A862),   // 链接/互动色

    // ─── Tab Bar ────────────────────────────────────────
    tabBarIcon:   const Color(0xDEFFFFFF),

    // ─── 玻璃层（暗色专用）────────────────────────────
    onGlassText1: const Color(0xDEFFFFFF),
    onGlassText2: const Color(0xFFA9BCB5),
    onGlassAccent: const Color(0xFF00A862),
    glassBg:      const Color(0xFF1E3932),
    glassBgStrong: const Color(0xFF274A40),
    glassBorder:  const Color(0x1FFFFFFF),
    wallpaperScrim: const Color(0xFF101B17),

    // ─── 模态框 ─────────────────────────────────────────
    modalGlassBg: const Color(0xFF274A40),   // 浮层（弹窗）
    modalText1:   const Color(0xDEFFFFFF),
    modalText2:   const Color(0xFFA9BCB5),

    // ─── 测验状态 ───────────────────────────────────────
    quizCorrectBg:   const Color(0xFF1A3D2E),
    quizCorrectText: const Color(0xFF22A18B),
    quizWrongBg:     const Color(0xFF3D1A2E),
    quizWrongText:   const Color(0xFFC64354),

    // ─── VIP 金色 ────────────────────────────────────────
    // ⚠️ 浮层场景（modalGlassBg）必须用 goldLight（5.85:1 AA）
    // 普通场景 gold 5.25:1 AA 已够
    vipGoldBg:    const Color(0xFFCBA258),
    vipGoldText:  const Color(0xFFFFFFFF),

    // ─── 个人页装饰 ─────────────────────────────────────
    profileDecor: const [Color(0xFF101B17), Color(0xFF1E3932)],
  ),
);
```

---

## 六、迁移注释（旧 Token → 新值对照）

| 旧 Token | 旧值 | 新 Token | 新值 | 备注 |
|---|---|---|---|---|
| **画布/背景** | | | | |
| `pageBg` (bright) | `#F5F5F5` | `pageBg` (cream) | `#F2F0EB` | 奶油画布替换浅灰 |
| `pageBg` (dark) | `#212532` 蓝灰 | `pageBg` (dark) | `#101B17` 墨绿近黑 | 三层深绿体系 |
| `pageBg` (pure_black) | `#040404` | 无对应 | — | pure_black 合并入 dark |
| `cardBg` (bright) | `#FFFFFF` | `cardBg` (cream) | `#FFFFFF` | 不变 |
| `cardBg` (dark) | `#2E344A` 蓝灰 | `cardBg` (dark) | `#1E3932` 深绿 | 表面层 |
| `cardBgAlt` (dark) | `#292F44` | `cardBgAlt` (dark) | `#274A40` | 二级浮层 |
| **文字** | | | | |
| `text1` (bright) | `0xDE000000` (87%黑) | `text1` (cream) | `0xDE212121` | 改用 #212121 |
| `text2` (bright) | `0x8A000000` (54%黑) | `text2` (cream) | `0x94212121` (58%黑) | α 提升至 0.58 AA |
| `text3` (bright) | `0x61000000` (38%黑) | `text3` (cream) | `0x73212121` (45%黑) | α 提升 |
| `text1` (dark) | `0xDEFFFFFF` | `text1` (dark) | `0xDEFFFFFF` | 不变 |
| `text2` (dark) | `0x8AFFFFFF` (54%白) | `text2` (dark) | `#A9BCB5` 雾绿 | 固定色值（浮层 AA 达标）|
| **强调色** | | | | |
| `accent` (bright) | `#E8913A` 橙 | `accent` (cream) | `#00754A` 绿 | 品牌绿替换橙 |
| `accent` (dark) | `#F4A100` 金 | `accent` (dark) | `#00A862` 薄荷绿 | 薄荷绿替换金色 |
| `teal` (bright) | `#4A90E2` 蓝 | `teal` (cream) | `#00754A` 绿 | 品牌绿替换蓝 |
| `teal` (dark) | `#4A90E2` 蓝 | `teal` (dark) | `#00A862` 薄荷绿 | |
| **状态色** | | | | |
| `success` (bright) | `#4CAF50` | `success` (cream) | `#4CAF50` | 不变 |
| `success` (dark) | `#22A18B` | `success` (dark) | `#22A18B` | 不变 |
| `danger` (bright) | `#E3303B` | `danger` (cream) | `#E3303B` | 不变 |
| `danger` (dark) | `#C64354` | `danger` (dark) | `#C64354` | 不变 |
| **VIP 金色** | | | | |
| `vipGoldBg` | `#FFD06A` 旧亮金 | `vipGoldBg` (cream/dark) | `#CBA258` 品牌金 | 星巴克经典金 |
| `vipGoldText` | `#1F1F1F` | `vipGoldText` | `#FFFFFF` | 白字 on 金色 |
| **Tab** | | | | |
| `tabBarIcon` (bright) | `0xDE000000` | `tabBarIcon` (cream) | `0xDE212121` | 与 text1 一致 |
| **个人页** | | | | |
| `profileDecor` (bright) | `[#F5F5F5, #E8E8E8]` | `profileDecor` (cream) | `[#D4E9E2, #EDEBE9]` | 浅绿+陶瓷 |
| `profileDecor` (dark) | `[#212532, #292F44]` | `profileDecor` (dark) | `[#101B17, #1E3932]` | 深绿体系 |

---

## 七、设计决策记录

### 7.1 亮色文字 α 阶梯

| 层级 | α 值 | 设计意图 | A11y 状态 |
|---|---|---|---|
| text1 主文字 | 0.87 | 正文/标题 | AAA (14.14:1) |
| text2 次要文字 | 0.58 | 说明/元数据 | AA (5.11:1) |
| text3 三级文字 | 0.45 | 禁用态/纯装饰 | 仅限非交互 |

**α 红线**（来源 `docs/a11y_contrast_report.md`）：α 不得低于 0.55（0.52 即 AA 失败 4.16:1）

### 7.2 暗色文字为何不用 α 阶梯？

暗色版改用**固定色值**而非 α 合成，原因：
1. 白字 α 在三层表面上对比度差异大（画布 6.59 vs 浮层 4.51）
2. 固定色值 #A9BCB5 经 A11y 验证浮层 4.93:1 AA 达标
3. 比统一 α=0.62 更精准（避免画布/卡片过亮）

### 7.3 accentOnSurface 修正

`docs/dark_skin_strategy.md` 原方案 `#D4E9E2` on `#00A862` = 2.44:1 ❌，**全场景失败**。
修正：用深色文字 `#101B17` on `#00A862` = 5.69:1 ✅（复用画布 token，零新增色值）

### 7.4 textSecondary 修正

`docs/dark_skin_strategy.md` 原方案 `#9DB0A9` 在浮层 `#274A40` 上仅 4.31:1 ❌。
修正：提亮至 `#A9BCB5`（浮层 4.93 ✅ / 表面 6.25 ✅ / 画布 ≈8.4 AAA）

### 7.5 金色浮层规则

- 普通场景：`#CBA258`（5.25:1 AA 够用）
- 浮层/弹窗：必须用 `#DFC49D`（5.85:1 AA），原金色在 `#274A40` 上仅 4.14:1 ❌

### 7.6 三层深绿体系

来源 `docs/dark_skin_strategy.md` 4.2 节：
- 画布 `#101B17`：比 #1E3932 更深更沉，长时间盯屏不疲劳
- 表面 `#1E3932`：品牌深绿的正确位置（卡片/浮层，非画布）
- 浮层 `#274A40`：弹窗/菜单，需注意文字对比度

---

## 八、引用来源

| 来源 | 内容 |
|---|---|
| `docs/a11y_contrast_report.md` | 亮色 7 组组合全 AA 达标，α 红线 ≥0.55 |
| `docs/a11y_dark_mode_report.md` | 暗色三层体系验证，accentOnSurface/textSecondary 修正 |
| `docs/dark_skin_strategy.md` | 方案C（画布归品牌装饰归个性），深绿三层体系提案 |
| `docs/font_strategy.md` | Inter 选型，中西文混排策略，letterSpacing 规则 |
| `lib/theme/skin_system.dart` | 现有 ThemeVars 30 个语义字段结构 |
| `lib/tokens/design_tokens.dart` | 现有 MistralColors/AppleRadius 等旧 token |

---

## 九、待确认项

1. **Lora 衬线字体**：成就/奖励场景是否引入？（`docs/font_strategy.md` 建议，草案暂未包含）
2. **glassBg 模糊效果**：亮色下与卡片同值，是否需要 BackdropFilter？
3. **pure_black 主题**：是否保留为无障碍选项？（草案已合并入 dark，OLED 需求由 surface 层压暗覆盖）
4. **#274A40 的使用纪律**：浮层内禁用小号强调色文字（#00A862 仅 4.02:1），需写入代码注释

---

*草案完成于 2026-08-24，基于方案C（画布归品牌，装饰归个性）。*
*全部 A11y 数值由 WCAG 官方公式经脚本精确计算，可随时用 WebAIM Contrast Checker 复核。*
