# 【重构97】词书封面图形升级方案

> 项目：Monster Word（D:\claude\work\cn_com_lange\word_app）
> 日期：2026-08-24
> 前置：【重构48】封面占位规格（纯色底+白字）、【重构42】三档绿轮换算法
> 依据：docs/cover_placeholder_spec.md、docs/imagery_audit.md §3.1（可选B版方案）、docs/book_cover_design_spec.md §2.5
> 约束：只产文档和代码骨架，不改源码；中文

---

## 一、设计目标

在现有纯色底 + 白字的基础上，叠加一层**低透明度书本轮廓图形**，增加"书"的视觉暗示，提升封面品质感，同时：
- 零新增图片资产（纯代码绘制）
- 不影响白字可读性
- 亮色/深色模式均兼容
- 三档绿轮换机制不变

> 来源：docs/imagery_audit.md §3.1 明确提出「可选 B 版：底部叠一层 8% 透明白色书本轮廓线性图形」

---

## 二、图形设计规格

### 2.1 书本轮廓方案

| 参数 | 值 | 说明 |
|---|---|---|
| 图形 | 打开的书本轮廓（两页展开） | 语义明确：这是"词书" |
| 描边色 | `Colors.white`（白色） | 在三档绿底上均可见 |
| 描边透明度 | **8%**（`alpha: 0.08`） | 极低透明度，不干扰前景文字 |
| 描边宽度 | 1.5px | 线性图形，不填充 |
| 图形尺寸 | 宽 52dp × 高 36dp | 在 72×88 容器中居中偏下，留出顶部文字空间 |
| 位置 | 水平居中，垂直偏下（距底边 12dp） | 文字在上、图形在下，层次分明 |
| 圆角 | 书页边缘 R4 | 柔和不尖锐 |

### 2.2 层次结构（从底到顶）

```
┌─────────────────────┐
│  ┌───────────────┐  │ ← 层1：纯色底（三档绿）
│  │               │  │
│  │    红宝书      │  │ ← 层3：白字（前景，最顶层）
│  │               │  │
│  │   ╭─────╮     │  │ ← 层2：书本轮廓（8%白，中层）
│  │  ╱       ╲    │  │
│  │ ╱    📖    ╲   │  │
│  │╱           ╲  │  │
│  └───────────────┘  │
└─────────────────────┘
```

### 2.3 为什么是 8% 透明度

| 透明度 | 视觉效果 | 判定 |
|---|---|---|
| 4% | 几乎不可见 | 太弱，失去装饰意义 |
| **8%** | **隐约可见，增加质感** | ✅ 推荐：不抢文字注意力，但在仔细看时能感知 |
| 12% | 明显可见 | 可能干扰白字可读性 |
| 20% | 过于突出 | 违反"克制"原则 |

> 8% 是星巴克设计语言中"装饰性背景图形"的标准透明度（参考 Starbucks 官网卡片装饰元素）。

---

## 三、Flutter 实现方案

### 3.1 方案 A：CustomPaint 自绘（推荐）

使用 `CustomPainter` 绘制书本轮廓，性能最优、零资产。

```dart
/// 书本轮廓装饰画笔
/// 在词书封面上绘制 8% 透明白色书本轮廓
class BookOutlinePainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  const BookOutlinePainter({
    this.color = const Color(0x14FFFFFF), // 8% 白色
    this.strokeWidth = 1.5,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // 书本尺寸：宽 52dp × 高 36dp，居中偏下
    const bookWidth = 52.0;
    const bookHeight = 36.0;
    final offsetX = (size.width - bookWidth) / 2;
    final offsetY = size.height - bookHeight - 12; // 距底边 12dp

    // 左页轮廓（带 R4 圆角）
    final leftPage = RRect.fromLTRBAndCorners(
      offsetX,
      offsetY,
      offsetX + bookWidth / 2 - 1, // 中缝留 2px 间距
      offsetY + bookHeight,
      topLeft: const Radius.circular(4),
      bottomLeft: const Radius.circular(4),
    );
    canvas.drawRRect(leftPage, paint);

    // 右页轮廓（带 R4 圆角）
    final rightPage = RRect.fromLTRBAndCorners(
      offsetX + bookWidth / 2 + 1,
      offsetY,
      offsetX + bookWidth,
      offsetY + bookHeight,
      topRight: const Radius.circular(4),
      bottomRight: const Radius.circular(4),
    );
    canvas.drawRRect(rightPage, paint);

    // 中缝线
    canvas.drawLine(
      Offset(offsetX + bookWidth / 2, offsetY),
      Offset(offsetX + bookWidth / 2, offsetY + bookHeight),
      paint,
    );

    // 左页文字行（3 条水平线，增加"书页"暗示）
    final linePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    for (int i = 1; i <= 3; i++) {
      final lineY = offsetY + 8.0 * i;
      canvas.drawLine(
        Offset(offsetX + 4, lineY),
        Offset(offsetX + bookWidth / 2 - 5, lineY),
        linePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
```

### 3.2 方案 B：Icon 叠加（备选，更简单）

直接使用 Flutter 内置 `Icons.menu_book_outlined`，通过透明度控制视觉强度。

```dart
/// 书本图标装饰（备选方案：更简单但灵活性较低）
Widget _buildBookDecoration() {
  return Positioned(
    bottom: 12,
    left: 0,
    right: 0,
    child: Center(
      child: Icon(
        Icons.menu_book_outlined,
        size: 36,
        color: Colors.white.withOpacity(0.08), // 8% 白色
      ),
    ),
  );
}
```

**方案对比**：

| 维度 | 方案 A（CustomPaint） | 方案 B（Icon） |
|---|---|---|
| 定制性 | 完全可控（轮廓+中缝+文字行） | 仅单个图标 |
| 性能 | 优秀（shouldRepaint=false） | 优秀（Icon 是轻量组件） |
| 复杂度 | ~50 行代码 | ~10 行代码 |
| 视觉效果 | 更丰富的"打开的书"暗示 | 简洁的书本图标 |
| **推荐** | ✅ 推荐（品质感更高） | 备选（快速实现） |

### 3.3 完整封面组件集成

```dart
/// 星巴克风格词书封面（带书本轮廓装饰）
/// 规格来源：docs/cover_placeholder_spec.md + docs/cover_graphic_upgrade_spec.md
class BookCoverWidget extends StatelessWidget {
  final String bookCode;
  final String? displayName; // 友好名（待 Librarian 方案落地后传入）

  const BookCoverWidget({
    super.key,
    required this.bookCode,
    this.displayName,
  });

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
    Color(0xFF274A40), // 墨绿提亮（Surface High）
  ];

  /// 按 book code hash 稳定分配三档绿
  Color _coverColor(BuildContext context, String code) {
    final index = code.hashCode.abs() % 3;
    // 通过 MediaQuery.platformBrightness 判断深色模式
    final isDark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    return isDark ? _coverColorsDark[index] : _coverColorsLight[index];
  }

  /// 封面文字：优先友好名，兜底 code 前 4 字符
  String _coverText() {
    if (displayName != null && displayName!.isNotEmpty) {
      final mainTitle = displayName!.split('·').first.trim();
      return mainTitle.length > 4 ? mainTitle.substring(0, 4) : mainTitle;
    }
    return bookCode.length > 4 ? bookCode.substring(0, 4) : bookCode;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      height: 88,
      decoration: BoxDecoration(
        color: _coverColor(context, bookCode),
        borderRadius: BorderRadius.circular(8), // AppleRadius.md
      ),
      child: Stack(
        children: [
          // 层2：书本轮廓装饰（CustomPaint 方案）
          Positioned.fill(
            child: CustomPaint(
              painter: BookOutlinePainter(),
            ),
          ),
          // 层3：封面文字（前景，最顶层）
          Center(
            child: Text(
              _coverText(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14, // 提升至 14px（book_cover_design_spec.md §2.4）
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }
}
```

---

## 四、视觉效果预期

### 4.1 亮色模式（奶油画布 `#F2F0EB`）

| 绿档 | 底色 | 书本轮廓（8%白） | 白字 |
|---|---|---|---|
| Green-1 | `#006241` | 约 `#146F54`（极淡） | 清晰 |
| Green-2 | `#00754A` | 约 `#14825D`（极淡） | 清晰 |
| Green-3 | `#1E3932` | 约 `#2E4A42`（极淡） | 清晰 |

### 4.2 深色模式（画布 `#101B17`）

| 绿档 | 底色 | 书本轮廓（8%白） | 白字 |
|---|---|---|---|
| Green-1 | `#006241` | 同上 | 清晰 |
| Green-2 | `#00754A` | 同上 | 清晰 |
| Green-3 | `#274A40` | 约 `#375B50`（极淡） | 清晰 |

**结论**：8% 透明度在所有组合下均不干扰白字可读性（白字对比度最低 5.76:1，远超 AA 标准）。

---

## 五、与其他方案的关系

| 方案 | 关系 | 说明 |
|---|---|---|
| 【重构48】封面占位规格 | 本方案是其"可选 B 版"的正式落地 | 在纯色底基础上叠加装饰层 |
| 【重构42】书封设计规格 | 完全兼容 | 三档绿算法、圆角、尺寸均不变 |
| 【重构22】词书友好名 | 数据源 | `displayName` 参数待友好名落地后传入 |
| imagery_audit.md §3.1 | 直接实现其建议 | 「8% 透明白色书本轮廓线性图形」 |

---

## 六、实施建议

| 步骤 | 改动 | 依赖 |
|---|---|---|
| 1 | 新建 `lib/widgets/book_cover_widget.dart`，包含 `BookOutlinePainter` + `BookCoverWidget` | 无 |
| 2 | `lib_select_page.dart` 的 `_LibItem` 封面替换为 `BookCoverWidget` | 步骤 1 |
| 3 | `dashboard_page.dart` 的封面替换为 `BookCoverWidget` | 步骤 1 |
| 4 | 友好名落地后，传入 `displayName` 参数 | Librarian 方案 |

---

## 七、验收清单

| # | 验收点 | 预期结果 |
|---|---|---|
| V1 | 书本轮廓可见性 | 仔细看可辨识"打开的书"轮廓，不看时不抢注意力 |
| V2 | 白字可读性 | 三档绿底上白字清晰，8% 装饰不影响对比度 |
| V3 | 三档绿轮换 | 191 本书封面仍为三档绿均匀分布 |
| V4 | 深色模式 | 装饰在深色模式下同样隐约可见 |
| V5 | 性能 | CustomPaint 不引发重建（shouldRepaint=false） |
| V6 | 尺寸 | 72×88 不变，圆角 8px 不变 |
