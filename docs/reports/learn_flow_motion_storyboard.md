# 学习核心流程动效分镜（Learn Flow Motion Storyboard）

> 任务：【重构32】答题动效分镜 —— 学习核心流程逐帧蓝图
> 依据：`docs/motion_spec.md`（五档曲线/时长 Token）、`docs/component_spec.md` §3（FrapFab）、`docs/touch_target_audit.md`（P0 间距）、`lib/pages/learn_page.dart` 等（只读分析）
> 流程覆盖：**FrapFab 开始学习 → 出题入场 → 四选项作答 → 选错反馈/重选 → 选对确认 → 字典详情 → 返回下一题**

---

## 0. 现状基线与缺口（读码结论）

| 环节 | 现状（代码事实） | 缺口 |
| --- | --- | --- |
| 进出学习页 | `/learn` 走 `FadeRoute`（main.dart:216-218） | ✅ 有基础 |
| 进度条推进 | `TweenAnimationBuilder` 400ms `standardCurve`（learn_page:130-146） | ✅ 可直接沿用 |
| 选项外观 | 高 56px、间距 8、圆角 14，`AnimatedContainer` 200ms 只变色 | ⚠️ 间距待扩为 16（触控审计建议） |
| 选项入场 | 无任何入场动画，切词时 `didUpdateWidget` 仅重置状态（learn_page:264-271） | ❌ 缺 stagger |
| 选错反馈 | 标红 200ms + `ShakeWidget` ±6px/400ms（learn_page:245-247,285-286,356-358） | ⚠️ 按 motion_spec §6 需收敛为 ±3px/300ms |
| 重选提示文案 | `'请选择正确释义' ↔ '请再选出正确答案'` 瞬间切换（learn_page:301） | ❌ 缺过渡 |
| **选对确认** | `_bounceController.forward()` 但 **UI 未挂接任何组件**（learn_page:278）——控制器悬空，绿色确认态不存在 | ❌ **最关键缺口**：用户点对后 400ms 内画面毫无变化就跳页 |
| 进入详情页 | `Navigator.pushNamed('/word_detail')` → 默认 `MaterialPageRoute` 水平滑动（main.dart:226） | ⚠️ 与学习页 FadeRoute 家族不连贯 |

---

## 1. 引用约定：五档曲线 / 时长速查

本分镜全部引用 motion_spec Token，不再出现裸数值曲线：

| Token | 定义 | 本分镜用途 |
| --- | --- | --- |
| 时长 `fast/base/slow/expressive` | 150/200/300/450ms | 按压/常规过渡/展开确认/仪式性入场 |
| 曲线 `MotionCurves.standard` | Cubic(.29,.09,.24,.99) | 默认状态过渡、颜色、透明度 |
| 曲线 `MotionCurves.accordion` | Cubic(.25,.46,.45,.94)（星巴克手风琴） | 入场滑入、路由飞行、高度展开 |
| 曲线 `MotionCurves.springPop` | Cubic(.32,2.32,.61,.27)（星巴克复选框） | 对勾弹入等一次性确认微弹 |
| 曲线 `MotionCurves.exit` | Cubic(.4,0,.5,.8) | 退场/消失 |
| 曲线 `MotionCurves.elastic` | SpringCurve() | 仅限仪式性时刻（本分镜不使用） |
| 按压 `MotionPress.scale` | 0.95 + fast | 所有点按目标 |

---

## 2. 分镜 S1：出题入场（题干 + 四选项 stagger）

### 逐帧表

| 帧 | 时间轴(ms) | 动效 | 曲线/时长 | 涉及 Widget | 实现 |
| --- | --- | --- | --- | --- | --- |
| F0 | 0 | 页面 FadeRoute 淡入完成（已有） | — | LearnPage | 沿用 main.dart FadeRoute |
| F1 | 0–300 | 单词 + 音标自下方 12px 上滑淡入 | `accordion` / `slow` | `_WordArea` 内 Column | 显式 Controller A（见下）Interval(0, 1) |
| F2 | 120–420 | 提示文案「请选择正确释义」淡入 | `standard` / `slow` | _QuizArea 首行 Text | 同 Controller A Interval(0.4, 1)，纯 Opacity 无位移 |
| F3 | 180–480 | 选项① 淡入 + 上滑 16px→0 | `accordion` / `slow` | choice tile | Interval(0.6, 1) |
| F4 | 240–540 | 选项② 同上 | 同上 | 同上 | Interval(0.8, 1) |
| F5 | 300–600 | 选项③ 同上 | 同上 | 同上 | Interval(1.0, 1) |
| F6 | 360–660 | 选项④ 同上 | 同上 | 同上 | Interval(1.2, 1)* |
| F7 | 0–400 | 进度条从上一位置推进 | `standard` / 400ms | _TopBar LinearProgressIndicator | **沿用现有** TweenAnimationBuilder，不动 |

\* Interval 超 1.0 由 `CurvedAnimation` 自动钳制，无需特判；等价写法是每个 Interval 上限取 min(1, x+1)。

### stagger 参数

- **步长 60ms、首项延迟 180ms**（题干先行 180ms，建立"题目在上、选项在下"的阅读顺序）。
- 总时长 660ms，处于 `expressive`(450ms) 档之上但属**整屏级仪式性入场**，符合 motion_spec §4.1 特例档定义；每秒最多发生一次（切词频率低），无疲劳风险。

### 实现要点

```dart
// 单 master Controller + Interval 链，省 vsync、天然同步
_master = AnimationController(vsync: this, duration: MotionDurations.expressive);
_wordAnim    = CurvedAnimation(parent: _master, curve: const Interval(0, 1,     curve: MotionCurves.accordion));
_promptAnim  = CurvedAnimation(parent: _master, curve: const Interval(0.4, 1,   curve: MotionCurves.standard));
_option(i)   => CurvedAnimation(parent: _master,
                  curve: Interval(0.6 + 0.2 * i, 1, curve: MotionCurves.accordion));
```

- 用显式 Controller 而非隐式动画：stagger 需要 delay 编排，`AnimatedFoo` 无延迟参数；每个选项独立 `TweenAnimationBuilder` 会因 rebuild 时机不可控而失去错峰。
- **下一题快速版（防疲劳）**：`didUpdateWidget` 检测换词后重播时降级——题干 crossfade `fast`（无位移），四个选项整体 `base` 淡入（不做逐项 stagger，不重新上滑）。首次进页才播放完整版。判断依据：`firstBuild` 标志位。
- 选项 tile 结构不变（`GestureDetector > AnimatedContainer`），外层套 `FadeTransition + SlideTransition`（由 `option(i)` 驱动），与 S2 的按压缩放互不干扰（不同变换通道）。

---

## 3. 分镜 S2：选错路径（含触控审计 P0 配合）

### 逐帧表

| 帧 | 时间轴(ms) | 动效 | 曲线/时长 | 涉及 Widget | 实现 |
| --- | --- | --- | --- | --- | --- |
| F0 | 指下即始 | 按压缩放 1→0.95 | `standard` / `fast` | ScaleDownOnPress（pressable_inventory §5 升级版）包裹 tile | onTapDown forward |
| F1 | 抬指 | 缩放回弹 0.95→1 | `standard` / `fast` | 同上 | reverse；回调仍为"恢复后触发" |
| F2 | 判错帧 T2 起 0–200 | 背景→errorBg(α.6)、描边→红 #E8A0A0 | `standard` / `base` | AnimatedContainer（现有，learn_page:333） | setState(_wrongIndex=i) 驱动，**不动布局只变色** |
| F3 | T2 起 0–300 | 微抖 ±3px 单周期（权重 1:2:1） | TweenSequence / `slow` 总长 | ShakeWidget（收敛后版本） | 替换现 ±6px/400ms；控制器 duration 改 `MotionDurations.slow` |
| F4 | T2+100 起 200 | 变暗 opacity 1→0.55 | `standard` / `base` | tile 外层 AnimatedOpacity | 比 F3 晚 100ms 启动，错峰避免"又抖又暗"同帧抢眼 |
| F5 | T2+0 | 文案切换「请选择…」→「请再选出正确答案」 | `standard` / `fast` | AnimatedSwitcher 包提示 Text | 修复现状瞬切；crossFade 即可 |
| F6 | 重选其它项瞬间 0–150 | 旧错误项恢复：颜色/透明度 reverse | `standard` / `fast` | AnimatedContainer + AnimatedOpacity | setState 清 _wrongIndex，隐式动画自动反向 |
| F7 | 新判定 | 正确→转 S3；再次选错→另一 tile 重演 F2-F4（旧项执行 F6） | — | — | 现有 `_onChoice` 逻辑兼容 |

### 关键时序决策

- **解除时机：判错帧 T2 即解锁输入，不等抖动结束。** 抖动只是"告知"，不是"锁定"；用户在 300ms 抖动期间点其它选项必须立即生效（F6 的 reverse 与新一轮 F2 并行，互不阻塞）。现状代码本就不锁 UI（`_onChoice` 无 guard），分镜将其固化为规格并写入验收。
- F3/F4 结束后错误项停在「红底 0.55 暗」静止态，等待用户重选——**不加呼吸、不加闪烁**（克制原则）。

### 与触控审计 P0 的配合标注 ⚠️

1. **四选项间距 8 → 16dp**（touch_target_audit 对四选一的整改建议）：按压缩放到 0.95 时，56px 高 tile 视觉边缘各内收约 1.4px，若间距过窄，相邻项的视觉边界会在按压时互相侵入；16dp 间距保证任意一项按压中，与邻项仍有 ≥13dp 净空。
2. **命中区随缩放内收**：`ScaleDownOnPress` 的 Transform 会连带缩小命中区（这正是 Frap 式"视觉外扩、命中内收"策略的落地形态）；tile 为全宽行元素，配合 `behavior: HitTestBehavior.opaque` 保证整行可点。
3. **SRS 三键间距 P0（review_session 认识/模糊/忘记，补 SizedBox(width:12)）**：本四选一流程当前不含 SRS 三键；若未来在学习页追加快速评分键组，**必须先落实 12px 实体间距，再叠加任何按压缩放**——缩放会进一步侵蚀键间净空，顺序颠倒会把 P0 风险放大。
4. 抖动幅度 ±3px 不会使相邻 16dp 间距内的两项发生视觉重叠（3 < 16−56×0.05≈13.2 的安全余量成立）。

---

## 4. 分镜 S3：选对路径（重点修复区）

> 现状缺口：`_bounceController.forward()` 后无任何 UI 挂接，点对后画面静止 400ms 直接跳页。本分镜将该控制器接入真实反馈链。

### 逐帧表

| 帧 | 时间轴(ms) | 动效 | 曲线/时长 | 涉及 Widget | 实现 |
| --- | --- | --- | --- | --- | --- |
| F0 | 指下/抬指 | 按压缩放往返 | `standard` / `fast` | ScaleDownOnPress | 同 S2 F0-F1 |
| F1 | T1 起 0–200 | 该 tile 背景→成功绿、描边→绿 | `standard` / `base` | AnimatedContainer | 新增 `isCorrect` 三态分支（现在只有 red/normal 两态） |
| F2 | T1 起 0–200 | 对勾图标 scale 0.6→1.0 弹入 + 淡入 | `springPop` / `base` | tile 尾部 AnimatedScale + AnimatedOpacity | 复用星巴克复选框曲线，语义同为"勾选确认" |
| F3 | T1 起 0–300 | 整卡微弹 1→1.04→1 | TweenSequence / `slow` | BounceWidget（幅度收敛版） | **修复**：将现有 `_bounceController` 真正接到 tile 外层 BounceWidget；幅度 1.08→1.04 |
| F4 | T1+150 起 200 | 其余三个选项降权 opacity→0.40 | `standard` / `base` | 各 tile 外层 AnimatedOpacity | 聚焦正确项；只降亮度不做位移（克制） |
| F5 | T1+200 | 进度条预推一格 | `standard` / 400ms | _TopBar（现有） | 维持现有 TweenAnimationBuilder，不改 |
| F6 | T1+400（保持现有时序） | 路由转场进入字典详情页 | 见下节 | Navigator.pushNamed('/word_detail') | 维持 400ms 等待（F1-F3 已填满这段空白，现状"死等"消失） |

### 详情页转场曲线（两案对比）

| 方案 | 表达 | 优点 | 代价 | 结论 |
| --- | --- | --- | --- | --- |
| **A. Hero 容器转换**（推荐） | 单词文本 `Hero(tag:'word-${word}')` 从答题卡上方飞至详情页标题位；路由 `transitionDuration: slow`, 曲线 `accordion`；底层页面淡入 | 与"查这个词"的心智完全一致；Flutter 内建 Hero，零依赖；与 FadeRoute 家族兼容 | 需在 learn_page `_WordArea` 与 word_detail 标题各包 Hero，并给该路由定制 PageRoute | **采用** |
| B. 统一 FadeRoute | 详情页整体淡入 + 上滑 24px，`exit` 曲线反向退出 | 改动最小 | 失去"词条延续"叙事；与搜索页等普通页无差异 | 备选（P2 兜底） |

实现要点（A 案）：新建 `_WordDetailHeroRoute extends PageRouteBuilder`，`transitionDuration: MotionDurations.slow`，`CurvedAnimation(curve: MotionCurves.accordion)`；返回时自动反向（Hero 飞回），退出段曲线用同 route 的 `reverseTransitionDuration: base`。

### 实现要点汇总

- 对勾：`Stack(alignment: centerRight)` 内 `AnimatedScale(scale: ok?1:0.6, curve: MotionCurves.springPop)` + `AnimatedOpacity`，图标用 `Icons.check_circle_outline`。
- `_bounceController.duration` 300ms 不变；`didUpdateWidget` 换词重置逻辑保留（现有 learn_page:266-270 已正确处理）。
- F4 降权与 S2 的错误变暗共用同一个 AnimatedOpacity 通道，注意状态机优先级：`correctIndex` 命中后忽略新的错误判定（答对即终局）。

---

## 5. 分镜 S4：FrapFab「开始学习」→ 进入学习页

> FrapFab 规格来源：component_spec §3——56px 圆形 #00754A 白 icon、双阴影（基础光环 + 环境投影）、触控外扩 8px、右下角常驻、按压 scale(0.95)。本分镜补齐其**动效行为定义**与进页衔接。

### 逐帧表

| 帧 | 时间轴(ms) | 动效 | 曲线/时长 | 涉及 Widget | 实现 |
| --- | --- | --- | --- | --- | --- |
| F0 | 指下 0–150 | scale 1→0.95 | `standard` / `fast` | FrapFab 内核 Container | ScaleDownOnPress 同款参数 |
| F1 | 指下同步 0–200 | **环境投影淡出**（blur 12→6、opacity .14→0），基础光环保留 | `standard` / `base` | BoxShadow 参数化 | 星巴克原规格"按压时环境投影淡出"——贴桌感→拿起感 |
| F2 | 抬指 0–150 | scale 回弹 + 投影回弹 | `standard` / `fast` | 同上 | reverse；随后触发回调 |
| F3 | 回调帧 | pushNamed('/learn')，页面 FadeRoute 淡入（已有）+ **Fab 图标 Hero 飞行** | `accordion` / `slow` | Hero(tag:'fab-play') ×2 | 见下 |
| F4 | 飞行落点 | 图标融入学习页顶部发音钮位（同为白色圆形声纹语义）后隐去 | — | _WordArea 发音钮 | Hero flightShuttleBuilder 控制 size 过渡 30→28 |
| F5 | 返回学习首页 | 反向：页面 `exit` 淡出 + Fab 阴影回弹归位 | `exit` / `base` + `standard` / `base` | 同上 | route reverseTransitionDuration |

### hero/容器转换建议（两案对比）

| 方案 | 表达 | 结论 |
| --- | --- | --- |
| **A. 单点 Hero**（推荐） | 仅 Fab 图标参与 Hero 飞行（tag `fab-play`），页面本体维持现有 FadeRoute | 零新依赖、改动 2 个文件、风险最低；"按钮起飞"的仪式感足够 |
| B. 完整 Container Transform（animations 包 open_container） | 圆钮扩散揭示整页 | 需引入官方 animations 依赖；全屏揭示与壁纸背景的连续性差（学习页另有自己的壁纸层）；与 App 自研转场体系（transition_widgets）并存两套范式 | **不采用**，列为远期备选 |

实现要点：

```dart
// FrapFab 内部（component_spec §3 代码的动效升级点）
AnimatedScale(                                  // F0/F2
  scale: _pressing ? MotionPress.scale : 1.0,
  duration: MotionDurations.fast, curve: MotionCurves.standard,
  child: Hero(
    tag: 'fab-play',
    child: AnimatedContainer(                   // F1：双阴影参数化
      duration: MotionDurations.base, curve: MotionCurves.standard,
      boxShadow: _pressing ? [_glowOnly] : [_glowAmbient],
      ...
```

- 阴影不能走 `AnimatedContainer.decoration` 的隐式插值歧义：BoxShadow 列表长度变化不会插值，**两组阴影必须等长**（按压态= [光环(弱), 环境(opacity 0)]，常态=[光环, 环境]），靠数值插值实现淡出。
- Hero 两端 child 必须同型（同 Icon、同色），否则飞行跳变。

---

## 6. 全流程时序总览

```
[首页] FrapFab 按下(F0-F2: 0-200ms) ──抬指──► pushNamed(/learn)
                                                        │
[学习页] ◄────────────── FadeRoute 淡入 + Fab 图标 Hero 飞行(slow300 accordion)
   │
   ├─ S1 首次入场: 题干(0-300) → 文案(120-420) → 选项①..④ stagger 60ms (180-660)
   │
   ├─ 用户作答
   │    ├─ 选错 S2: 按压(fast150) ─► 标红(base200) ∥ 微抖±3px(slow300) ─► 变暗0.55(+100ms, base200)
   │    │            文案切换(fast150) · T2 即解锁重选 · 重选恢复(fast150) ──┐
   │    │                                                                  ▼ 循环回"用户作答"
   │    └─ 选对 S3: 按压 ─► 变绿+对勾 springPop(base200) ∥ 卡片微弹1.04(slow300)
   │                 ─► 其余项降权0.40(T+150) ─► T+400 Hero 转场 ─► [字典详情页]
   │                                                                    │ 返回
   ├─ 下一题: didUpdateWidget ─► S1 快速版(题干 crossfade fast150 + 选项整体淡入 base200)
   └─ 返回首页: exit 淡出 + Fab 阴影回弹
```

---

## 7. 控制器清单与工程注意

| 控制器 | 归属 | duration | 驱动内容 | 状态 |
| --- | --- | --- | --- | --- |
| `_master`（新增） | _QuizArea/_WordArea 共享 vsync | expressive | S1 stagger 五路 Interval | 新增，initState 播完整版 / didUpdateWidget 播快速版 |
| `_shakeController` | _QuizArea | 400ms → **slow(300)** | S2 微抖 | 改造（幅度 ±6→±3px 在 ShakeWidget 参数化） |
| `_bounceController` | _QuizArea | 300ms | S3 卡片微弹 | **修复悬空**：接入 BounceWidget |
| 进度条 TweenAnimationBuilder | _TopBar | 400ms | F5/S3 F5 | 沿用不动 |
| FrapFab 内部双通道 | FrapFab | fast/base | scale + 阴影 | 新增于 component_spec §3 实现之上 |

注意事项：

1. `_QuizArea` 已是 `TickerProviderStateMixin`，新增 `_master` 无需额外 ticker。
2. 所有新增隐式动画（AnimatedOpacity/AnimatedScale/AnimatedSwitcher）复用 motion_spec Token 常量，禁止裸 Duration/Cubic。
3. 状态机优先级：`answeredCorrectly > wrongIndex > idle`；答对后屏蔽后续 tap（现状 `_onChoice` 未挡重复点击，S3 落地时补 guard，防止 400ms 窗口内连点触发多次 pushNamed）。
4. 验收基准：S2 全程 ≤500ms、S3 到转场 ≤700ms、S1 首次 ≤660ms / 快速版 ≤350ms；全程无循环动画、无闪烁。
