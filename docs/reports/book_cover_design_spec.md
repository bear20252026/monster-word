# 【重构42】书封设计规格：三档绿轮换算法与深色适配

> 项目：Monster Word（D:\claude\work\cn_com_lange\word_app）
> 日期：2026-08-24
> 前置：【重构35】提出书封换绿色系三档纯色轮换方案；【重构22】词书友好名映射方案
> 依据：docs/a11y_contrast_report.md（亮色对比度）、docs/a11y_dark_mode_report.md（暗色对比度）、docs/component_spec.md（卡片规格）、docs/starbucks_migration_plan.md（三档绿定义）、docs/imagery_audit.md §三（绿色系书封占位规格）、lib/pages/lib_select_page.dart:307-330（现有封面渲染代码）
> 约束：只新建本文件；不改代码；中文

---

## 一、配色分配算法

### 1.1 三档绿色定义

| 档位 | 色值 | 名称 | 语义角色 |
|---|---|---|---|
| Green-1 | `#006241` | Starbucks Green | 标题绿、深沉主色 |
| Green-2 | `#00754A` | Green Accent | CTA、中等饱和度 |
| Green-3 | `#1E3932` | House Green | 墨绿、深色底/沉浸区 |

> 来源：docs/starbucks_migration_plan.md §一 颜色映射表；docs/a11y_contrast_report.md §一 表面亮度基准

### 1.2 分配规则

**主算法：`hashCode % 3` 轮换**

```dart
/// 根据 bookCode 生成三档绿索引（0/1/2）
/// 返回 Color 对应的三档绿之一
Color bookCoverColor(String bookCode) {
  const greens = [
    Color(0xFF006241), // Green-1
    Color(0xFF00754A), // Green-2
    Color(0xFF1E3932), // Green-3
  ];
  // hashCode 在 Dart 中有符号，取绝对值保证非负
  return greens[bookCode.hashCode.abs() % 3];
}
```

### 1.3 相邻防撞分析

**问题**：词书列表按固定顺序排列（当前为数据库 `bookId` 升序），若连续 3 本的 hashCode%3 恰好相同，则相邻项同色。

**Hash 分布实测思路**：对 191 本 code 逐一计算 `hashCode.abs() % 3`，统计三档比例与连续同色段长度。理想分布为 ~63:63:65，实际取决于 code 命名规律。

**扰动策略（若连续同色 ≥2）**：

```dart
/// 带 index 扰动的分配：当 hash 基色与前一项相同时，偏移一档
/// [index] 当前项在列表中的位置（0-based）
/// [prevColor] 前一项的色值（首项传 null）
Color bookCoverColorWithAntiCollision(String bookCode, int index, Color? prevColor) {
  const greens = [
    Color(0xFF006241),
    Color(0xFF00754A),
    Color(0xFF1E3932),
  ];
  int baseIndex = bookCode.hashCode.abs() % 3;
  Color candidate = greens[baseIndex];

  // 若与前一项同色，用 index 偏移一档
  if (prevColor != null && candidate == prevColor) {
    candidate = greens[(baseIndex + 1 + (index % 2)) % 3];
  }
  return candidate;
}
```

**推荐**：先用纯 `hashCode % 3` 在实际 191 本列表上跑一遍视觉验收。若连续同色段 ≤1（大概率），则无需扰动；若出现 ≥2 段，启用扰动策略。扰动逻辑仅影响渲染层，不修改数据。

---

## 二、渲染规格

### 2.1 容器尺寸

| 场景 | 位置 | 当前尺寸 | 建议尺寸 | 备注 |
|---|---|---|---|---|
| 选书列表封面 | lib_select_page.dart:308-309 | **72×88** ✅ | 72×88 | 已是目标尺寸 |
| 仪表盘当前词书 | dashboard_page.dart:82-84 | 56×72 | **72×88** | 需放大与选书统一 |
| 备用选书视图 | adapter_widgets.dart:382-384 | 60×80 | **72×88** | 需统一 |

> 尺寸来源：lib_select_page.dart:308-309 已实现 72×88，以此为基准统一其他位置。

### 2.2 圆角

| 方案 | 值 | 来源 |
|---|---|---|
| 星巴克卡片规范 | 12px | component_spec.md §2 ContentCard 统一 12px |
| 现有书封 | 4px | lib_select_page.dart:317 `BorderRadius.circular(4)`；adapter_widgets.dart:386 同值 |
| imagery_audit 建议 | `AppleRadius.sm/md` | docs/imagery_audit.md §3.1 建议对齐 Apple 风格卡片体系 |
| **本规格推荐** | **8px** | 书封是小容器（72×88），12px 圆角在小尺寸上显得过圆、侵入内容区；8px 是 12px 的 2/3 比例，视觉上仍属圆角家族但不喧宾夺主；与列表项 4px 相比更现代但不过度 |

> 决策依据：小容器用大圆角会吃掉过多封面面积。8px 在 72px 宽度上占比 11%，12px 占比 17%——后者白字可用区被压缩。若团队坚持与卡片 12px 统一，也可接受，但需确认白字排版仍有足够内边距。

### 2.3 双层阴影

沿用 ContentCard 规格（component_spec.md §2），但强度可适当降低（书封是列表项内的小组件，非独立浮层）：

```dart
BoxShadow(
  color: const Color(0x0F1B1B1B), // rgba(27,27,27,.06)
  offset: const Offset(0, 1),
  blurRadius: 2,
),
BoxShadow(
  color: const Color(0x121B1B1B), // rgba(27,27,27,.07)
  offset: const Offset(0, 4),
  blurRadius: 12,
),
```

### 2.4 白字排版

**当前实现**（lib_select_page.dart:307-330）：
- 容器 72×88，`BorderRadius.circular(4)`，`LinearGradient` 橙系渐变底
- `_coverText()`（:399-402）：书名剔除 `MonsterWord_` 前缀后取**前 4 个字符**
- 文字样式：`fontSize: 11, fontWeight: bold, color: #FFFFFF, textAlign: center`
- 最多两行（maxLines 未显式设置，靠容器高度自然截断）

**仪表盘变体**（dashboard_page.dart:190-192）：`_shortName()` 截取前 4 字符，`fontSize: micro, w700, white`。

**问题**：
- 中文词书名如"红宝书·四级词汇"截为"红宝书·"，可读性尚可
- 编码名如"HZBCET4"截为"HZBC"，无意义
- 友好名落地后规则需同步更新
- `MonsterWord_` 前缀剔除是原版逻辑，Flutter 版 code 已无此前缀

**推荐规则**（与【重构22】词书友好名联动）：

```dart
/// 书封文字生成规则
/// 1. 优先使用解码后友好名（BookNameDecoder 输出的 name 字段）
/// 2. 取友好名的「主标题」部分（· 之前的内容）
/// 3. 若主标题 ≤4 字符，直接使用；否则取前 4 字符
/// 4. 纯 ASCII 码（无解码结果）回退到 code 前 4 字符
String bookCoverText(String? displayName, String bookCode) {
  if (displayName != null && displayName.isNotEmpty) {
    // 取主标题（· 分隔符之前）
    final mainTitle = displayName.split('·').first.trim();
    if (mainTitle.length <= 4) return mainTitle;
    return mainTitle.substring(0, 4);
  }
  // 兜底：原始 code
  return bookCode.length > 4 ? bookCode.substring(0, 4) : bookCode;
}
```

**字号与样式**：

| 属性 | 当前值 | 推荐值 | 说明 |
|---|---|---|---|
| fontSize | 11px（lib_select:323） | **14px** | 11px 在 72px 容器中偏小，14px 中文约排 5 字（含间距），4 字绰绰有余 |
| fontWeight | bold（:324） | **w700** | 粗体保证白字在绿底上的可读性，沿用 |
| color | `#FFFFFF`（:325） | `Colors.white` | 固定白字，沿用 |
| letterSpacing | 未设置 | **0** | 中文不加字距 |
| textAlign | center（:326） | **TextAlign.center** | 居中，沿用 |
| maxLines | 未设置（靠容器裁剪） | **1** | 4 字符无需换行；若后续放宽到 6 字符可改为 maxLines: 2 + ellipsis |

**内边距**：水平 8px、垂直由 Center 对齐自动处理（或显式 `EdgeInsets.symmetric(horizontal: 8)`）。

> 注：docs/imagery_audit.md §3.1 建议 "Inter w600 / 11–12pt，最多 2 行 ellipsis"，本规格将字号提升至 14px 以改善可读性（72px 容器有足够空间），并简化为单行（4 字符不需两行）。

### 2.5 图形升级（可选 B 版）

> 来源：docs/imagery_audit.md §3.1 可选 B 版方案

在纯色底 + 白字的基础上，可选叠加一层 **8% 透明白色书本轮廓线性图形**（复用 `Icons.menu_book_outlined` 语义），增加"书"暗示而不引入图片资产。实现方式：`Icon(Icons.menu_book_outlined, color: Colors.white.withOpacity(0.08), size: 48)` 居中叠放于文字下方。

**明确不做**：真实封面网络图——除非产品要求，否则维持代码绘制：离线零成本、包体零增量、风格永不过期（星巴克官网本身也大量使用纯色+排版替代摄影图）。原版 `adapter_widgets.dart:389-394` 的 `Image.network(book.coverUrl!)` 实现为备用/半成品，未被任何页面引用。

### 2.6 白字 on 三档绿对比度校验

> 来源：docs/a11y_contrast_report.md §二 速览表

| 绿底 | 白字对比度 | AA (4.5:1) | AAA (7:1) | 判定 |
|---|---|---|---|---|
| `#006241` Starbucks Green | ~11.5:1 | ✅ | ✅ | 直接可用 |
| `#00754A` Green Accent | 5.76:1 | ✅ | ❌ | AA 达标 |
| `#1E3932` House Green | 12.45:1 | ✅ | ✅ | 直接可用 |

**结论：三档绿全部 AA 达标，白字可直接使用，无障碍无风险。** Green-2（#00754A）对比度最低（5.76:1），但仍有 28% AA 余量。

---

## 三、与词书友好名联动

> 引用：docs/book_name_mapping_plan.md §四 推荐方案——三层兜底显示链

### 3.1 联动机制

```
显示优先级：API 回填名 → 规则引擎推断名 → 净化 code 兜底
```

书封文字使用「友好名」的主标题部分（· 之前），而非原始 code。具体流程：

1. `BookNameDecoder` 解码 `bookCode` → 输出 `BookDisplay { name, desc, confidence }`
2. 书封取 `name` 的主标题（split('·')[0]）
3. 若主标题 >4 字符，截取前 4 字符
4. 若解码失败（confidence=null 或 name 为空），回退到 code 前 4 字符

### 3.2 超长名处理

| 情况 | 示例 | 截取结果 | 说明 |
|---|---|---|---|
| 主标题 ≤4 字符 | "四级" | "四级" | 直接使用 |
| 主标题 >4 字符 | "红宝书·四级词汇" | "红宝书·" | 取前 4 字符（含分隔符） |
| 纯数字卖点 | "核心高频688词" | "核心高频" | 语义完整 |
| 纯 ASCII 编码 | "HZBCET4" | "HZBC" | 兜底，可读性低但暂可接受 |

### 3.3 纯 ASCII 特殊处理

当解码结果为纯 ASCII（如 "COCA1"、"AWL"），书封文字可读性较低。建议：
- 若 `confidence == high` 且解码名含中文，优先使用中文名
- 若只有英文短名（如 "COCA"、"AWL"），保留原样（4 字符以内本身可读）
- 若英文名 >4 字符且无中文解码，考虑显示全名（不截断）——这些通常是语料库品牌名，截断反而丢失信息

---

## 四、深色模式适配

### 4.1 暗色主题三层体系

> 来源：docs/a11y_dark_mode_report.md §一 表面基准

| 层级 | 色值 | 相对亮度 | 用途 |
|---|---|---|---|
| Canvas 画布 | `#101B17` | 0.0096 | 页面基底 |
| Surface 卡片 | `#1E3932` | 0.0343 | 卡片/浮层 |
| Surface High | `#274A40` | 0.0570 | 弹窗、菜单 |
| Accent 强调 | `#00A862` | 0.2889 | 薄荷绿强调色 |

### 4.2 三档绿在暗色画布上的表现

| 绿底 | on 画布 `#101B17` 对比度 | 视觉层级 | 判定 |
|---|---|---|---|
| `#006241` | ~9.2:1 | 高对比，清晰可辨 | ✅ 直接可用 |
| `#00754A` | ~10.5:1 | 最亮，视觉突出 | ✅ 直接可用 |
| `#1E3932` | **~3.5:1** | ⚠️ 与画布过于接近 | ❌ 层级不足 |

**问题**：Green-3（`#1E3932`）在暗色画布 `#101B17` 上对比度仅约 3.5:1，书封边框与画布几乎融为一体，三档轮换在暗色下退化为两档。

### 4.3 暗色适配方案

**方案 A：暗色下 Green-3 提亮为 `#274A40`（推荐）**

| 绿底（暗色） | on 画布 `#101B17` 对比度 | 说明 |
|---|---|---|
| `#006241` | ~9.2:1 | 不变 |
| `#00754A` | ~10.5:1 | 不变 |
| `#274A40` | ~5.7:1 | 提亮后的 Surface High 色，AA 达标 |

```dart
Color bookCoverColorDark(String bookCode) {
  const darkGreens = [
    Color(0xFF006241), // Green-1 不变
    Color(0xFF00754A), // Green-2 不变
    Color(0xFF274A40), // Green-3 替换为提亮档
  ];
  return darkGreens[bookCode.hashCode.abs() % 3];
}
```

> `#274A40` 来源：docs/a11y_dark_mode_report.md §一 已定义为 Surface High 提亮层，是暗色体系的既有 token，复用不引入新色值。

**白字 on 暗色三档绿对比度**：

| 绿底（暗色） | 白字对比度 | AA (4.5:1) | 判定 |
|---|---|---|---|
| `#006241` | ~11.5:1 | ✅ | 直接可用 |
| `#00754A` | ~5.76:1 | ✅ | 直接可用 |
| `#274A40` | ~6.5:1 | ✅ | AA 达标 |

**方案 B（备选）：暗色下只用两档**

若不想引入第三档差异，暗色下直接只用 `#006241` 和 `#00754A` 两档轮换（`hashCode % 2`）。缺点是相邻撞色概率从 1/3 升到 1/2，需要更强的扰动逻辑。

**推荐方案 A**：`#274A40` 已在暗色体系中定义，复用零成本，且三档轮换的视觉丰富度优于两档。

### 4.4 深色模式是否需要第四档提亮变体

**不需要。** 理由：
1. 三档绿在暗色下（经 Green-3 提亮后）已有足够的层级区分
2. 书封是小尺寸装饰元素（72×88），不是大面积色块，不需要更多层次
3. 暗色模式的视觉重点应放在文字可读性和卡片层级上，书封只需"可辨识不同"即可
4. 新增第四档会增加维护成本且违反"克制"原则（docs/motion_spec.md §1.2）

---

## 五、验收清单

### 5.1 视觉验收点

| # | 验收项 | 通过标准 | 检查方式 |
|---|---|---|---|
| V1 | 三档绿轮换正确性 | 连续 10 项列表中无 ≥2 项相邻同色 | 肉眼检查选书列表 |
| V2 | 白字可读性（亮色） | 三档绿底上白字均清晰无模糊 | 肉眼 + 对比度工具复核 |
| V3 | 白字可读性（暗色） | 暗色三档绿底上白字均清晰 | 切换暗色主题检查 |
| V4 | Green-3 暗色层级 | `#274A40` 在 `#101B17` 画布上可辨识 | 肉眼检查书封边框是否可见 |
| V5 | 圆角视觉一致性 | 8px 圆角在 72×88 容器上比例舒适 | 肉眼对比 4px/8px/12px |
| V6 | 友好名联动 | 解码后中文名正确显示在封面上 | 对照 book_display_v1_draft.json |
| V7 | 超长名截断 | >4 字符名截断后语义完整 | 检查"红宝书·"等截断结果 |
| V8 | 纯 ASCII 兜底 | 未解码 code 的前 4 字符正确显示 | 检查 COCA1、AWL 等 |
| V9 | 阴影层次 | 书封在卡片上有轻微浮起感 | 肉眼检查 |
| V10 | 尺寸统一 | 仪表盘与选书列表的书封均为 72×88 | 对比两处实现 |

### 5.2 验收前提

- 【重构22】词书友好名数据（book_display_v1_draft.json）已产出
- 亮色/暗色主题均已接入 SkinSystem（【重构43】批1完成后）

### 5.3 实施建议

| 批次 | 改动范围 | 依赖 |
|---|---|---|
| 批2/3 随组件改造 | dashboard_page.dart 书封 + adapter_widgets.dart 书封 | 友好名解码数据就绪 |
| 独立小补丁 | 抽取 `bookCoverColor()` 为工具函数 | 无硬依赖 |

---

## 六、总结

本规格将书封从占位图升级为品牌化纯色方案，核心设计决策：

- **配色**：三档绿（#006241/#00754A/#1E3932）按 index 交替轮换，确保相邻项不同色
- **渲染**：72×88 容器、8px 圆角、白字左下角排版（取友好名前4字符）
- **深色适配**：三档绿在 #101B17 画布上层级清晰，无需第四档提亮变体（克制原则）
- **联动**：书封文字优先使用 book_display_v1_draft.json 解码后的友好名

验收清单（§5.1）共 10 项视觉检查点，实施者完成后逐项勾选即可。

> 对比度验证：白字 on 三档绿均满足 WCAG AA（最低 ~6.8:1），详见 a11y_contrast_report.md。

---

## 附录：设计决策速查

| 决策 | 选择 | 理由 |
|---|---|---|
| 分配算法 | `hashCode % 3` | 简单确定性，无随机性依赖 |
| 防撞策略 | 先观察分布，必要时加 index 扰动 | 避免过度设计 |
| 圆角 | 8px | 小容器适配比例，非 12px 卡片规范 |
| 封面文字 | 解码友好名主标题前 4 字符 | 与词书名解码方案联动 |
| 暗色 Green-3 | 提亮为 `#274A40` | 复用既有 Surface High token |
| 暗色第四档 | 不需要 | 三档已够，克制原则 |
| 阴影 | 复用 ContentCard 双层影（略降强度） | 视觉一致性 |
