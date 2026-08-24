# 动效 Token 一致性检查报告

> 检查日期：2026-08-24
> 检查范围：`lib/widgets/sb_*.dart` + `lib/widgets/scale_down_on_press.dart`
> 对照基准：`lib/tokens/motion_tokens.dart`

---

## 检查结果

### 发现的不一致项（已修复）

| 文件 | 行号 | 旧值 | 新值 | 状态 |
|---|---|---|---|---|
| sb_button.dart | 190 | `Duration(milliseconds: 200)` | `MotionDurations.base` | ✅ 已修复 |
| sb_segmented.dart | 61 | `Duration(milliseconds: 200)` | `MotionDurations.base` | ✅ 已修复 |
| sb_progress.dart | 56 | `Duration(milliseconds: 200)` | `MotionDurations.base` | ✅ 已修复 |
| sb_progress.dart | 115 | `Duration(milliseconds: 400)` | 保留（环形进度特例，已加注释） | ✅ 符合规范 |

### 已合规项（无需修改）

| 文件 | 使用的 Token | 状态 |
|---|---|---|
| scale_down_on_press.dart | `MotionPress.scale` / `MotionPress.duration` / `MotionPress.curve` | ✅ |
| sb_card.dart | `ScaleDownOnPress`（继承 motion token） | ✅ |
| sb_fab.dart | `ScaleDownOnPress`（继承 motion token） | ✅ |
| sb_banner.dart | `ScaleDownOnPress`（继承 motion token） | ✅ |
| sb_badge.dart | `ScaleDownOnPress`（继承 motion token） | ✅ |
| sb_modal.dart | `showModalBottomSheet` / `showDialog`（系统动画） | ✅ |

### Curves.ease vs Curves.easeOut 说明

sb_segmented.dart 和 sb_progress.dart 中的 `Curves.ease` 保留原值，原因：
- 星巴克原规格 CSS `ease` = `cubic-bezier(0.25, 0.1, 0.25, 1)` = Flutter `Curves.ease`
- `MotionCurves.standard` = `Cubic(0.29, 0.09, 0.24, 0.99)`（稍有不同的 ease-out 变体）
- 两者同族，视觉差异极小；保留 `Curves.ease` 与星巴克原规格精确匹配

---

## 结论

**所有 sb_* 组件的动效 Duration 已统一使用 MotionDurations token。** 仅 sb_progress.dart 的环形进度使用 400ms 特例档（非用户交互反馈，符合 motion_spec 约束）。

已提交：`refactor(motion): unify motion tokens across components`

---

*本报告基于 2026-08-24 代码主干静态审读。*
