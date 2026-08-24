// 由 Claude 团队生成 | Monster Word App

// 由账号4生成
// 自适应缩放：确保任意窗口大小都能正常显示，页面不会缩成一团
// 策略：设定最小可用尺寸（320×568），小于该尺寸时启用 FittedBox 等比缩放
import 'package:flutter/material.dart';

/// 自适应缩放包装器
/// 当窗口小于最小尺寸时等比缩放，大于最小尺寸时正常布局
class AdaptiveScale extends StatelessWidget {
  final Widget child;
  final double minWidth;
  final double minHeight;

  const AdaptiveScale({
    super.key,
    required this.child,
    this.minWidth = 360,
    this.minHeight = 640,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;

        // 窗口足够大，直接返回
        if (w >= minWidth && h >= minHeight) {
          return child;
        }

        // 窗口太小，等比缩放以适配
        return FittedBox(
          fit: BoxFit.contain,
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: minWidth,
            height: minHeight,
            child: child,
          ),
        );
      },
    );
  }
}
