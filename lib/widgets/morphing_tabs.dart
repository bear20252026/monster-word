// SimpleMorphingTabs：变形标签栏（等宽 tab 版），切换时指示器像液体一样拉伸变形
// 唯一使用方：lib_select_page（词书分类标签）。原 MorphingTabs/MorphingTabIndicator
// 因长期零引用已于 v2.7.34 删除，如需不等宽测量版请按需重写而非恢复死代码。
import 'package:flutter/material.dart';

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
