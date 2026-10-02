// 由 Claude 团队生成 | Monster Word App

// 答题反馈动效三原语（审计 P2-8 抽取）：对勾弹入 / 答错温柔下沉 / 候选卡双层浮起阴影。
// 学习页与正式复习候选卡此前同源双写约 55 行，此处收敛为单一实现；
// 曲线、位移、透明度数值与抽取前逐位一致，AnimationController 所有权留在调用方 State。
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:word_app/tokens/design_tokens.dart';
import 'package:word_app/tokens/motion_tokens.dart';

/// 对勾弹入原语：0.6→1.0 springPop 过冲缩放 + 随控制器进度的线性淡入。
///
/// [controller] 由调用方 State 持有并驱动（vsync 与时长归调用方，现两侧均为
/// MotionDurations.base），本原语只消费其动画值，不持有 ticker。
class MwCheckIconPop extends StatelessWidget {
  const MwCheckIconPop({
    super.key,
    required this.controller,
    required this.icon,
    required this.color,
    this.size = 24,
    this.curve = MotionCurves.springPop,
  });

  /// 弹入进度控制器（0→1）：淡入取其线性值，缩放经 [curve] 过冲。
  final AnimationController controller;

  /// 弹入的图标（学习页 check_circle_outline / 复习卡 check_circle_rounded）。
  final IconData icon;

  /// 图标颜色。
  final Color color;

  /// 图标边长。
  final double size;

  /// 缩放曲线 — 默认统一 MotionCurves.springPop（学习页内联 Cubic 已收编进 token）。
  final Curve curve;

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween<double>(begin: 0.6, end: 1.0).animate(CurvedAnimation(parent: controller, curve: curve)),
      child: FadeTransition(
        opacity: controller,
        child: Icon(icon, color: color, size: size),
      ),
    );
  }
}

/// 答错「温柔下沉」原语：sin(π·进度)·5px 下探即回 + 线性轻淡（最低 0.88），无左右位移。
///
/// [progress] 由调用方 State 持有的控制器驱动（现两侧均为 MotionDurations.slow），
/// 本原语只读其进度值，不持有 ticker。
class MwDipFeedback extends StatelessWidget {
  const MwDipFeedback({super.key, required this.progress, required this.child});

  /// 下沉进度（0→1 线性扫过，sin(π·v) 保证 5px 下探后原路回到 0）。
  final Animation<double> progress;

  /// 被包裹的内容；经 AnimatedBuilder 的 child 透传，动画帧不重建子树。
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: progress,
      builder: (context, child) {
        final dip = math.sin(progress.value * math.pi) * 5;
        final fade = 1 - progress.value * 0.12;
        return Transform.translate(
          offset: Offset(0, dip),
          child: Opacity(opacity: fade, child: child),
        );
      },
      child: child,
    );
  }
}

/// 答题候选卡的「双层浮起」阴影（审计 P2-8 收编两侧内联常量）。
abstract final class MwQuizElevation {
  /// 非状态卡阴影：发丝细影 (0,0) + 1px 下坠影 (0,1)；状态卡（绿/红）以色块表达，不带影。
  static const List<BoxShadow> shadows = [
    BoxShadow(color: MwShadows.softShadow, blurRadius: 0.5, offset: Offset(0, 0)),
    BoxShadow(color: MwShadows.liftShadow, blurRadius: 1, offset: Offset(0, 1)),
  ];
}
