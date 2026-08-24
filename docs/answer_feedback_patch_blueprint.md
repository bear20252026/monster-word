# 答题反馈补丁蓝图：7 项机械补丁单

> 任务：【重构44】悬空控制器修复等 7 项机械补丁单
> 依据：`docs/learn_flow_motion_storyboard.md`（分镜 S2/S3）、`docs/motion_spec.md`（五档曲线 Token）、`docs/touch_target_audit.md`（P0 间距）、`lib/pages/learn_page.dart` / `lib/screens/review_session.dart`（只读分析）
> 状态：**蓝图阶段**——当前提交权在批1（串行纪律），本文件为后续实施提供纯机械操作清单

---

## 补丁总览

| # | 补丁名称 | 目标文件 | 对应分镜 | 预估 diff 行数 |
|---|---|---|---|---|
| P1 | 悬空 `_bounceController` 修复 + 绿色确认态 | learn_page.dart | S3 F1-F3 | ~45 行 |
| P2 | 对勾 springPop 弹入 | learn_page.dart | S3 F2 | ~25 行 |
| P3 | 抖动收敛 ±6px/400ms → ±3px/300ms | animations.dart + learn_page.dart | S2 F3 | ~15 行 |
| P4 | 答对后防重复点击 guard | learn_page.dart | S3 全局 | ~8 行 |
| P5 | 四选项间距 8 → 16dp | learn_page.dart | S2 P0 | ~2 行 |
| P6 | SRS 三键 12dp 实体间距 | review_session.dart | S2 P0 | ~3 行 |
| P7 | 其余选项答对后降权 0.40 | learn_page.dart | S3 F4 | ~30 行 |

**总预估 diff**：~128 行（不含注释）
**建议拆分为 3 个独立可回滚的 commit**（见第 5 节）

---

## 依赖说明

### 已存在的控制器 / 曲线（可直接复用）

| 名称 | 位置 | 说明 |
|---|---|---|
| `_shakeController` | learn_page.dart:237 | 400ms，驱动 ShakeWidget |
| `_bounceController` | learn_page.dart:240 | 300ms，已初始化但 UI 未挂接 |
| `ShakeWidget` | animations.dart:60-79 | 横向抖动包装器，接收 controller |
| `BounceWidget` | animations.dart:94-120 | scale 弹跳包装器，接收 controller |
| `buildShakeAnim` | animations.dart:82-90 | TweenSequence ±6px/5 cycles |
| `buildBounceAnim` | animations.dart:115-120 | TweenSequence 1→1.08→1 |
| `standardCurve` | animations.dart:46 | Cubic(0.29, 0.09, 0.24, 0.99) |
| `ScaleDownOnPress` | widget_utils.dart:12-80 | 按压缩放包装器 |

### 需要新增的 Token（建议先落地 motion_tokens.dart）

```dart
// lib/theme/motion_tokens.dart（批2 Token 层落地后才可用；蓝图中以注释标注替代写法）
class MotionDurations {
  static const fast = Duration(milliseconds: 150);
  static const base = Duration(milliseconds: 200);
  static const slow = Duration(milliseconds: 300);
}

class MotionCurves {
  static const standard = Cubic(0.29, 0.09, 0.24, 0.99); // == standardCurve
  static const springPop = Cubic(0.32, 2.32, 0.61, 0.27);
  static const exit = Cubic(0.4, 0.0, 0.5, 0.8);
}
```

> **临时兼容**：批3 之前可用 `const Duration(milliseconds: 200)` 等裸值 + 注释 `// TODO: replace with MotionDurations.base`，批2 Token 层落地后统一替换。

---

## 补丁 P1：悬空 `_bounceController` 修复 + 绿色确认态

**对应分镜**：S3 F1（变绿）、F3（卡片微弹）
**根因**：learn_page.dart:278 `_bounceController.forward(from: 0)` 被调用，但 build 方法中无任何 Widget 通过该 controller 驱动动画——用户答对后画面静止 400ms 直接跳页。

### 修改位置：learn_page.dart `_QuizAreaState` 类

#### 1a. 新增 `correctIndex` 状态字段

**位置**：`_QuizAreaState` 类顶部，`_wrongIndex` 声明之后（约 line 234）

```dart
// --- PATCH P1a: 答对索引，用于绿色确认态 ---
int _correctIndex = -1; // -1=未答对
```

#### 1b. 修改 `_onChoice` 方法——记录答对索引

**位置**：`_onChoice` 方法（line 273-288），`isCorrect` 分支内

**现状代码**：
```dart
if (isCorrect) {
  // 选对：评分 + 弹跳反馈，跳转字典详情页
  widget.state.rate(RecallRating.good);
  _bounceController.forward(from: 0);
  setState(() {});
  Future.delayed(const Duration(milliseconds: 400), () {
    if (mounted) Navigator.pushNamed(context, '/word_detail');
  });
}
```

**替换为**：
```dart
if (isCorrect) {
  // --- PATCH P1b: 记录答对索引，驱动绿色确认态 + 弹跳 ---
  widget.state.rate(RecallRating.good);
  setState(() => _correctIndex = i);
  _bounceController.forward(from: 0);
  Future.delayed(const Duration(milliseconds: 400), () {
    if (mounted) Navigator.pushNamed(context, '/word_detail');
  });
}
```

#### 1c. 修改 `didUpdateWidget`——重置答对状态

**位置**：`didUpdateWidget`（line 264-271），`_wrongIndex = -1` 之后

**追加一行**：
```dart
_correctIndex = -1; // --- PATCH P1c ---
```

#### 1d. 修改 `_buildChoice` 方法——三态分支（红/绿/默认）

**位置**：`_buildChoice` 方法（line 316-361），颜色判断逻辑

**现状代码**（line 322-329）：
```dart
Color bgColor;
Color borderColor;
if (isWrong) {
  bgColor = const Color(0xFFE8A0A0).withOpacity(0.6);
  borderColor = const Color(0xFFE8A0A0);
} else {
  bgColor = Colors.white.withOpacity(0.25);
  borderColor = Colors.white.withOpacity(0.3);
}
```

**替换为**：
```dart
// --- PATCH P1d: 三态颜色（红/绿/默认）---
final isCorrect = i == _correctIndex;
Color bgColor;
Color borderColor;
if (isCorrect) {
  bgColor = const Color(0xFF4CAF50).withOpacity(0.35); // 成功绿，低透明度
  borderColor = const Color(0xFF4CAF50);
} else if (isWrong) {
  bgColor = const Color(0xFFE8A0A0).withOpacity(0.6);
  borderColor = const Color(0xFFE8A0A0);
} else {
  bgColor = Colors.white.withOpacity(0.25);
  borderColor = Colors.white.withOpacity(0.3);
}
```

#### 1e. 将 `_bounceController` 接入 BounceWidget 包裹 tile

**位置**：`_buildChoice` 方法末尾，`return tile;` 之前（line 360）

**现状**：
```dart
return tile;
```

**替换为**：
```dart
// --- PATCH P1e: 答对项接入 BounceWidget ---
if (isCorrect) {
  tile = BounceWidget(controller: _bounceController, child: tile);
}
return tile;
```

> **注意**：`_bounceController` 的 duration 已是 300ms（line 251），`buildBounceAnim` 在 `BounceWidget` 内部通过 `AnimatedWidget` 驱动——但当前 `BounceWidget` 直接读 `listenable as Animation<double>`，需要确认 `buildBounceAnim` 的结果已被赋值给 controller。现状 `BounceWidget` 使用方式是 controller 直接驱动（无显式 Tween），需在 initState 中设置：
>
> ```dart
> _bounceController = AnimationController(
>   duration: const Duration(milliseconds: 300),
>   vsync: this,
> );
> // 将 buildBounceAnim 的结果作为 controller 的默认动画
> // BounceWidget 内部通过 listenable 读取值，需确保 forward 时有正确插值
> ```
>
> **实际做法**：BounceWidget 继承 AnimatedWidget，直接 listen controller——controller.value 从 0→1 线性变化，但 buildBounceAnim 返回的是 TweenSequence 动画。**需要修改 BounceWidget 接收一个显式 Animation<double> 而非 controller**，或者改用 `AnimatedBuilder`。
>
> **更简方案**：不修改 BounceWidget，改用 `ScaleTransition` + `buildBounceAnim`：

```dart
// --- PATCH P1e（替代方案）: 用 ScaleTransition + buildBounceAnim ---
if (isCorrect) {
  final bounceAnim = buildBounceAnim(_bounceController);
  tile = ScaleTransition(scale: bounceAnim, child: tile);
}
return tile;
```

---

## 补丁 P2：对勾 springPop 弹入

**对应分镜**：S3 F2（对勾图标 scale 0.6→1.0 弹入 + 淡入）
**依赖**：`MotionCurves.springPop`（批2 Token 层）或临时 `const Cubic(0.32, 2.32, 0.61, 0.27)`

### 修改位置：learn_page.dart `_QuizAreaState` 类

#### 2a. 新增对勾动画控制器

**位置**：initState 中，`_bounceController` 初始化之后（约 line 253）

```dart
// --- PATCH P2a: 对勾 springPop 控制器 ---
_checkController = AnimationController(
  duration: const Duration(milliseconds: 200), // base 档
  vsync: this,
);
```

**声明**（类顶部，`_bounceController` 之后）：
```dart
late AnimationController _checkController;
```

**dispose**（line 257-260）追加：
```dart
_checkController.dispose();
```

**didUpdateWidget**（line 264-271）追加重置：
```dart
_checkController.reset();
```

#### 2b. 修改 `_onChoice`——答对时触发对勾动画

**位置**：`_onChoice` 的 `isCorrect` 分支，`_bounceController.forward` 之后

```dart
_checkController.forward(from: 0); // --- PATCH P2b ---
```

#### 2c. 在 `_buildChoice` 中答对项添加对勾图标

**位置**：`_buildChoice` 方法，tile 构建逻辑中。将 `GestureDetector > AnimatedContainer` 改为 `Stack`，右侧叠加对勾图标。

**现状 tile 结构**（line 331-353）：
```dart
Widget tile = GestureDetector(
  onTap: () => _onChoice(i),
  child: AnimatedContainer(
    // ... 现有内容
  ),
);
```

**替换为**：
```dart
// --- PATCH P2c: 答对项右侧叠加对勾图标 ---
Widget tile = GestureDetector(
  onTap: () => _onChoice(i),
  child: Stack(
    alignment: Alignment.centerRight,
    children: [
      AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 56,
        margin: const EdgeInsets.only(bottom: 16), // P5: 间距 8→16
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor, width: 0.5),
        ),
        child: Center(
          child: Text(interpret,
            style: TextStyle(
              fontSize: 16,
              color: isCorrect
                  ? const Color(0xFF2E7D32) // 深绿文字
                  : Colors.white,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 2, overflow: TextOverflow.ellipsis),
        ),
      ),
      // 对勾图标：springPop 弹入
      if (isCorrect)
        Padding(
          padding: const EdgeInsets.only(right: 14),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.6, end: 1.0).animate(
              CurvedAnimation(
                parent: _checkController,
                curve: const Cubic(0.32, 2.32, 0.61, 0.27), // springPop
              ),
            ),
            child: FadeTransition(
              opacity: _checkController,
              child: const Icon(
                Icons.check_circle_outline,
                color: Color(0xFF2E7D32),
                size: 24,
              ),
            ),
          ),
        ),
    ],
  ),
);
```

> **注意**：`isCorrect` 变量需在 `_buildChoice` 方法开头计算（P1d 已定义）。若 P1d 与 P2c 同时落地，合并颜色逻辑即可。

---

## 补丁 P3：抖动收敛 ±6px/400ms → ±3px/300ms 单周期

**对应分镜**：S2 F3（微抖收敛）
**改动范围**：animations.dart + learn_page.dart

### 3a. 修改 `buildShakeAnim` 参数化

**位置**：animations.dart:82-90

**现状代码**：
```dart
Animation<double> buildShakeAnim(AnimationController controller) {
  return TweenSequence<double>([
    for (int i = 0; i < 5; i++) ...[
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -6.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -6.0, end: 6.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 6.0, end: 0.0), weight: 1),
    ],
  ]).animate(CurvedAnimation(parent: controller, curve: Curves.linear));
}
```

**替换为**（新增参数化重载，保留旧签名兼容）：
```dart
/// 参数化版本：可指定幅度和周期数
/// [amplitude] 抖动幅度（像素），[cycles] 周期数
Animation<double> buildShakeAnim(
  AnimationController controller, {
  double amplitude = 6.0,
  int cycles = 5,
}) {
  return TweenSequence<double>([
    for (int i = 0; i < cycles; i++) ...[
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -amplitude), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -amplitude, end: amplitude), weight: 2),
      TweenSequenceItem(tween: Tween(begin: amplitude, end: 0.0), weight: 1),
    ],
  ]).animate(CurvedAnimation(parent: controller, curve: Curves.linear));
}
```

> **兼容性**：旧调用 `buildShakeAnim(controller)` 不受影响（默认值 amplitude=6, cycles=5）。

### 3b. 修改 learn_page.dart `_shakeController` duration

**位置**：learn_page.dart:245-248

**现状**：
```dart
_shakeController = AnimationController(
  duration: const Duration(milliseconds: 400),
  vsync: this,
);
```

**替换为**：
```dart
// --- PATCH P3b: 收敛为 slow 档 300ms ---
_shakeController = AnimationController(
  duration: const Duration(milliseconds: 300), // motion_spec: slow 档
  vsync: this,
);
```

### 3c. 修改 `_buildChoice` 中 ShakeWidget 的调用

**位置**：learn_page.dart `_buildChoice` 方法，`ShakeWidget` 包裹处（约 line 356-358）

**现状**：
```dart
if (isWrong) {
  tile = ShakeWidget(controller: _shakeController, child: tile);
}
```

> ShakeWidget 内部使用 `listenable as Animation<double>` 直接读 controller.value。
> 但 `buildShakeAnim` 返回的是 TweenSequence 动画，需要在 initState 中构建并赋值。

**实际做法**：ShakeWidget 需要接收一个 Animation<double>，而非 controller。

**方案A（推荐——不改 ShakeWidget 签名）**：在 initState 中预构建动画，用 `AnimatedBuilder` 替代 `ShakeWidget`：

```dart
// --- PATCH P3c: 替换 ShakeWidget 为 AnimatedBuilder + 参数化抖动 ---
if (isWrong) {
  tile = AnimatedBuilder(
    animation: _shakeController,
    builder: (context, child) {
      // 实时计算抖动偏移（单周期 ±3px）
      final t = _shakeController.value;
      final offset = _computeShakeOffset(t, amplitude: 3.0, cycles: 1);
      return Transform.translate(offset: Offset(offset, 0), child: child);
    },
    child: tile,
  );
}
```

**新增辅助函数**（learn_page.dart 文件顶部或 `_QuizAreaState` 内）：
```dart
/// 单周期抖动偏移计算（替代 TweenSequence，更轻量）
double _computeShakeOffset(double t, {double amplitude = 3.0, int cycles = 1}) {
  // 单周期：0→-amp→+amp→0，权重 1:2:1
  final phase = (t * cycles * 4) % 4;
  if (phase < 1) return -amplitude * phase;
  if (phase < 3) return -amplitude + amplitude * (phase - 1);
  return amplitude - amplitude * (phase - 3);
}
```

> **为什么不用 buildShakeAnim**：ShakeWidget 直接读 controller.value（线性 0→1），而 buildShakeAnim 返回的 TweenSequence 需要单独的 Animation 对象。为避免改动 ShakeWidget 签名影响其它调用点，改用 AnimatedBuilder 直接在 builder 中计算偏移，效果完全等价。

---

## 补丁 P4：答对后防重复点击 guard

**对应分镜**：S3 全局安全
**根因**：现状 `_onChoice` 无 guard，400ms 窗口内连点可触发多次 `pushNamed`

### 修改位置：learn_page.dart `_onChoice` 方法（line 273）

**现状**：
```dart
void _onChoice(int i) {
  final isCorrect = widget.state.choices[i].word == widget.word.word;
  if (isCorrect) {
    // ...
```

**替换为**：
```dart
void _onChoice(int i) {
  // --- PATCH P4: 防重复点击 guard ---
  if (_correctIndex >= 0) return; // 已答对，屏蔽后续 tap
  final isCorrect = widget.state.choices[i].word == widget.word.word;
  if (isCorrect) {
    // ...
```

> **与 P1b 的合并**：P1b 已在 isCorrect 分支内 `setState(() => _correctIndex = i)`，guard 读取该状态即可。此补丁仅需在方法入口加一行 `if (_correctIndex >= 0) return;`。

---

## 补丁 P5：四选项间距 8 → 16dp

**对应分镜**：S2 触控审计 P0
**改动范围**：learn_page.dart `_buildChoice` 方法

### 修改位置：learn_page.dart `_buildChoice` 方法，`AnimatedContainer` 的 `margin`（line 337）

**现状**：
```dart
margin: const EdgeInsets.only(bottom: 8),
```

**替换为**：
```dart
margin: const EdgeInsets.only(bottom: 16), // --- PATCH P5: 触控审计 P0 间距 ---
```

> **影响**：四选项总高度增加约 32dp（4×8→4×16），在 56px 高 tile + 16dp 间距下总高约 304dp，仍在常见屏幕（667dp+）的安全区内。若空间紧张，可将 tile 高度从 56 降至 52（仍在触控 48dp 基线之上）。

---

## 补丁 P6：SRS 三键 12dp 实体间距

**对应分镜**：S2 触控审计 P0
**改动范围**：review_session.dart `_buildVerdictRow` 方法

### 修改位置：review_session.dart `_buildVerdictRow`（line 249-259）

**现状**：
```dart
Widget _buildVerdictRow(SkinSystem skin) {
  return Container(
    padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
    child: Row(
      children: [
        _verdictBtn('认识', skin.colors.teal, () => _rate(RecallRating.good), skin),
        _verdictBtn('模糊', skin.colors.accent, () => _rate(RecallRating.hard), skin),
        _verdictBtn('忘记了', skin.colors.danger, () => _rate(RecallRating.again), skin),
      ],
    ),
  );
}
```

**替换为**：
```dart
Widget _buildVerdictRow(SkinSystem skin) {
  return Container(
    padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
    child: Row(
      children: [
        Expanded(child: _verdictBtn('认识', skin.colors.teal, () => _rate(RecallRating.good), skin)),
        const SizedBox(width: 12), // --- PATCH P6: 触控审计 P0 三键间距 ---
        Expanded(child: _verdictBtn('模糊', skin.colors.accent, () => _rate(RecallRating.hard), skin)),
        const SizedBox(width: 12), // --- PATCH P6 ---
        Expanded(child: _verdictBtn('忘记了', skin.colors.danger, () => _rate(RecallRating.again), skin)),
      ],
    ),
  );
}
```

> **同时需移除** `_verdictBtn` 内部的 `Expanded` 包裹（line 263），因为 `Expanded` 已移到外层：
>
> **现状**（line 262-278）：
> ```dart
> Widget _verdictBtn(String label, Color color, VoidCallback onTap, SkinSystem skin) {
>   return Expanded(  // ← 移除此行
>     child: GestureDetector(
>       onTap: onTap,
>       child: Container(
>         height: 48,
>         // ...
>       ),
>     ),
>   );  // ← 移除此行
> }
> ```
>
> **替换为**：
> ```dart
> Widget _verdictBtn(String label, Color color, VoidCallback onTap, SkinSystem skin) {
>   return GestureDetector(
>     onTap: onTap,
>     child: Container(
>       height: 48,
>       decoration: BoxDecoration(
>         border: Border(bottom: BorderSide(color: color, width: AppUnderline.thickness)),
>       ),
>       child: Center(
>         child: Text(label,
>             style: AppTypography.body.copyWith(color: skin.colors.onGlassText1)),
>       ),
>     ),
>   );
> }
> ```

---

## 补丁 P7：其余选项答对后降权 0.40

**对应分镜**：S3 F4（其余三个选项降权 opacity→0.40）
**改动范围**：learn_page.dart `_buildChoice` 方法

### 修改位置：learn_page.dart `_buildChoice` 方法，tile 外层包裹

**在 P1e/P2c 的 tile 构建之后、return 之前**，追加降权逻辑：

```dart
// --- PATCH P7: 答对后其余选项降权 0.40 ---
if (_correctIndex >= 0 && !isCorrect) {
  tile = AnimatedOpacity(
    opacity: 0.40,
    duration: const Duration(milliseconds: 200), // base 档
    curve: standardCurve,
    child: tile,
  );
}
```

> **时序**：此 AnimatedOpacity 在 `_correctIndex` 被 setState 设置后立即生效（下一帧 rebuild），比分镜要求的 T1+150ms 略早——但由于 P1 的 BounceWidget 和 P2 的 springPop 同时在播放，视觉上降权与弹入是并行的，符合分镜"聚焦正确项"的意图。
>
> **精确延迟版**（可选，若需严格对齐 T1+150ms）：
> ```dart
> // 在 _onChoice 的 isCorrect 分支中：
> Future.delayed(const Duration(milliseconds: 150), () {
>   if (mounted) setState(() {}); // 触发其余选项的 AnimatedOpacity
> });
> ```
> 但这会增加状态管理复杂度，建议先用即时版验收，若视觉节奏不对再加延迟。

---

## 风险点与状态机接入顺序

### 1. 状态机优先级

```
_correctIndex >= 0  →  答对终局，屏蔽所有后续 tap（P4 guard）
_wrongIndex >= 0    →  选错标红 + 抖动，允许重选
两者互斥：答对后 _wrongIndex 不再更新
```

**接入顺序建议**：
1. 先落地 P4（guard），确保不会有多次 pushNamed 的风险
2. 再落地 P1（绿色态 + 弹跳），此时答对有视觉反馈但无对勾
3. 最后落地 P2（对勾）+ P7（降权），完善反馈链

### 2. `_bounceController` 的动画类型问题

**现状**：`BounceWidget` 直接 listen controller，但 controller.value 是线性 0→1，而 `buildBounceAnim` 返回的是 TweenSequence 动画。

**解决方案**（已在 P1e 中说明）：改用 `ScaleTransition(scale: buildBounceAnim(_bounceController), child: tile)`，不修改 BounceWidget 签名。

### 3. P3 抖动收敛与现有 ShakeWidget 的兼容

**现状**：`ShakeWidget` 读 `listenable as Animation<double>`，即 controller.value（线性 0→1）。
**问题**：`buildShakeAnim` 返回的是 TweenSequence 动画，不是 controller 本身。
**解决方案**：P3c 已改用 `AnimatedBuilder` + `_computeShakeOffset`，完全绕过 ShakeWidget，无兼容风险。

### 4. P6 的 Expanded 嵌套冲突

**现状**：`_verdictBtn` 内部有 `Expanded`，外层 `Row` 直接放三个 `_verdictBtn`。
**修改后**：外层 `Row` 放 `Expanded > _verdictBtn` + `SizedBox`，需移除 `_verdictBtn` 内部的 `Expanded`。
**风险**：若遗漏移除内部 `Expanded`，会触发 "Incorrect use of ParentDataWidget" 运行时错误。**必须同步修改两处**。

### 5. P5 间距扩大对布局的影响

四选项总高从 `4×56 + 3×8 = 248dp` 增至 `4×56 + 3×16 = 272dp`，增加 24dp。
在 `_QuizArea` 的 `Expanded(flex: 6)` 容器内，需确认不会溢出——建议在小屏设备（567dp 高）上验证。

---

## 建议 Commit 拆分方案

### Commit 1：安全修复（P4 + P6）
- **P4**：防重复点击 guard（1 行）
- **P6**：SRS 三键 12dp 间距（~10 行，含 _verdictBtn 改造）
- **理由**：纯安全修复，零视觉变化，可独立回滚
- **验证**：连点答对不会多次跳页；三键间距目视 12dp
- **commit message**：`fix(quiz): prevent double-tap navigation, add 12dp spacing to SRS verdict buttons`

### Commit 2：视觉反馈修复（P1 + P2 + P7）
- **P1**：悬空控制器修复 + 绿色确认态（~45 行）
- **P2**：对勾 springPop 弹入（~25 行）
- **P7**：其余选项降权 0.40（~5 行）
- **理由**：三者共同构成"答对反馈链"，拆开后单独落地视觉不完整
- **验证**：答对→变绿+对勾弹入+其余变暗→400ms 后跳详情
- **commit message**：`feat(quiz): wire correct-answer feedback chain (green state, checkmark springPop, dim others)`

### Commit 3：动效收敛（P3 + P5）
- **P3**：抖动收敛 ±3px/300ms（~15 行）
- **P5**：四选项间距 16dp（1 行）
- **理由**：动效参数调整，与功能修复正交
- **验证**：选错抖动幅度明显收敛；间距目视 16dp
- **commit message**：`refactor(quiz): converge shake to ±3px/300ms, widen choice gap to 16dp`

---

## 验收清单

| 验收项 | 操作 | 预期结果 |
|---|---|---|
| A1 | 答对任意单词 | 选中项变绿 + 对勾 springPop 弹入 + 卡片微弹 + 其余三项变暗 0.40 |
| A2 | 答对后 400ms 内连点其它选项 | 无反应（guard 生效） |
| A3 | 答对后自动跳转字典详情页 | 400ms 后平滑跳转 |
| A4 | 选错任意选项 | 标红 + 微抖（幅度明显小于现状）+ 变暗 0.55 |
| A5 | 选错后立即点其它选项 | 立即响应（不等抖动结束） |
| A6 | 四选项间距 | 目视 16dp（约一个手指宽度的间隙） |
| A7 | SRS 三键间距 | 认识/模糊/忘记了 之间有 12dp 间隙 |
| A8 | 连续答对 5 题 | 每题反馈完整，无卡顿或状态残留 |

---

*本蓝图基于 2026-08-24 代码主干，所有行号以当日代码为准。实施时请先确认行号是否偏移。*
