# 动效规范验证报告

> 任务：【重构102】动效验证 — 确认所有动效规范在页面改造后正确应用
> 依据：`docs/motion_spec.md`、`docs/learn_flow_motion_storyboard.md`、`docs/answer_feedback_patch_blueprint.md`
> 验证日期：2026-08-24
> 约束：只读代码，仅产出本报告

---

## 一、验证总览

| 验证维度 | 结果 | 详情 |
|---|---|---|
| 答题反馈动效（learn_page） | ✅ 全部正确 | 7 项补丁完整保留，无覆盖 |
| ScaleDownOnPress 按压组件 | ⚠️ 两套并存 | 新版规范，旧版仍在 widget_utils.dart |
| 页面转场动画 | ✅ 正确 | 300ms standardCurve，符合规范 |
| motion_tokens.dart Token 文件 | ❌ 未创建 | motion_spec §4.3 建议的 Token 文件未落地 |
| 时长散乱问题 | ⚠️ 部分收敛 | learn_page 已归档，其余页面仍有裸值 |
| fataleCurve 收敛 | ⚠️ 未完成 | motion_spec 建议替换为 springPop，2 处仍在用 |

---

## 二、答题反馈动效验证（learn_page.dart）

### 2.1 控制器状态

| 控制器 | duration | 用途 | 状态 |
|---|---|---|---|
| `_shakeController` | 300ms（slow 档） | 选错微抖 | ✅ 正确 |
| `_bounceController` | 300ms | 答对弹跳 | ✅ 正确 |
| `_checkController` | 200ms（base 档） | 对勾 springPop | ✅ 正确 |

### 2.2 七项补丁验证

| 补丁 | 描述 | 状态 | 验证方式 |
|---|---|---|---|
| P1 | 悬空 _bounceController 修复 + 绿色确认态 | ✅ | `buildBounceAnim` 已接入 `ScaleTransition` |
| P2 | 对勾 springPop 弹入 | ✅ | `Cubic(0.32, 2.32, 0.61, 0.27)` + `ScaleTransition` |
| P3 | 抖动收敛 ±3px/300ms 单周期 | ✅ | `computeShakeOffset(t, amplitude: 3.0, cycles: 1)` + `AnimatedBuilder` |
| P4 | 防重复点击 guard | ✅ | `if (_correctIndex >= 0) return;` 在 `_onChoice` 入口 |
| P5 | 四选项间距 16dp | ✅ | `margin: EdgeInsets.only(bottom: 16)` |
| P6 | SRS 三键 12dp 间距 | ✅ | `SizedBox(width: 12)` 在 review_session.dart |
| P7 | 其余选项降权 0.40 | ✅ | `AnimatedOpacity(opacity: 0.40)` |

### 2.3 答题颜色 token 化验证

| 颜色项 | 旧值 | 新值 | 状态 |
|---|---|---|---|
| 答对背景 | `Color(0xFF4CAF50).withOpacity(0.35)` | `colors.quizCorrectBg` | ✅ |
| 答对边框 | `Color(0xFF4CAF50)` | `colors.quizCorrectText` | ✅ |
| 答对文字 | `Color(0xFF2E7D32)` | `colors.quizCorrectText` | ✅ |
| 答错背景 | `Color(0xFFE8A0A0).withOpacity(0.6)` | `colors.quizWrongBg` | ✅ |
| 答错边框 | `Color(0xFFE8A0A0)` | `colors.quizWrongText` | ✅ |
| 默认背景 | `Colors.white.withOpacity(0.25)` | `colors.cardBg` | ✅ |
| 默认文字 | `Colors.white` | `colors.text1` | ✅ |

### 2.4 壁纸→奶油画布验证

| 项目 | 状态 |
|---|---|
| 壁纸背景移除 | ✅ 已移除 `_buildWallpaperBg` 和 wallpaper imports |
| 半透明遮罩移除 | ✅ 已移除 `Colors.black.withOpacity(0.15)` |
| Scaffold backgroundColor | ✅ `skin.colors.pageBg`（#F2F0EB） |

---

## 三、ScaleDownOnPress 验证

### 3.1 两套实现并存问题

| 文件 | 默认 scale | 默认 duration | 默认 curve | 状态 |
|---|---|---|---|---|
| `lib/widgets/scale_down_on_press.dart`（新版） | 0.95 | **200ms** | Curves.easeOut | ✅ 符合规范 |
| `lib/widgets/widget_utils.dart`（旧版） | 0.95 | **100ms** | standardCurve | ❌ duration 不符 |

**问题**：旧版 `widget_utils.dart` 的 `ScaleDownOnPress` 默认 duration=100ms，不符合 motion_spec 要求的 200ms（base 档）。新版 `scale_down_on_press.dart` 已修正。

**建议**：统一迁移到 `scale_down_on_press.dart`，废弃 `widget_utils.dart` 中的旧版。

### 3.2 使用分布

**使用新版 `scale_down_on_press.dart` 的组件**（规范✅）：
- `sb_button.dart` — PillButton
- `sb_card.dart` — ContentCard
- `sb_fab.dart` — FrapFab
- `sb_banner.dart` — StreakBanner
- `sb_badge.dart` — GoldPillBadge

**使用旧版 `widget_utils.dart` 的组件**（需迁移）：
- `home_screen.dart`（2 处）
- `check_in_widgets.dart`（2 处）
- `search_page.dart`（4 处）

---

## 四、页面转场动画验证

| 转场类型 | 文件 | duration | curve | 状态 |
|---|---|---|---|---|
| FadeSlideRoute | transition_widgets.dart | 300ms | standardCurve | ✅ 符合 slow 档 |
| FadeRoute | transition_widgets.dart | 300ms | standardCurve | ✅ |
| ScaleRoute | transition_widgets.dart | 300ms | standardCurve | ✅ |
| Splash exit | transition_widgets.dart | 100ms | splashExitCurve | ✅ 特例档 |

**结论**：页面转场统一使用 300ms + standardCurve，符合 motion_spec 规范。

---

## 五、时长档位收敛验证

### 5.1 learn_page.dart（已归档 ✅）

| 用途 | 旧值 | 新值 | 状态 |
|---|---|---|---|
| 抖动控制器 | 400ms | 300ms（slow） | ✅ |
| 弹跳控制器 | 300ms | 300ms（slow） | ✅ |
| 对勾控制器 | — | 200ms（base） | ✅ |
| 选项变色 | 200ms | 200ms（base） | ✅ |
| 进度条 | 400ms | 400ms（expressive 特例） | ✅ |

### 5.2 其余页面（未收敛 ⚠️）

| 文件 | 裸值示例 | motion_spec 建议 |
|---|---|---|
| learn_session.dart | 600ms（底栏入场） | 归入 expressive 档，保留 |
| learn_session.dart | 250ms（下划线） | 收敛为 base(200) 或 slow(300) |
| main_shell.dart | 300ms（Tab 指示器） | ✅ 符合 slow 档 |
| custom_dialog_widgets.dart | 225ms | 收敛为 base(200) |
| badge_label_widgets.dart | 1600ms（计数滚动） | 环境类，保留 |

**结论**：learn_page 已完成时长归档；其余页面存在散乱值，建议后续批量替换。

---

## 六、曲线使用验证

### 6.1 规范曲线使用分布

| 曲线 | 定义 | 使用处 | 状态 |
|---|---|---|---|
| `standardCurve` | Cubic(0.29, 0.09, 0.24, 0.99) | 主壳、学习会话、登录、指示器、进度等 15+ 处 | ✅ 统一 |
| `SpringCurve` | 指数衰减正弦 | Tab 弹跳、底栏入场、卡片入场 | ✅ 仪式性时刻白名单 |
| `fataleCurve` | Cubic(0.0, 1.34, 1.0, 1.81) | login_page、learn_widgets、custom_text | ⚠️ motion_spec 建议逐步替换为 springPop |
| `splashExitCurve` | Cubic(0.4, 0.0, 0.5, 0.8) | splash exit、transition_widgets | ✅ exit 家族 |

### 6.2 新增规范曲线（未创建 ❌）

motion_spec §4.2 定义了以下新曲线，但 `animations.dart` 中未添加命名常量：

| 曲线 | 定义 | 状态 |
|---|---|---|
| `MotionCurves.accordion` | Cubic(0.25, 0.46, 0.45, 0.94) | ❌ 未创建 |
| `MotionCurves.springPop` | Cubic(0.32, 2.32, 0.61, 0.27) | ❌ 未创建（learn_page 使用内联值） |
| `MotionCurves.exit` | Cubic(0.4, 0.0, 0.5, 0.8) | ❌ 未创建（等于现有 splashExitCurve） |

**影响**：learn_page 中 `springPop` 使用内联 `Cubic(0.32, 2.32, 0.61, 0.27)`，可工作但不利于全局调优。

---

## 七、问题清单与修复建议

### P0（应立即修复）

无。所有动效功能正常，无崩溃或回归风险。

### P1（建议尽快修复）

| # | 问题 | 文件 | 建议 |
|---|---|---|---|
| 1 | motion_tokens.dart 未创建 | — | 新建 `lib/theme/motion_tokens.dart`，按 motion_spec §4.3 定义 MotionDurations/MotionCurves/MotionPress |
| 2 | 旧版 ScaleDownOnPress 并存 | widget_utils.dart | 迁移 3 个文件的 import 到 `scale_down_on_press.dart`，废弃旧版 |
| 3 | springPop 内联值 | learn_page.dart:388 | 创建命名常量后替换 |

### P2（后续批次）

| # | 问题 | 文件 | 建议 |
|---|---|---|---|
| 4 | fataleCurve 存量 | login_page, learn_widgets | 评估替换为 springPop（motion_spec §4.2 收敛策略） |
| 5 | 时长散乱 | learn_session, custom_dialog_widgets 等 | 批量替换裸值为 MotionDurations 引用 |
| 6 | buildShakeAnim 旧签名 | animations.dart | 已参数化，旧调用兼容，无紧迫问题 |

---

## 八、结论

**动效规范应用状态：核心路径完整，边缘待收敛。**

- ✅ **答题核心流程**（learn_page）：7 项补丁全部保留，颜色 token 化完成，壁纸→奶油画布落地，无任何动效被覆盖或移除
- ✅ **页面转场**：统一 300ms + standardCurve，符合规范
- ✅ **新版 ScaleDownOnPress**：新组件（sb_button/sb_card/sb_fab/sb_banner/sb_badge）均使用规范参数（0.95 / 200ms / easeOut）
- ⚠️ **motion_tokens.dart 未创建**：MotionDurations/MotionCurves Token 文件缺失，当前用内联值
- ⚠️ **旧版 ScaleDownOnPress**：widget_utils.dart 中 100ms 版本仍在 3 个文件中使用
- ⚠️ **时长/曲线散乱**：learn_page 已归档，其余页面待后续批次统一

**一句话总结**：学习核心路径的动效改造完整且正确，全局 Token 层和旧版组件迁移是下一步工作。

---

*本报告基于 2026-08-24 代码主干静态审读。*
