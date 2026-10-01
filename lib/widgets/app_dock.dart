// App Dock：macOS 风格底部导航栏，支持悬停/触摸放大 + 弹性动画
// 颜色可自定义，支持主题色适配
// 替代或增强现有底部导航栏
import 'package:flutter/material.dart';

import 'package:word_app/tokens/design_tokens.dart';
import 'package:word_app/theme/skin_system.dart';

class DockItem {
  final IconData icon;
  final IconData? activeIcon;
  final String label;
  final Color? color;

  const DockItem({required this.icon, this.activeIcon, required this.label, this.color});
}

/// 浮动 Dock（带背景模糊效果）
class FloatingDock extends StatelessWidget {
  /// 页面底部需为悬浮 Dock 预留的最小空隙（单一事实来源）。
  ///
  /// 主壳将 Dock 悬浮定位在底部安全区之上，Dock 自身再带 16 外边距 + 64 栏高；
  /// 页面底部固定内容（如工具栏）必须预留此高度，否则与 Dock 重叠。
  static double clearance(BuildContext context) => MediaQuery.of(context).padding.bottom + 16 + 64;

  final List<DockItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;
  final Color? activeColor;

  const FloatingDock({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
    this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    final active = activeColor ?? context.skin.colors.accent;

    return Container(
      margin: const EdgeInsets.all(AppSpacing.md),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: AppSpacing.xxs),
      decoration: BoxDecoration(
        color: AppColors.white100.withValues(alpha: AppAlphas.o85),
        borderRadius: BorderRadius.circular(context.design.radius.xl),
        boxShadow: [BoxShadow(color: AppColors.black12, blurRadius: 24, offset: const Offset(0, 8))],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(items.length, (i) {
          final item = items[i];
          final isActive = i == currentIndex;

          return GestureDetector(
            onTap: () => onTap(i),
            behavior: HitTestBehavior.opaque,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              padding: EdgeInsets.symmetric(horizontal: isActive ? 16 : 12, vertical: 10),
              decoration: BoxDecoration(
                color: isActive ? active.withValues(alpha: AppAlphas.o10) : Colors.transparent,
                borderRadius: BorderRadius.circular(context.design.radius.control),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isActive ? (item.activeIcon ?? item.icon) : item.icon,
                    size: 22,
                    color: isActive ? active : context.skin.colors.text2,
                  ),
                  if (isActive) ...[
                    const SizedBox(width: 6),
                    Text(
                      item.label,
                      style: MwTypography.micro.copyWith(fontWeight: FontWeight.w600, color: active),
                    ),
                  ],
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}
