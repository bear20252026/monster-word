// Apple 风格卡片轮播：3D 透视 + 缩放 + 视差效果
// 适用于：词书选择、单词卡片轮播、功能展示
import 'package:flutter/material.dart';

import '../tokens/design_tokens.dart';

class AppleCardCarousel extends StatefulWidget {
  final List<Widget> children;
  final double height;
  final double viewportFraction;
  final Function(int)? onPageChanged;
  final Duration animationDuration;
  final bool autoPlay;
  final Duration autoPlayInterval;

  const AppleCardCarousel({
    super.key,
    required this.children,
    this.height = 200,
    this.viewportFraction = 0.8,
    this.onPageChanged,
    this.animationDuration = const Duration(milliseconds: 400),
    this.autoPlay = false,
    this.autoPlayInterval = const Duration(seconds: 4),
  });

  @override
  State<AppleCardCarousel> createState() => _AppleCardCarouselState();
}

class _AppleCardCarouselState extends State<AppleCardCarousel> {
  late PageController _pageController;
  double _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: widget.viewportFraction);
    _pageController.addListener(() {
      setState(() {
        _currentPage = _pageController.page ?? 0;
      });
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: PageView.builder(
        controller: _pageController,
        itemCount: widget.children.length,
        onPageChanged: widget.onPageChanged,
        itemBuilder: (context, index) {
          final diff = (index - _currentPage).abs();
          final scale = (1 - diff * 0.15).clamp(0.85, 1.0);
          final opacity = (1 - diff * 0.3).clamp(0.5, 1.0);

          return AnimatedContainer(
            duration: widget.animationDuration,
            curve: Curves.easeOutCubic,
            child: Transform.scale(
              scale: scale,
              child: Opacity(opacity: opacity, child: widget.children[index]),
            ),
          );
        },
      ),
    );
  }
}

/// 词书选择卡片
class BookCarouselCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final int wordCount;
  final Color color;
  final IconData icon;
  final VoidCallback? onTap;
  final double progress;

  const BookCarouselCard({
    super.key,
    required this.title,
    this.subtitle = '',
    this.wordCount = 0,
    this.color = const Color(0xFF006241),
    this.icon = Icons.menu_book,
    this.onTap,
    this.progress = 0,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color, color.withValues(alpha: 0.8)],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 8))],
        ),
        child: Stack(
          children: [
            // 装饰圆
            Positioned(
              top: -30,
              right: -30,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.white100.withValues(alpha: 0.1)),
              ),
            ),
            Positioned(
              bottom: -20,
              left: -20,
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.white100.withValues(alpha: 0.08)),
              ),
            ),
            // 内容
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, color: AppColors.white100, size: 28),
                  const SizedBox(height: 12),
                  Text(
                    title,
                    style: const TextStyle(color: AppColors.white100, fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(subtitle, style: TextStyle(color: AppColors.white100.withValues(alpha: 0.8), fontSize: 13)),
                  ],
                  const Spacer(),
                  if (wordCount > 0) ...[
                    Text(
                      '$wordCount words',
                      style: TextStyle(color: AppColors.white100.withValues(alpha: 0.7), fontSize: 12),
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor: AppColors.white100.withValues(alpha: 0.2),
                        valueColor: const AlwaysStoppedAnimation(AppColors.white100),
                        minHeight: 4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
