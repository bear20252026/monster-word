# Monster Word 动效规范（Motion Spec）

> 任务：【重构7】动效规范 —— 星巴克动效语言 → Flutter 映射
> 依据：项目根 `DESIGN.md`（星巴克视觉/交互规范）+ 现有代码盘点（只读分析）
> 本文档是**规范建议**，不含任何代码改动；落地迁移见 §7。

---

## 1. 星巴克动效语言的提炼

从 `DESIGN.md` 中提取出的动效规格共 4 条核心条款，外加隐含的 3 条设计原则。

### 1.1 四条核心规格

| 场景 | 星巴克原始规格（CSS） | 动效意图 |
| --- | --- | --- |
| **按钮按压** | `transform: scale(0.95)`（`--buttonActiveScale`），`transition: all 0.2s ease` | 按下物理感：轻微缩小 + 快速回弹 |
| **手风琴 / 展开收起** | `300ms cubic-bezier(0.25, 0.46, 0.45, 0.94)`（measured ease-out） | 内容展开快进慢出，克制不夸张 |
| **复选框 / 单选选中** | `0.3s cubic-bezier(0.32, 2.32, 0.61, 0.27)`（springy overshoot） | 选中确认时的一次性微弹（y 值 >1 产生过冲） |
| **图片淡入** | `opacity 0.3s ease-in` | 加载完成后安静浮现，不做位移 |

### 1.2 三条设计原则

1. **克制（Restraint）**：动效服务于状态表达，不做纯装饰；时长短、幅度小、一次性（不循环、不闪烁）。
2. **快速响应（Responsiveness）**：所有用户触发的反馈 ≤300ms 完成，按压类反馈必须 <200ms 让用户感到"立即生效"。
3. **缓动家族化（Easing Family）**：
   - **进入/展开** → ease-out 家族（起步快、收尾缓）
   - **选中/确认** → 弹性过冲家族（一次微弹即止）
   - **退出/消失** → ease-in 家族（加速离场）

---

## 2. 星巴克动效 → Flutter 逐条映射

### 2.1 缓动曲线映射表

| 星巴克（CSS） | 数学定义 | Flutter 表达 | 说明 |
| --- | --- | --- | --- |
| `ease`（按钮 0.2s） | `cubic-bezier(0.25, 0.1, 0.25, 1)` | **`Curves.ease`** | 二者贝塞尔完全相同，可直接替换 |
| measured ease-out（手风琴 300ms） | `cubic-bezier(0.25, 0.46, 0.45, 0.94)` | **`Curves.easeOutQuad`** | Flutter 内置 `easeOutQuad` 恰好就是这个贝塞尔，零误差映射 |
| springy overshoot（复选框 300ms） | `cubic-bezier(0.32, 2.32, 0.61, 0.27)` | **`const Cubic(0.32, 2.32, 0.61, 0.27)`** | Flutter 的 `Cubic` 允许 y 坐标超出 [0,1]，可直接原样定义；近似内置替代为 `Curves.easeOutBack`（`Cubic(0.34,1.56,0.64,1)`，过冲更小更含蓄） |
| `ease-in`（图片淡入 300ms） | `cubic-bezier(0.42, 0, 1, 1)` | **`Curves.easeIn`** | 二者贝塞尔完全相同 |

> 结论：星巴克的曲线家族在 Flutter 中**全部可以无损或近无损表达**，无需引入第三方动画库。

### 2.2 标准实现模板（AnimationController + CurvedAnimation）

星巴克动效落到 Flutter 时统一采用如下模板：

```dart
_controller = AnimationController(vsync: this, duration: MotionDurations.slow);
_animation = Tween<double>(begin: 0.0, end: 1.0).animate(
  CurvedAnimation(parent: _controller, curve: MotionCurves.standard),
);
```

四条规格的具体写法：

```dart
// ① 按钮按压：scale 1.0 → 0.95，fast 档
_scale = Tween<double>(begin: 1.0, end: 0.95).animate(
  CurvedAnimation(parent: _pressController, curve: MotionCurves.standard),
);
// 按下 forward()，松开 reverse()

// ② 手风琴展开：AnimatedContainer 隐式动画即可，不必显式 Controller
AnimatedContainer(
  duration: MotionDurations.slow,        // 300ms
  curve: Curves.easeOutQuad,             // 即星巴克手风琴曲线
  height: expanded ? contentHeight : 0,
)

// ③ 复选框选中：对勾 scale 过冲弹入（显式 Controller 版本）
_checkScale = Tween<double>(begin: 0.6, end: 1.0).animate(
  CurvedAnimation(parent: _checkController, curve: MotionCurves.springPop),
);

// ④ 图片淡入：隐式动画版本
AnimatedOpacity(
  duration: MotionDurations.slow,        // 300ms
  curve: Curves.easeIn,
  opacity: loaded ? 1.0 : 0.0,
)
```

---

## 3. 本 App 现有动画盘点

### 3.1 已有的曲线 / Token 定义（`lib/widgets/animations.dart`）

| 名称 | 定义 | 性格 | 现状用途 |
| --- | --- | --- | --- |
| `standardCurve` | `Cubic(0.29, 0.09, 0.24, 0.99)` | 平滑 ease-out（≈ Material 标准） | 全 App 默认过渡曲线，**事实上的 token** |
| `fataleCurve` | `Cubic(0.0, 1.34, 1.0, 1.81)` | 强过冲弹簧 | 文字入场、登录页、learn_widgets 入场 |
| `splashExitCurve` | `Cubic(0.4, 0.0, 0.5, 0.8)` | 加速离场（ease-in 系） | 启动页退出 |
| `SpringCurve(factor: 0.4)` | `2^(-10t)·sin(...) + 1`，指数衰减正弦 | 弹性震荡（elastic-out） | Tab 图标弹跳 350ms、底栏入场 600ms、滑动单元格复位 195ms |
| `ReverseSpringCurve` | 同上作用于 `1-t` | 反向弹性（elastic-in） | 锁屏模块关闭动效 300ms |
| `ShakeWidget` | TweenSequence：x 0→−6→+6→0 px（权重 1:2:1） | 横向抖动 | 答错反馈（400ms 控制器驱动） |
| `BounceWidget` | TweenSequence：scale 1→1.08→1（权重 40:60） | 放大回弹 | 答对反馈（300ms） |

### 3.2 分模块清单

#### lib/lock/（锁屏模块）

| 文件 | 动效 | 参数 |
| --- | --- | --- |
| `my_element_animator.dart` | 元素逐个入场编排 | 200ms 交错延迟调度 |
| `spring_interpolator.dart` | Android 弹性插值器的 Dart 移植 | `SpringCurve` 的数学来源 |
| `lock_screen_page.dart` | 上滑/下滑跟随 | 1000ms linear ×2、3000ms |
| 同上 | 关闭/收回 | 300ms `ReverseSpringCurve` |
| 同上 | 长按计时 | 500ms Timer（非视觉动画） |
| `view/scroll_top_bottom_layout.dart` | 滚动到顶/底 | `Curves.decelerate` |

#### Shell 与页面转场

| 文件 | 动效 | 参数 |
| --- | --- | --- |
| `shell/main_shell.dart` | 底栏 Tab 图标选中弹跳 | 350ms TweenSequence + `SpringCurve` |
| 同上 | Tab 指示器 | 250ms `standardCurve` |
| `widgets/transition_widgets.dart` | 页面转场 FadeSlideRoute（滑入+淡入组合，Interval 链） | 300ms `standardCurve` |
| 同上 | 启动页退出组件 | 默认 100ms，`splashExitCurve` |
| `widgets/word_dictionary_popup.dart` | 词典弹层 scale 入场 | 200ms `Curves.easeOutBack` |
| `widgets/word_lookup_popup.dart` | 查词弹层淡入 | 200ms `Curves.easeOutCubic` |

#### 学习会话与答题（核心场景）

| 文件 | 动效 | 参数 |
| --- | --- | --- |
| `screens/learn_session.dart` | 学习底栏入场 | 600ms `SpringCurve` 上滑 |
| 同上 | SegmentTabs 文字样式 | 200ms `standardCurve` |
| 同上 | SegmentTabs 下划线 | 250ms `standardCurve` |
| 同上 | 页面指示点 | 200ms AnimatedContainer |
| 同上 | PageView 翻页 | 300ms `standardCurve` |
| `pages/learn_page.dart` | **答错：选项标红** | 200ms AnimatedContainer 变色 |
| 同上 | **答错：抖动** | 400ms `ShakeWidget`（±6px） |
| 同上 | **答对：弹跳** | 300ms `BounceWidget`（1→1.08→1），400ms 后跳转详情页 |
| 同上 | 顶部进度区 | 400ms `standardCurve` |
| `widgets/learn_widgets.dart` | 学习卡翻转（正面↔背面） | 300ms + 300ms 两段 |
| 同上 | 卡片入场 | 300ms `fataleCurve` |
| `pages/review_page.dart` | 复习流程间隔 | 300ms delay |
| `pages/word_machine_page.dart` | 入场 + 抖动机件 | 600ms 入场、300ms `Curves.elasticIn` 抖动、800/1200ms 步骤延迟 |

#### 通用组件库（lib/widgets/）

| 文件 | 动效 | 参数 |
| --- | --- | --- |
| `widget_utils.dart` | `ScaleDownOnPress` 按压缩放（自 Android 移植） | scale 0.95，100ms `standardCurve` |
| `input_controls.dart` | 开关/复选状态 | 250ms `standardCurve`；按压 100ms |
| `layout_widgets.dart` | 滑动删除复位 | 195ms `SpringCurve` |
| 同上 | 展开/折叠 | 300ms `standardCurve` |
| `custom_dialog_widgets.dart` | 弹窗出入场 | 225ms `standardCurve` |
| `custom_text_widgets.dart` | 文字渐入/上移 | 300ms `fataleCurve` |
| `text_widgets.dart` | 打字机文本 | 300ms `standardCurve` |
| `list_widgets.dart` | 列表项按压/删除揭示 | 200ms / 300ms `standardCurve` |
| `guide_widgets.dart` | 引导遮罩 + 高亮脉冲 | 600ms `standardCurve` + `Curves.elasticOut` |
| `badge_label_widgets.dart` | 徽标计数滚动 | 1600ms linear |
| `progress_indicators.dart` | 进度环/条 | 1200ms 循环；200ms 切换 |
| `progress_widgets.dart` | 进度填充 | 1500ms |
| `pager_widgets.dart` | 轮播自动播放 | 800ms `standardCurve` |
| `card_widgets.dart` | 卡片入场 | `SpringCurve` |
| `misc_widgets.dart` / `adapter_widgets.dart` | 环境动效、点击延迟 | 1500ms / 15s / 150ms |

#### 其它页面

| 文件 | 动效 | 参数 |
| --- | --- | --- |
| `pages/splash_page.dart` | 启动页序列 | 1500ms 总长，Interval(0~0.6)，`standardCurve` |
| `pages/login_page.dart` | 登录页入场 | 800ms `standardCurve` + `fataleCurve` |
| `pages/immersive_swipe_page.dart` | 沉浸页滑入/滑出 | 300ms `Curves.easeOut` / 200ms `Curves.easeIn` |
| `pages/wallpaper_select_page.dart` | 壁纸交叉淡化 | 1s |
| `pages/word_detail_page.dart` | 详情页动效 | 1s |
| `pages/class_checkin_page.dart` | 签到循环 | 2s |

### 3.3 盘点结论（问题清单）

1. **时长散乱**：实际使用值有 100/195/200/225/250/300/350/400/600/800ms 十余种，无档位约束。
2. **弹性曲线混用**：`fataleCurve`、`SpringCurve`、`easeOutBack`、`elasticIn/Out` 四种"弹性"并存，性格不统一。
3. **缺少语义命名**：除 `standardCurve` 外，调用处全是裸数值 + 匿名 Cubic，无法全局调优。
4. **答错反馈偏重**：±6px 抖动 × 400ms 相对星巴克"克制"原则偏夸张（详见 §6）。
5. **按压反馈双轨制**：`ScaleDownOnPress`（100ms）与 `input_controls` 内部实现（100ms）重复，参数不一致风险。

---

## 4. 统一动效 Token 建议

### 4.1 时长档位（MotionDurations）

| Token | 值 | 适用场景 | 收编的现状值 |
| --- | --- | --- | --- |
| `fast` | **150ms** | 按压反馈、图标微变、指示器、恢复态 | 100 / 160 / 195ms |
| `base` | **200ms** | 常规状态过渡：颜色、透明度、选项标红、Tab 切换 | 200 / 225ms |
| `slow` | **300ms** | 展开/收起、卡片翻转、弹层出入场、页面转场 | 250 / 300 / 350ms |
| `expressive`（特例档） | 400–600ms | 仅限**整屏级入场**与庆祝时刻（底栏首次入场、学习完成） | 400 / 600ms |

规则：
- 用户主动触发的反馈一律落在 `fast/base/slow` 三档内；`expressive` 只允许用于非交互的仪式性时刻。
- >800ms 仅限环境/循环类（进度环、壁纸淡入），不得用于交互反馈。

### 4.2 曲线档位（MotionCurves）

| Token | 定义 | 性格 | 用途 |
| --- | --- | --- | --- |
| `standard` | 沿用现有 `Cubic(0.29, 0.09, 0.24, 0.99)` | 平滑 ease-out | 一切默认状态过渡（与星巴克 measured ease-out 同族） |
| `accordion` | `Curves.easeOutQuad`（= 星巴克手风琴曲线） | 快进慢出 | 展开/收起、高度/位置变化 |
| `springPop` | `Cubic(0.32, 2.32, 0.61, 0.27)`（星巴克复选框曲线） | 一次性微弹过冲 | 选中、确认、对勾、徽标出现 |
| `exit` | 沿用现有 `splashExitCurve`（≈ `Curves.easeIn` 族） | 加速离场 | 退出、消失、dismiss |
| `elastic` | 现有 `SpringCurve()` | 弹性震荡 | **仅限**整块元素入场/Tab 弹跳等仪式性时刻，日常禁用 |

收敛策略：
- `fataleCurve`（过冲过强）逐步由 `springPop` 替代；存量引用允许暂存。
- 弹窗/弹层统一 `base + standard` 进入、`fast + exit` 退出，替换现散落的 `easeOutBack` / `easeOutCubic`。

### 4.3 Token 文件草案（建议新增 `lib/theme/motion_tokens.dart`）

```dart
/// 全局动效 Token —— 对齐星巴克动效语言（见 docs/motion_spec.md）
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
  static const accordion = Cubic(0.25, 0.46, 0.45, 0.94); // == Curves.easeOutQuad
  /// 星巴克复选框弹性曲线 cubic-bezier(0.32,2.32,0.61,0.27)
  static const springPop = Cubic(0.32, 2.32, 0.61, 0.27);
  /// 退出/离场（现有 splashExitCurve）
  static const exit = Cubic(0.4, 0.0, 0.5, 0.8);
}

/// 按压反馈标准量
class MotionPress {
  static const scale = 0.95; // 星巴克 --buttonActiveScale
}
```

### 4.4 按压反馈标准实现

全 App 统一使用 `ScaleDownOnPress`（`lib/widgets/widget_utils.dart`，已翻译自 Android `ScaleDownOnPressOnTouchListener`）作为唯一按压封装：

```dart
ScaleDownOnPress(
  scale: MotionPress.scale,                 // 0.95
  duration: MotionDurations.fast,           // 150ms（现状 100ms → 收敛为 fast 档）
  onTap: () { ... },
  child: child,
)
```

要点：
- 按 `onTapDown` 缩小、`onTapUp/onTapCancel` 恢复，回调在恢复完成后触发（保持现有行为，避免误触）。
- 曲线用 `standardCurve` 双向即可——星巴克原规格 `ease` 双向同曲线，按压不需要过冲。
- 禁止再新写第三套按压实现；`input_controls` 内部的 100ms 实现合并进来。

---

## 5. 学习卡翻转 / 页面转场的规范化对照

| 场景 | 现状 | 规范化后 |
| --- | --- | --- |
| 学习卡翻转 | 300ms × 2 段（未注明曲线） | `slow` + `accordion`（easeOutQuad），翻出段可用 `exit` |
| 页面转场 FadeSlideRoute | 300ms `standardCurve` | 保持，改引 `slow + standard` |
| 弹层（词典/查词） | 200ms 各自曲线 | 进入 `base + standard`，退出 `fast + exit` |
| 底栏入场 | 600ms `SpringCurve` | 归入 `expressive` 档，保留 `SpringCurve`（仪式性时刻白名单） |
| Tab 弹跳 | 350ms `SpringCurve` | 收敛为 300ms `SpringCurve`（或 `springPop` 更克制版） |

---

## 6. 重点方案：4 选项答题「选错标红 / 重选」动效

### 6.1 设计立场（星巴克"克制"原则的不对称应用）

- **错误要平静，成功才允许弹性。** 错误反馈的目标是"被注意到但不制造焦虑"，只用状态变化（颜色、亮度）+ 一次极短的方位提示；弹性过冲（`springPop`/`BounceWidget`）只保留给正确确认。
- **不阻断操作流。** 选错后必须立即可重选，不允许任何模态打断或长动画锁定输入。
- **一次性原则。** 抖动只发生一次，不循环、不红闪。

### 6.2 分步规格

| 步骤 | 动效 | 规格 |
| --- | --- | --- |
| ① 标红 | 选项容器颜色/描边过渡 | `base`(200ms) + `standard`，仅变色不动布局（现状已符合 ✓） |
| ② 微抖 | 水平小幅抖动一次 | 由现状 ±6px/400ms 收敛为 **±3px / 300ms(`slow`) / 单周期**，`TweenSequence` 权重保持 1:2:1 |
| ③ 降权 | 错误项整体变暗 | opacity 1→0.55，`base`(200ms)；文字保留可读，仍可点击 |
| ④ 重选恢复 | 点击其它选项时旧错误项还原 | `fast`(150ms) reverse 回正常色/透明度，与新选项判定并行进行 |
| ⑤ 正确确认 | 对勾弹入 + 边框转绿 | 对勾 scale 0.6→1.0，`base`(200ms) + **`springPop`**（星巴克复选框曲线，语义同为"勾选确认"）；整卡 `BounceWidget` 幅度由 1.08 降为 **1.04** |
| ⑥ 后续跳转 | 答对后进入详情 | 维持 400ms 延迟不变（等待确认动画收尾） |

### 6.3 参考实现骨架

```dart
// 答错
setState(() => _wrongIndex = i);
_wrongController.forward(from: 0); // slow=300ms 驱动 ShrinkShake(±3px)

// 选项容器（保持可重选）
AnimatedContainer(
  duration: MotionDurations.base,
  curve: MotionCurves.standard,
  decoration: BoxDecoration(
    color: isWrong ? errorBg : normalBg,      // 仅颜色参与动画
    border: Border.all(color: isWrong ? errorBorder : transparent),
  ),
  child: Opacity(opacity: isWrong ? 0.55 : 1.0, ...) // 或并入 Container
)

// 答对：对勾以星巴克复选曲线弹入
_checkScale = Tween(begin: 0.6, end: 1.0).animate(
  CurvedAnimation(parent: _checkController, curve: MotionCurves.springPop),
);
Future.delayed(const Duration(milliseconds: 400), pushWordDetail);
```

### 6.4 明确禁止

- ❌ 整页/整卡大幅晃动（现 ±6px×400ms 属于上限，应下调）
- ❌ 红色呼吸/闪烁循环
- ❌ 禁用其余选项并播放重力下坠类动画
- ❌ 错误项使用任何过冲曲线（`springPop`/`fataleCurve`/`SpringCurve`）

---

## 7. 迁移落地建议（后续重构任务执行，本次不动代码）

1. **第一步**：新建 `lib/theme/motion_tokens.dart`（§4.3），`animations.dart` 中的常量改为转发引用，保证旧调用不断。
2. **第二步**：按压组件合并 —— `input_controls` 的内部实现并入 `ScaleDownOnPress`，参数统一为 `fast + scale 0.95`。
3. **第三步**：答题反馈按 §6 改造（改动面小、收益最直观）。
4. **第四步**：批量时长归档（机械替换 100→fast、225/250→base/slow 等），逐文件提交便于回滚。
5. **第五步**：`fataleCurve` 存量点逐一评估替换为 `springPop`；`elastic` 白名单之外的场景移除弹性。
6. 全程遵守：新代码禁止出现裸 `Duration(milliseconds: xxx)` 与匿名 `Cubic(...)`，一律引用 Token。
