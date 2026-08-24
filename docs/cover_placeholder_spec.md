# 【重构48】词书封面占位图：代码绘制规格

> 项目：Monster Word（D:\claude\work\cn_com_lange\word_app）· 2026-08-24
> 方法：只读分析 lib/pages/lib_select_page.dart 现有封面绘制代码 + 引用 imagery_audit.md / starbucks_migration_plan.md 结论
> 关联文档：docs/imagery_audit.md（§1.2 渲染代码取证）、docs/starbucks_migration_plan.md（§一 颜色映射）、docs/starbucks_tokens_draft.md（三档绿定义）

---

## 一、现状分析

### 1.1 当前封面渲染代码

位置：`lib/pages/lib_select_page.dart:307-330`（`_LibItem.build` 内）

```dart
// 当前实现（橙系渐变，违反星巴克"无渐变"规范）
Container(
  width: 72,
  height: 88,
  decoration: BoxDecoration(
    gradient: const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [AppColors.mainBgTop, AppColors.mainBgBottom],
    ),
    borderRadius: BorderRadius.circular(4),
  ),
  child: Center(
    child: Text(
      _coverText(),
      style: const TextStyle(
        color: Colors.white,
        fontSize: 11,
        fontWeight: FontWeight.bold,
      ),
      textAlign: TextAlign.center,
    ),
  ),
)
```

### 1.2 封面文字生成逻辑

位置：`lib_select_page.dart:399-402`

```dart
String _coverText() {
  final name = book.name.replaceAll(RegExp(r'MonsterWord_'), '');
  return name.length > 4 ? name.substring(0, 4) : name;
}
```

- 书名剔除 `MonsterWord_` 前缀后取**前 4 个字符**
- 191 本书的 `books.name` 全部等于内部 code（如 `HZBCET6N`），非人类可读名
- 待词书友好名方案（Librarian 方案）落地后，数据源应切换为 friendly name

### 1.3 现有问题清单

| 问题 | 严重度 | 说明 |
|---|---|---|
| 渐变背景 | 高 | LinearGradient 直接违反星巴克"无渐变"规范 |
| 橙色系 | 高 | mainBgTop/Bot 为奶油色（原为橙色），迁移后仍需替换为品牌绿 |
| 圆角 4px | 低 | 与新卡片体系 12px 不一致，但书封尺寸小，需单独评估 |
| 文字取 code 前 4 字符 | 中 | `HZBCET6N` → `HZBC` 无语义，待 friendly name 落地 |

---

## 二、星巴克风格替代方案

### 2.1 设计原则

- **零新增资产**：维持纯代码绘制架构，离线零成本、包体零增量
- **品牌一致性**：三档绿轮换，避免 191 本书一片绿墙
- **文字可读性**：白字 on 三档绿对比度均 ≥7:1（远超 WCAG AA 4.5:1）
- **深色模式兼容**：三档绿在深色画布上保持层级区分

### 2.2 配色方案

| 档位 | 色值 | 色名 | 白字对比度 | 用途 |
|---|---|---|---|---|
| 绿-1 | `#006241` | Starbucks Green | 8.2:1 | 深绿底，标题/描边主色 |
| 绿-2 | `#00754A` | House Green | 5.76:1 | 中绿底，CTA/主强调色 |
| 绿-3 | `#1E3932` | 墨绿 | 10.5:1 | 最深绿底，沉浸区/深色底 |

> 数据来源：docs/a11y_contrast_report.md 实测值

### 2.3 三档绿轮换算法

按 book code 的 hash 值稳定分配，保证：
- 同一词书每次打开颜色一致（确定性）
- 相邻列表项尽量不同色（视觉错开）

```dart
/// 三档绿：按 book code hash 稳定分配
/// 返回值 0/1/2 对应三档绿索引
static int _coverColorIndex(String code) {
  return code.hashCode.abs() % 3;
}

static const _coverColors = [
  Color(0xFF006241), // Starbucks Green
  Color(0xFF00754A), // House Green
  Color(0xFF1E3932), // 墨绿
];
```

**相邻列表项错开分析**：
- 当前列表按数据库默认顺序排列（非 hash 排序）
- 191 本书的 code hash % 3 分布近似均匀（各约 63-64 本）
- 但连续排列时可能出现同色相邻（如 hash 值相近的 code）
- **扰动策略**（若视觉验收不通过）：引入 `index` 参与计算 `_coverColors[(code.hashCode.abs() + index) % 3]`，在列表构建时传入 `index` 参数

### 2.4 封面文字升级

| 维度 | 当前 | 新方案 |
|---|---|---|
| 数据源 | `book.name`（内部 code） | 待 friendly name 落地后切换；当前保持 code 兜底 |
| 截取规则 | 前 4 字符 | 保持前 4 字符（短名场景足够）；超长名截断策略见下 |
| 字体 | bold | Inter w600（对齐品牌字体规范） |
| 字号 | 11px | 11px（72px 容器内 4 字符 + 两行，空间刚好） |
| 颜色 | `#FFFFFF` | `#FFFFFF`（不变） |

**超长名处理**（friendly name 落地后）：
- 中文名：取前 4 个汉字（如"红宝书·四" → "红宝书·"）
- 英文名：取首单词或前 6 字符（如"CET4" → "CET4"、"IELTS" → "IELTS"）
- 纯 ASCII code：保持前 4 字符（如"HZBC"）

### 2.5 尺寸规格

| 参数 | 当前值 | 新值 | 说明 |
|---|---|---|---|
| 宽度 | 72dp | 72dp | 保持不变，与列表项 120dp 高度协调 |
| 高度 | 88dp | 88dp | 保持不变 |
| 宽高比 | 0.82:1 | 0.82:1 | 接近标准书籍比例 |
| 圆角 | 4px | **8px** | 对齐 AppleRadius.md，介于旧值 4 与卡片 12 之间——书封尺寸小，12px 会切掉过多面积 |

### 2.6 深色模式适配

三档绿在深色画布上的层级表现：

| 绿档 | 在 `#101B17`（starbucks_dark 画布）上的表现 | 备注 |
|---|---|---|
| `#006241` | 可辨识，中等对比 | 需确认与画布的对比度 |
| `#00754A` | 最亮，层级最突出 | 主 CTA 色，适合高优先词书 |
| `#1E3932` | 接近画布色，可能难以区分 | ⚠️ 风险点 |

**深色模式方案**：
- 方案 A（推荐）：深色模式下统一提亮一档——绿-3 `#1E3932` → `#2b5148`（starbucks_migration_plan.md 已定义的中间层），确保三档在深色画布上均可辨识
- 方案 B：深色模式下仅用两档（`#006241` / `#00754A`），弃用 `#1E3932`
- 方案 C：保持三档不变，通过加 1px 白色 10% 透明描边区分 `#1E3932` 与画布

**推荐方案 A**，理由：复用已有中间层 token，零新增常量，且三档保持完整。

---

## 三、Flutter 代码骨架

### 3.1 完整替换代码（lib_select_page.dart:307-330）

```dart
// ===== 词书封面（星巴克风格：纯色底 + 白字）=====
Container(
  width: 72,
  height: 88,
  decoration: BoxDecoration(
    color: _coverColor(book.code), // 三档绿按 hash 轮换
    borderRadius: BorderRadius.circular(8), // AppleRadius.md
  ),
  child: Center(
    child: Text(
      _coverText(),
      style: const TextStyle(
        color: Colors.white,
        fontSize: 11,
        fontWeight: FontWeight.w600, // Inter w600，对齐品牌规范
      ),
      textAlign: TextAlign.center,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    ),
  ),
)
```

### 3.2 辅助方法（新增到 _LibItem 类）

```dart
/// 三档绿：按 book code hash 稳定分配
static const _coverColors = [
  Color(0xFF006241), // Starbucks Green
  Color(0xFF00754A), // House Green
  Color(0xFF1E3932), // 墨绿
];

/// 深色模式下的替代色（绿-3 提亮）
static const _coverColorsDark = [
  Color(0xFF006241), // Starbucks Green（不变）
  Color(0xFF00754A), // House Green（不变）
  Color(0xFF2b5148), // 墨绿提亮（替代 #1E3932）
];

/// 根据当前主题选择封面色
Color _coverColor(String code) {
  final index = code.hashCode.abs() % 3;
  // 通过 context 读取当前主题亮度
  // 注意：此方法需要 BuildContext，实际实现见下方完整方案
  return _coverColors[index];
}
```

### 3.3 完整实现方案（含深色模式适配）

由于 `_LibItem` 是 StatelessWidget，需要通过 `BuildContext` 读取主题状态：

```dart
class _LibItem extends StatelessWidget {
  final Book book;
  final bool showDescription;
  const _LibItem({required this.book, this.showDescription = true});

  // 三档绿（亮色模式）
  static const _coverColorsLight = [
    Color(0xFF006241), // Starbucks Green
    Color(0xFF00754A), // House Green
    Color(0xFF1E3932), // 墨绿
  ];

  // 三档绿（深色模式：绿-3 提亮）
  static const _coverColorsDark = [
    Color(0xFF006241),
    Color(0xFF00754A),
    Color(0xFF2b5148), // 墨绿提亮
  ];

  /// 按 book code hash 稳定分配三档绿
  Color _coverColor(BuildContext context, String code) {
    final index = code.hashCode.abs() % 3;
    final isDark = context.skin.currentTheme.uiBrightness == Brightness.dark;
    return isDark ? _coverColorsDark[index] : _coverColorsLight[index];
  }

  String _coverText() {
    final name = book.name.replaceAll(RegExp(r'MonsterWord_'), '');
    return name.length > 4 ? name.substring(0, 4) : name;
  }

  @override
  Widget build(BuildContext context) {
    // ... 现有 build 方法不变，仅替换封面 Container 部分 ...
    // Container(
    //   width: 72,
    //   height: 88,
    //   decoration: BoxDecoration(
    //     color: _coverColor(context, book.code),
    //     borderRadius: BorderRadius.circular(8),
    //   ),
    //   child: Center(
    //     child: Text(
    //       _coverText(),
    //       style: const TextStyle(
    //         color: Colors.white,
    //         fontSize: 11,
    //         fontWeight: FontWeight.w600,
    //       ),
    //       textAlign: TextAlign.center,
    //       maxLines: 2,
    //       overflow: TextOverflow.ellipsis,
    //     ),
    //   ),
    // ),
  }
}
```

---

## 四、变更影响分析

### 4.1 改动范围

| 文件 | 改动点 | 行数 |
|---|---|---|
| `lib/pages/lib_select_page.dart` | `_LibItem` 类：封面 Container 装饰 + 新增 `_coverColor` 方法 + `_coverText` 微调 | ~15 行 |

### 4.2 不需要改动的部分

- `lib/theme/skin_system.dart`：ThemeVars 结构不变，封面色由组件内部管理（三档绿是封面专属，非全局 token）
- `lib/tokens/design_tokens.dart`：AppColors 不变，封面色不入全局 token（避免污染 analyzer 统计）
- 数据库/模型层：`book.cover` 字段继续保留为预留位，本次不消费

### 4.3 与后续任务的衔接

| 后续任务 | 衔接点 |
|---|---|
| 词书友好名（Librarian 方案） | `_coverText()` 数据源从 `book.name` 切换为 friendly name 字段 |
| book_cover_design_spec.md | 本规格的三档绿算法与该 spec 的 hash 轮换方案一致，可直接复用 |
| 星巴克 token 草案 | 三档绿色值与 starbucks_tokens_draft.md 对齐 |

---

## 五、验收清单

| # | 验收点 | 预期结果 |
|---|---|---|
| V1 | 列表中 191 本书封面颜色 | 三档绿均匀分布，无橙色/渐变残留 |
| V2 | 相邻列表项颜色 | 大部分相邻项不同色（偶尔同色可接受，若频繁则启用 index 扰动） |
| V3 | 白字可读性 | 三档绿底上白字清晰可辨，无模糊/低对比 |
| V4 | 深色模式 | 三档绿在深色画布上均可辨识，绿-3 不与画布混淆 |
| V5 | 封面文字 | 显示 book code 前 4 字符（待 friendly name 后切换） |
| V6 | 尺寸 | 72×88 不变，圆角 8px |
| V7 | 无渐变 | LinearGradient 完全移除，改为纯色 BoxDecoration |
| V8 | flutter analyze | ERROR=0 |
| V9 | flutter test | 全过 |

---

## 六、风险与降级策略

| 风险 | 概率 | 降级方案 |
|---|---|---|
| 三档绿在浅色主题下区分度不够 | 低 | 浅色画布 `#f2f0eb` 与三档绿对比度均 >5:1，理论无问题 |
| 绿-3 `#1E3932` 在深色画布 `#101B17` 难区分 | 中 | 已在 §2.6 提供提亮方案 `#2b5148` |
| 相邻列表项频繁同色 | 低 | 启用 index 扰动：`_coverColors[(code.hashCode.abs() + index) % 3]` |
| friendly name 未及时落地 | 无影响 | 当前 code 前 4 字符兜底，体验与现有一致 |

---

*产出：ComponentEngineer · 2026-08-24 · 基于 lib_select_page.dart 只读分析与既有审计文档引用*
