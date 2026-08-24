// App Dock：macOS 风格底部导航栏，支持悬停/触摸放大 + 弹性动画
// 颜色可自定义，支持主题色适配
// 替代或增强现有底部导航栏
import 'package:flutter/material.dart';

import '../tokens/design_tokens.dart';

class DockItem {
  final IconData icon;
  final IconData? activeIcon;
  final String label;
  final Color? color;

  const DockItem({
    required this.icon,
    this.activeIcon,
    required this.label,
    this.color,
  });
}

class AppDock extends StatefulWidget {
  final List<DockItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;
  final Color? backgroundColor;
  final Color? activeColor;
  final Color? inactiveColor;
  final double height;
  final double iconSize;
  final double magnification;
  final EdgeInsets padding;
  final double borderRadius;

  const AppDock({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
    this.backgroundColor,
    this.activeColor,
    this.inactiveColor,
    this.height = 64,
    this.iconSize = 24,
    this.magnification = 1.4,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    this.borderRadius = 20,
  });

  @override
  State<AppDock> createState() => _AppDockState();
}

class _AppDockState extends State<AppDock> with TickerProviderStateMixin {
  int _hoverIndex = -1;
  late List<AnimationController> _scaleControllers;
  late List<Animation<double>> _scaleAnims;

  @override
  void initState() {
    super.initState();
    _scaleControllers = List.generate(widget.items.length, (i) {
      return AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 200),
      );
    });
    _scaleAnims = _scaleControllers.map((c) {
      return Tween<double>(begin: 1.0, end: widget.magnification).animate(
        CurvedAnimation(parent: c, curve: Curves.easeOutBack),
      );
    }).toList();
  }

  @override
  void dispose() {
    for (final c in _scaleControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _setHover(int index) {
    setState(() => _hoverIndex = index);
    if (index >= 0) {
      _scaleControllers[index].forward();
    }
    // 相邻项也轻微放大
    if (index > 0) {
      _scaleControllers[index - 1].forward();
    }
    if (index < widget.items.length - 1) {
      _scaleControllers[index + 1].forward();
    }
  }

  void _clearHover() {
    setState(() => _hoverIndex = -1);
    for (final c in _scaleControllers) {
      c.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = widget.backgroundColor ?? AppColors.white100.withValues(alpha: 0.92);
    final activeColor = widget.activeColor ?? const Color(0xFF006241);
    final inactiveColor = widget.inactiveColor ?? MistralColors.grey500;

    return MouseRegion(
      onExit: (_) => _clearHover(),
      child: Container(
        height: widget.height,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(widget.borderRadius),
          boxShadow: [
            BoxShadow(
              color: AppColors.black12,
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: AppColors.white100.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(widget.items.length, (i) {
            final item = widget.items[i];
            final isActive = i == widget.currentIndex;
            final isHovered = i == _hoverIndex;

            return MouseRegion(
              onEnter: (_) => _setHover(i),
              onExit: (_) => _clearHover(),
              child: GestureDetector(
                onTap: () => widget.onTap(i),
                child: AnimatedBuilder(
                  animation: _scaleAnims[i],
                  builder: (context, child) {
                    final scale = isHovered ? _scaleAnims[i].value : 1.0;
                    return Transform.scale(
                      scale: scale,
                      child: child,
                    );
                  },
                  child: Container(
                    padding: widget.padding,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isActive ? (item.activeIcon ?? item.icon) : item.icon,
                          size: widget.iconSize,
                          color: isActive
                              ? activeColor
                              : (isHovered ? activeColor.withValues(alpha: 0.7) : inactiveColor),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.label,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                            color: isActive
                                ? activeColor
                                : (isHovered ? activeColor.withValues(alpha: 0.7) : inactiveColor),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

/// 浮动 Dock（带背景模糊效果）
class FloatingDock extends StatelessWidget {
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
    final active = activeColor ?? const Color(0xFF006241);

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.white100.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.black12,
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
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
              padding: EdgeInsets.symmetric(
                horizontal: isActive ? 16 : 12,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: isActive ? active.withValues(alpha: 0.1) : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isActive ? (item.activeIcon ?? item.icon) : item.icon,
                    size: 22,
                    color: isActive ? active : MistralColors.grey500,
                  ),
                  if (isActive) ...[
                    const SizedBox(width: 6),
                    Text(
                      item.label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: active,
                      ),
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
