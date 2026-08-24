// lib/tokens/motion_tokens.dart
// 全局动效 Token — 对齐星巴克动效语言
// 来源：docs/motion_spec.md §4

import 'package:flutter/material.dart';

/// 动效时长档位（MotionDurations）
///
/// 用户主动触发的反馈一律落在 fast/base/slow 三档内；
/// expressive 只允许用于非交互的仪式性时刻。
/// >800ms 仅限环境/循环类（进度环、壁纸淡入），不得用于交互反馈。
class MotionDurations {
  /// 150ms — 按压反馈、图标微变、指示器、恢复态
  static const fast = Duration(milliseconds: 150);

  /// 200ms — 常规状态过渡：颜色、透明度、选项标红、Tab 切换
  static const base = Duration(milliseconds: 200);

  /// 300ms — 展开/收起、卡片翻转、弹层出入场、页面转场
  static const slow = Duration(milliseconds: 300);

  /// 450ms — 仅限整屏级入场与庆祝时刻（底栏首次入场、学习完成）
  static const expressive = Duration(milliseconds: 450);
}

/// 动效曲线档位（MotionCurves）
///
/// 缓动家族化原则：
/// - 进入/展开 → ease-out 家族（standard / accordion）
/// - 选中/确认 → 弹性过冲家族（springPop）
/// - 退出/消失 → ease-in 家族（exit）
class MotionCurves {
  /// 默认平滑 ease-out — Cubic(0.29, 0.09, 0.24, 0.99)
  /// 一切默认状态过渡（与星巴克 measured ease-out 同族）
  static const standard = Cubic(0.29, 0.09, 0.24, 0.99);

  /// 星巴克手风琴曲线 — cubic-bezier(0.25, 0.46, 0.45, 0.94) == Curves.easeOutQuad
  /// 展开/收起、高度/位置变化、入场滑入
  static const accordion = Cubic(0.25, 0.46, 0.45, 0.94);

  /// 星巴克复选框弹性曲线 — cubic-bezier(0.32, 2.32, 0.61, 0.27)
  /// 一次性微弹过冲：选中、确认、对勾、徽标出现
  static const springPop = Cubic(0.32, 2.32, 0.61, 0.27);

  /// 退出/离场 — cubic-bezier(0.4, 0.0, 0.5, 0.8) ≈ Curves.easeIn 族
  /// 退出、消失、dismiss
  static const exit = Cubic(0.4, 0.0, 0.5, 0.8);
}

/// 按压反馈标准量
///
/// 全 App 统一使用 ScaleDownOnPress 作为唯一按压封装：
/// ```dart
/// ScaleDownOnPress(
///   scale: MotionPress.scale,       // 0.95
///   duration: MotionDurations.base, // 200ms
///   curve: MotionCurves.standard,   // ease-out
///   onTap: () { ... },
///   child: child,
/// )
/// ```
class MotionPress {
  /// 按压缩放比例 — 星巴克 --buttonActiveScale
  static const double scale = 0.95;

  /// 按压动画时长
  static const Duration duration = Duration(milliseconds: 200);

  /// 按压动画曲线
  static const Curve curve = Curves.easeOut;
}
