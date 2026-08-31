// Testimonial Slider：引言/励志语轮播组件
// 自动轮播 + 手动滑动 + 渐变过渡 + 弹性手势
// 颜色可自定义
// 适用于：首页每日一句、学习激励语、用户评价展示
import 'dart:async';

import 'package:flutter/material.dart';

class TestimonialItem {
  final String text;
  final String? author;
  final String? source;
  final IconData? icon;
  final Color? color;

  const TestimonialItem({required this.text, this.author, this.source, this.icon, this.color});
}

class TestimonialSlider extends StatefulWidget {
  final List<TestimonialItem> items;
  final Duration autoPlayInterval;
  final bool autoPlay;
  final double height;
  final Color? activeColor;
  final Color? inactiveColor;
  final EdgeInsets padding;
  final BorderRadius? borderRadius;
  final Function(int)? onPageChanged;

  const TestimonialSlider({
    super.key,
    required this.items,
    this.autoPlayInterval = const Duration(seconds: 5),
    this.autoPlay = true,
    this.height = 140,
    this.activeColor,
    this.inactiveColor,
    this.padding = const EdgeInsets.all(20),
    this.borderRadius,
    this.onPageChanged,
  });

  @override
  State<TestimonialSlider> createState() => _TestimonialSliderState();
}

class _TestimonialSliderState extends State<TestimonialSlider> {
  late PageController _pageController;
  Timer? _autoPlayTimer;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.9);
    if (widget.autoPlay) {
      _startAutoPlay();
    }
  }

  void _startAutoPlay() {
    // 使用可取消的 Timer，避免 dispose 后仍有挂起的定时器
    // （Future.delayed 无法取消，会导致测试环境 pending timer 断言失败）
    _autoPlayTimer?.cancel();
    _autoPlayTimer = Timer(widget.autoPlayInterval, () {
      if (!mounted) return;
      final nextPage = (_currentPage + 1) % widget.items.length;
      _pageController.animateToPage(nextPage, duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
      _startAutoPlay();
    });
  }

  @override
  void dispose() {
    _autoPlayTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeColor = widget.activeColor ?? const Color(0xFF006241);
    final inactiveColor = widget.inactiveColor ?? Colors.grey.withValues(alpha: 0.3);

    return SizedBox(
      height: widget.height,
      child: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: widget.items.length,
              onPageChanged: (index) {
                setState(() => _currentPage = index);
                widget.onPageChanged?.call(index);
              },
              itemBuilder: (context, index) {
                final item = widget.items[index];
                final diff = (index - _currentPage).abs();
                final scale = (1 - diff * 0.08).clamp(0.9, 1.0);

                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                  child: Transform.scale(scale: scale, child: _buildCard(item, activeColor)),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          // 指示器
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(widget.items.length, (i) {
              final isActive = i == _currentPage;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                width: isActive ? 20 : 6,
                height: 6,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: isActive ? activeColor : inactiveColor,
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(TestimonialItem item, Color activeColor) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      padding: widget.padding,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            (item.color ?? activeColor).withValues(alpha: 0.1),
            (item.color ?? activeColor).withValues(alpha: 0.05),
          ],
        ),
        borderRadius: widget.borderRadius ?? BorderRadius.circular(16),
        border: Border.all(color: (item.color ?? activeColor).withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (item.icon != null) ...[
            Icon(item.icon, color: item.color ?? activeColor, size: 24),
            const SizedBox(height: 8),
          ],
          Expanded(
            child: Text(
              item.text,
              // 深色适配：跟随主题明暗，而非硬编码黑色（体验审计 P1）
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                height: 1.5,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.87),
              ),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (item.author != null) ...[
            const SizedBox(height: 4),
            Text(
              '— ${item.author}${item.source != null ? ' · ${item.source}' : ''}',
              style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45)),
            ),
          ],
        ],
      ),
    );
  }
}

/// 内置励志语数据
class TestimonialData {
  static const List<TestimonialItem> defaults = [
    TestimonialItem(text: '学习改变命运，每一天的积累都是未来的基石。', author: 'Monster Word', icon: Icons.auto_stories),
    TestimonialItem(
      text: 'The limits of my language mean the limits of my world.',
      author: 'Ludwig Wittgenstein',
      source: '哲学家',
      icon: Icons.format_quote,
    ),
    TestimonialItem(text: '背单词不是一场苦旅，而是一次次征服的成就感。', author: 'Monster Word', icon: Icons.emoji_events),
    TestimonialItem(text: '千里之行，始于足下。每天进步一点点，终将抵达远方。', author: '老子', source: '《道德经》', icon: Icons.landscape),
    TestimonialItem(
      text: 'Consistency is what transforms average into excellence.',
      source: 'Unknown',
      icon: Icons.star_outline,
    ),
  ];
}
