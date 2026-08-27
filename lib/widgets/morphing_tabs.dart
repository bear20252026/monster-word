// Morphing Tabs：变形标签栏，切换时指示器像液体一样拉伸变形
// 颜色可自定义，支持弹性动画和视差效果
// 适用于：词书分类标签、设置页标签、任何 Tab 切换场景
import 'dart:math' as math;

import 'package:flutter/material.dart';

class MorphingTab {
  final String label;
  final IconData? icon;
  final Widget? child;

  const MorphingTab({required this.label, this.icon, this.child});
}

class MorphingTabs extends StatefulWidget {
  final List<MorphingTab> tabs;
  final int initialIndex;
  final ValueChanged<int> onChanged;
  final Color? activeColor;
  final Color? inactiveColor;
  final Color? indicatorColor;
  final Color? backgroundColor;
  final double height;
  final double borderRadius;
  final EdgeInsets padding;
  final Duration animationDuration;
  final bool showIndicator;
  final bool enableParallax;

  const MorphingTabs({
    super.key,
    required this.tabs,
    this.initialIndex = 0,
    required this.onChanged,
    this.activeColor,
    this.inactiveColor,
    this.indicatorColor,
    this.backgroundColor,
    this.height = 44,
    this.borderRadius = 14,
    this.padding = const EdgeInsets.all(3),
    this.animationDuration = const Duration(milliseconds: 400),
    this.showIndicator = true,
    this.enableParallax = true,
  });

  @override
  State<MorphingTabs> createState() => _MorphingTabsState();
}

class _MorphingTabsState extends State<MorphingTabs> with TickerProviderStateMixin {
  late int _currentIndex;
  late AnimationController _morphController;
  late AnimationController _bounceController;
  late Animation<double> _morphAnim;
  late Animation<double> _bounceAnim;

  // 每个 tab 的位置信息
  final List<double> _tabWidths = [];
  final List<GlobalKey> _tabKeys = [];
  final List<Offset> _tabPositions = [];
  bool _measured = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _tabKeys.addAll(List.generate(widget.tabs.length, (_) => GlobalKey()));
    _tabPositions.addAll(List.generate(widget.tabs.length, (_) => Offset.zero));

    _morphController = AnimationController(vsync: this, duration: widget.animationDuration);
    _bounceController = AnimationController(vsync: this, duration: const Duration(milliseconds: 200));

    _morphAnim = CurvedAnimation(parent: _morphController, curve: Curves.easeInOutCubic);
    _bounceAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.12), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.12, end: 0.95), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 0.95, end: 1.0), weight: 30),
    ]).animate(CurvedAnimation(parent: _bounceController, curve: Curves.easeOut));

    WidgetsBinding.instance.addPostFrameCallback((_) => _measureTabs());
  }

  @override
  void dispose() {
    _morphController.dispose();
    _bounceController.dispose();
    super.dispose();
  }

  void _measureTabs() {
    if (!mounted) return;
    _tabWidths.clear();
    _tabPositions.clear();

    for (int i = 0; i < _tabKeys.length; i++) {
      final ctx = _tabKeys[i].currentContext;
      if (ctx != null) {
        final box = ctx.findRenderObject() as RenderBox?;
        if (box != null) {
          _tabWidths.add(box.size.width);
          _tabPositions.add(box.localToGlobal(Offset.zero));
        }
      }
    }

    if (_tabWidths.length == widget.tabs.length) {
      setState(() => _measured = true);
    }
  }

  void _selectTab(int index) {
    if (index == _currentIndex) return;
    setState(() => _currentIndex = index);
    _morphController.forward(from: 0);
    _bounceController.forward(from: 0);
    widget.onChanged(index);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeColor = widget.activeColor ?? Colors.white;
    final inactiveColor = widget.inactiveColor ?? theme.colorScheme.onSurface.withValues(alpha: 0.6);
    final indicatorColor = widget.indicatorColor ?? const Color(0xFF006241);
    final bgColor = widget.backgroundColor ?? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5);

    return LayoutBuilder(
      builder: (context, constraints) {
        // 重新测量（布局变化时）
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _measureTabs();
        });

        return Container(
          height: widget.height,
          decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(widget.borderRadius)),
          padding: widget.padding,
          child: Stack(
            children: [
              // 变形指示器
              if (widget.showIndicator && _measured && _tabPositions.isNotEmpty)
                AnimatedBuilder(
                  animation: Listenable.merge([_morphAnim, _bounceAnim]),
                  builder: (context, _) {
                    return _buildMorphIndicator(indicatorColor, constraints.maxWidth);
                  },
                ),
              // Tab 项
              Row(
                children: List.generate(widget.tabs.length, (i) {
                  final tab = widget.tabs[i];
                  final isActive = i == _currentIndex;

                  return Expanded(
                    child: GestureDetector(
                      key: _tabKeys[i],
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _selectTab(i),
                      child: Container(
                        height: widget.height - widget.padding.vertical,
                        alignment: Alignment.center,
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 200),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                            color: isActive ? activeColor : inactiveColor,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (tab.icon != null) ...[
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  child: Icon(
                                    tab.icon,
                                    size: isActive ? 16 : 14,
                                    color: isActive ? activeColor : inactiveColor,
                                  ),
                                ),
                                const SizedBox(width: 4),
                              ],
                              Flexible(child: Text(tab.label, overflow: TextOverflow.ellipsis)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMorphIndicator(Color color, double totalWidth) {
    final progress = _morphAnim.value;
    final bounce = _bounceAnim.value;

    // 计算当前和下一个 tab 的位置
    final currentPos = _tabPositions[_currentIndex];
    final currentWidth = _tabWidths[_currentIndex];

    // 指示器位置（相对于容器）
    final indicatorLeft = currentPos.dx - (totalWidth - _getTotalTabWidth()) / 2;
    final indicatorWidth = currentWidth;

    // 变形效果：切换时拉伸
    final stretchFactor = 1.0 + 0.15 * math.sin(progress * math.pi);

    return Positioned(
      left: indicatorLeft - (indicatorWidth * (stretchFactor - 1)) / 2,
      top: 0,
      bottom: 0,
      width: indicatorWidth * stretchFactor,
      child: Transform.scale(
        scaleY: bounce,
        child: Container(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(widget.borderRadius - widget.padding.top),
            boxShadow: [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 2))],
          ),
        ),
      ),
    );
  }

  double _getTotalTabWidth() {
    if (_tabWidths.isEmpty) return 0;
    return _tabWidths.reduce((a, b) => a + b);
  }
}

/// 简化的变形标签（无测量，等宽 tab）
class SimpleMorphingTabs extends StatefulWidget {
  final List<String> labels;
  final int initialIndex;
  final ValueChanged<int> onChanged;
  final Color? activeColor;
  final Color? inactiveColor;
  final Color? indicatorColor;
  final Color? backgroundColor;
  final double height;
  final double borderRadius;
  final EdgeInsets padding;

  const SimpleMorphingTabs({
    super.key,
    required this.labels,
    this.initialIndex = 0,
    required this.onChanged,
    this.activeColor,
    this.inactiveColor,
    this.indicatorColor,
    this.backgroundColor,
    this.height = 42,
    this.borderRadius = 12,
    this.padding = const EdgeInsets.all(3),
  });

  @override
  State<SimpleMorphingTabs> createState() => _SimpleMorphingTabsState();
}

class _SimpleMorphingTabsState extends State<SimpleMorphingTabs> with TickerProviderStateMixin {
  late int _currentIndex;
  late AnimationController _controller;
  late AnimationController _bounceCtrl;
  late Animation<double> _slideAnim;
  late Animation<double> _morphAnim;
  late Animation<double> _bounceAnim;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;

    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 450));
    _bounceCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 250));

    _slideAnim = CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic);
    _morphAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.25), weight: 35),
      TweenSequenceItem(tween: Tween(begin: 1.25, end: 0.92), weight: 35),
      TweenSequenceItem(tween: Tween(begin: 0.92, end: 1.0), weight: 30),
    ]).animate(_controller);
    _bounceAnim = Tween<double>(
      begin: 1.0,
      end: 1.08,
    ).animate(CurvedAnimation(parent: _bounceCtrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    _bounceCtrl.dispose();
    super.dispose();
  }

  void _select(int index) {
    if (index == _currentIndex) return;
    setState(() => _currentIndex = index);
    _controller.forward(from: 0);
    _bounceCtrl.forward(from: 0).then((_) {
      if (mounted) _bounceCtrl.reverse();
    });
    widget.onChanged(index);
  }

  @override
  Widget build(BuildContext context) {
    final activeColor = widget.activeColor ?? Colors.white;
    final inactiveColor = widget.inactiveColor ?? Colors.grey;
    final indicatorColor = widget.indicatorColor ?? const Color(0xFF006241);
    final bgColor = widget.backgroundColor ?? Colors.grey.withValues(alpha: 0.12);

    return LayoutBuilder(
      builder: (context, constraints) {
        final tabWidth = (constraints.maxWidth - widget.padding.horizontal) / widget.labels.length;

        return Container(
          height: widget.height,
          decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(widget.borderRadius)),
          padding: widget.padding,
          child: Stack(
            children: [
              // 变形指示器
              AnimatedBuilder(
                animation: Listenable.merge([_slideAnim, _morphAnim, _bounceAnim]),
                builder: (context, _) {
                  final left = widget.padding.left + tabWidth * _currentIndex;
                  final stretch = _morphAnim.value;
                  final offset = tabWidth * (stretch - 1) / 2;

                  return Positioned(
                    left: left - offset,
                    top: 0,
                    bottom: 0,
                    width: tabWidth * stretch,
                    child: Transform.scale(
                      scaleY: _bounceAnim.value,
                      child: Container(
                        decoration: BoxDecoration(
                          color: indicatorColor,
                          borderRadius: BorderRadius.circular(widget.borderRadius - widget.padding.top),
                          boxShadow: [
                            BoxShadow(
                              color: indicatorColor.withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
              // Tab 标签
              Row(
                children: List.generate(widget.labels.length, (i) {
                  final isActive = i == _currentIndex;
                  return Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _select(i),
                      child: Container(
                        height: widget.height - widget.padding.vertical,
                        alignment: Alignment.center,
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 200),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                            color: isActive ? activeColor : inactiveColor,
                          ),
                          child: Text(widget.labels[i]),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// 带视差效果的变形标签指示器
class MorphingTabIndicator extends StatelessWidget {
  final int tabCount;
  final int currentIndex;
  final double progress;
  final Color color;
  final double height;
  final double borderRadius;

  const MorphingTabIndicator({
    super.key,
    required this.tabCount,
    required this.currentIndex,
    required this.progress,
    required this.color,
    this.height = 4,
    this.borderRadius = 2,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final tabWidth = constraints.maxWidth / tabCount;
        final left = tabWidth * (currentIndex + progress);
        final stretch = 1.0 + 0.3 * math.sin(progress * math.pi);

        return Positioned(
          left: left - tabWidth * (stretch - 1) / 2,
          bottom: 0,
          width: tabWidth * stretch,
          height: height,
          child: Container(
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(borderRadius),
              boxShadow: [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 6)],
            ),
          ),
        );
      },
    );
  }
}
