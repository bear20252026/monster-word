# Batch 3 前置：组件层实施规格

> 项目：Monster Word（D:\claude\work\cn_com_lange\word_app）
> 依据：`docs/component_spec.md`（10 类组件）· `docs/pressable_inventory.md`（按压靶点）· `docs/motion_spec.md`（动效 Token）· `docs/ui_inventory.md`（页面映射）
> 范围：Batch 3 组件层新建/修改文件清单 + 核心组件代码骨架 + 依赖关系图
> 约束：只读代码分析，本文档为实施规格，不含运行时改动

---

## 1. 文件清单（lib/widgets/ 新建/修改）

### 1.1 新建文件（8 个）

| 文件 | 对应组件 | 来源 |
|---|---|---|
| `lib/widgets/sb_button.dart` | PillButton | component_spec §1 |
| `lib/widgets/sb_card.dart` | ContentCard | component_spec §2 |
| `lib/widgets/sb_fab.dart` | FrapFab | component_spec §3 |
| `lib/widgets/sb_banner.dart` | StreakBanner (FeatureBand) | component_spec §4 |
| `lib/widgets/sb_badge.dart` | GoldPillBadge | component_spec §5 |
| `lib/widgets/sb_input.dart` | FloatingLabelField | component_spec §6 |
| `lib/widgets/sb_dropdown.dart` | SbDropdown | component_spec §7 |
| `lib/widgets/sb_dialog.dart` | SbModal (居中 + 底部 Sheet) | component_spec §8 |
| `lib/widgets/sb_segmented.dart` | SbSegmented | component_spec §9 |
| `lib/widgets/sb_progress.dart` | SbProgress (线性 + 环形) | component_spec §10 |

### 1.2 修改文件（2 个）

| 文件 | 改动 | 理由 |
|---|---|---|
| `lib/widgets/widget_utils.dart` | ScaleDownOnPress API 升级 | pressable_inventory §5：新增 enableScale / enabled / behavior / triggerAfterRestore 参数，duration 默认 100ms→150ms |
| `lib/tokens/design_tokens.dart` | 新增 `MotionDurations` / `MotionCurves` / `MotionPress` Token 类 | motion_spec §4.3：全局动效 Token，所有新组件引用 |

---

## 2. ScaleDownOnPress 通用包装组件（完整代码）

> 来源：pressable_inventory.md §5 推荐 API + motion_spec.md §4.4 按压标准
> 现有实现：`lib/widgets/widget_utils.dart:12`，增量演进，存量 2 处用法零破坏

```dart
import 'package:flutter/material.dart';

/// 全局动效 Token（建议沉淀到 lib/tokens/design_tokens.dart）
class MotionDurations {
  static const fast = Duration(milliseconds: 150);   // 按压/微变
  static const base = Duration(milliseconds: 200);   // 常规过渡
  static const slow = Duration(milliseconds: 300);   // 展开/转场
  static const expressive = Duration(milliseconds: 450); // 仪式性时刻
}

class MotionCurves {
  /// 默认平滑 ease-out（现有 standardCurve）
  static const standard = Cubic(0.29, 0.09, 0.24, 0.99);
  /// 星巴克手风琴曲线 cubic-bezier(0.25,0.46,0.45,0.94)
  static const accordion = Cubic(0.25, 0.46, 0.45, 0.94);
  /// 星巴克复选框弹性曲线 cubic-bezier(0.32,2.32,0.61,0.27)
  static const springPop = Cubic(0.32, 2.32, 0.61, 0.27);
  /// 退出/离场（现有 splashExitCurve）
  static const exit = Cubic(0.4, 0.0, 0.5, 0.8);
}

class MotionPress {
  static const scale = 0.95; // 星巴克 --buttonActiveScale
}

/// 统一按压缩放包装 —— 星巴克 --buttonActiveScale: 0.95
/// （docs/motion_spec.md §4.4，docs/pressable_inventory.md §5）
class ScaleDownOnPress extends StatefulWidget {
  const ScaleDownOnPress({
    super.key,
    required this.child,
    this.onTap,                            // null ⇒ 整体禁用
    this.enableScale = true,               // false ⇒ 退化为纯点击区域
    this.enabled = true,                   // 语义禁用位
    this.scale = MotionPress.scale,        // 0.95
    this.duration = MotionDurations.fast,  // 150ms
    this.curve = MotionCurves.standard,    // 双向同曲线
    this.behavior,                         // 透传 HitTestBehavior
    this.triggerAfterRestore = true,       // true=恢复后回调（防误触）
  });

  final Widget child;
  final VoidCallback? onTap;
  final bool enableScale;
  final bool enabled;
  final double scale;
  final Duration duration;
  final Curve curve;
  final HitTestBehavior? behavior;
  final bool triggerAfterRestore;

  @override
  State<ScaleDownOnPress> createState() => _ScaleDownOnPressState();
}

class _ScaleDownOnPressState extends State<ScaleDownOnPress>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _hasGivenUp = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _animation = Tween<double>(begin: 1.0, end: widget.scale).animate(
      CurvedAnimation(parent: _controller, curve: widget.curve),
    );
  }

  @override
  void didUpdateWidget(covariant ScaleDownOnPress oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.duration != widget.duration) {
      _controller.duration = widget.duration;
    }
    if (oldWidget.scale != widget.scale) {
      _animation = Tween<double>(begin: 1.0, end: widget.scale).animate(
        CurvedAnimation(parent: _controller, curve: widget.curve),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _isInteractive => widget.onTap != null && widget.enabled;

  void _onTapDown(TapDownDetails _) {
    if (!_isInteractive || !widget.enableScale) return;
    _hasGivenUp = false;
    _controller.forward();
  }

  void _onTapUp(TapUpDetails _) {
    _releaseAnimation(triggerClick: true);
  }

  void _onTapCancel() {
    if (!_hasGivenUp) {
      _releaseAnimation(triggerClick: false);
    }
  }

  void _releaseAnimation({required bool triggerClick}) {
    if (!widget.enableScale) {
      if (triggerClick && _isInteractive && mounted) {
        widget.onTap?.call();
      }
      return;
    }
    _controller.reverse().then((_) {
      if (triggerClick && _isInteractive && mounted) {
        widget.onTap?.call();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final child = widget.enableScale
        ? ScaleTransition(scale: _animation, child: widget.child)
        : widget.child;

    if (!_isInteractive) return child;

    return GestureDetector(
      behavior: widget.behavior,
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: child,
    );
  }
}
```

**迁移要点**：
- 现有 `check_in_widgets.dart` 2 处用法无需改动（默认参数兼容）
- `input_controls.dart:277` 自实现按压缩放并入此组件后删除第二套实现
- 131 处裸 GestureDetector 靶点按 pressable_inventory §3 清单逐个包装

---

## 3. PillButton 组件（完整代码骨架）

> 来源：component_spec.md §1

```dart
import 'package:flutter/material.dart';
import '../tokens/design_tokens.dart';
import 'widget_utils.dart'; // ScaleDownOnPress

/// 星巴克胶囊主按钮 —— 50px 全胶囊 + scale(0.95) 按压
/// 四变体：主款(绿底白字) / 描边款(透明底绿框绿字) / 黑款(黑底白字) / 反白款(白底绿字)
class PillButton extends StatelessWidget {
  const PillButton({
    super.key,
    required this.label,
    this.onTap,
    this.fill = const Color(0xFF00754A),    // Green Accent
    this.textColor = Colors.white,
    this.side = BorderSide.none,
  });

  /// 主款：绿底白字
  const PillButton.primary({
    super.key,
    required this.label,
    this.onTap,
  })  : fill = const Color(0xFF00754A),
       textColor = Colors.white,
       side = BorderSide.none;

  /// 描边款：透明底绿框绿字
  const PillButton.outlined({
    super.key,
    required this.label,
    this.onTap,
  })  : fill = Colors.transparent,
       textColor = const Color(0xFF00754A),
       side = const BorderSide(color: Color(0xFF00754A));

  /// 黑款：黑底白字
  const PillButton.dark({
    super.key,
    required this.label,
    this.onTap,
  })  : fill = const Color(0xFF000000),
       textColor = Colors.white,
       side = BorderSide.none;

  /// 反白款（深底上用）：白底绿字
  const PillButton.inverse({
    super.key,
    required this.label,
    this.onTap,
  })  : fill = Colors.white,
       textColor = const Color(0xFF00754A),
       side = BorderSide.none;

  final String label;
  final VoidCallback? onTap;
  final Color fill;
  final Color textColor;
  final BorderSide side;

  @override
  Widget build(BuildContext context) {
    return ScaleDownOnPress(
      onTap: onTap,
      child: Material(
        color: fill,
        shape: StadiumBorder(side: side),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.16, // -0.01em @16px，仅西文
                color: null, // 由 fill 推导或显式传入
              ).copyWith(color: textColor),
            ),
          ),
        ),
      ),
    );
  }
}
```

---

## 4. ContentCard 组件（完整代码骨架）

> 来源：component_spec.md §2

```dart
import 'package:flutter/material.dart';

/// 星巴克内容卡片 —— 12px 白卡 + 双层低透明阴影
/// 一切内容容器的母体；画布必须是奶油色 #F2F0EB
class ContentCard extends StatelessWidget {
  const ContentCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.color = Colors.white,
    this.borderRadius = 12.0,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final Color color;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: const [
          // 层1：贴地晕（环境光）
          BoxShadow(
            offset: Offset.zero,
            blurRadius: 0.5,
            color: Color(0x24000000), // rgba(0,0,0,.14)
          ),
          // 层2：方向光
          BoxShadow(
            offset: Offset(0, 1),
            blurRadius: 1,
            color: Color(0x3D000000), // rgba(0,0,0,.24)
          ),
        ],
      ),
      child: Padding(
        padding: padding,
        child: child,
      ),
    );
  }
}
```

---

## 5. FrapFab 组件（完整代码骨架）

> 来源：component_spec.md §3

```dart
import 'package:flutter/material.dart';
import 'widget_utils.dart'; // ScaleDownOnPress

/// 星巴克 Frap 悬浮圆钮 —— 56px 圆形 + 双层阴影 + 触控外扩 8px
/// 学习页常驻「开始学习」入口
class FrapFab extends StatelessWidget {
  const FrapFab({
    super.key,
    this.icon = Icons.play_arrow_rounded,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      // 触控外扩 8px（视觉边缘外补足命中区）
      padding: const EdgeInsets.all(8),
      child: ScaleDownOnPress(
        onTap: onTap,
        child: Container(
          width: 56,
          height: 56,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              // 基础光环：rgba(0,0,0,.24)
              BoxShadow(
                blurRadius: 6,
                color: Color(0x3D000000),
              ),
              // 环境投影：rgba(0,0,0,.14)
              BoxShadow(
                offset: Offset(0, 8),
                blurRadius: 12,
                color: Color(0x24000000),
              ),
            ],
          ),
          child: Material(
            color: const Color(0xFF00754A), // Green Accent
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: Icon(icon, size: 30, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}
```

---

## 6. 组件 → 使用页面映射

> 来源：ui_inventory.md + component_spec.md 各组件「App 映射」段

| 组件 | 使用页面（可达 ✅ 优先） | 使用页面（孤儿/死路由） |
|---|---|---|
| **PillButton** | home_screen ✅（打卡 CTA）、learn_page ✅（答题确认）、review_session ✅、login_page ✅、splash_page ✅ | class_checkin、exam_quick_review、sentence_quiz |
| **ContentCard** | home_screen ✅（打卡卡/入口卡）、learn_page ✅（答题区容器）、word_detail_page ✅（释义块容器）、lib_select_page ✅（词书卡）、profile_screen ✅（统计卡）、dictionary_page ✅ | dashboard、my_content、courses |
| **FrapFab** | home_screen ✅（「开始学习」悬浮入口） | — |
| **StreakBanner** | home_screen ✅（连续打卡横幅） | class_checkin |
| **GoldPillBadge** | profile_screen ✅（成就/酷币区）、word_detail_page ✅（星标计数）、home_screen ✅（打卡奖励角标） | — |
| **FloatingLabelField** | search_page ✅（查词主输入）、login_page ✅（手机号/验证码）、lib_select_page ✅（书库搜索框） | user_item_modify |
| **SbDropdown** | more_settings_page ✅（设置选择器） | play_order、appearance、settings_page |
| **SbModal** | home_screen ✅（复习确认弹窗）、more_settings_page ✅（7 个底部弹窗） | word_lookup_popup、word_dictionary_popup |
| **SbSegmented** | learn_session ✅ / review_session ✅（模式切换） | dictionary_page（三 Tab）、extensive_model_select |
| **SbProgress** | home_screen ✅（今日目标进度）、learn_page ✅ / review_session ✅（答题进度） | dashboard（进度环）、splash（加载环） |

---

## 7. 依赖关系图（建造顺序）

```
第 0 层（无依赖，立即可建）
├── MotionDurations / MotionCurves / MotionPress   ← design_tokens.dart 新增
├── ScaleDownOnPress                                ← widget_utils.dart 升级
├── ContentCard                                     ← 纯 StatelessWidget，零依赖
└── SbProgress                                      ← 纯动画，零依赖

第 1 层（依赖第 0 层）
├── PillButton           ← 依赖 ScaleDownOnPress
├── StreakBanner         ← 依赖 PillButton（CTA 钮组）
├── GoldPillBadge        ← 纯样式组件，仅依赖 Token 色值
├── FloatingLabelField   ← 依赖 MotionDurations / MotionCurves
├── SbDropdown           ← 依赖 MotionDurations
└── SbSegmented          ← 依赖 MotionDurations / MotionCurves

第 2 层（依赖第 1 层）
├── FrapFab              ← 依赖 ScaleDownOnPress
└── SbModal              ← 依赖 ContentCard（弹层内嵌白卡）、MotionDurations
```

**实施顺序建议**：
1. **第一批**（Day 1）：design_tokens.dart 补 Motion Token → ScaleDownOnPress 升级 → ContentCard → SbProgress
2. **第二批**（Day 2）：PillButton → StreakBanner → GoldPillBadge → FloatingLabelField
3. **第三批**（Day 3）：SbDropdown → SbSegmented → FrapFab → SbModal

> 每批产出可独立验收；第 0 层组件无依赖可并行开发。
