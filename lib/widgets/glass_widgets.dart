// 由 Claude 团队生成 | Monster Word App
// 玻璃拟态组件库 - 实现毛玻璃效果

import 'dart:ui';
import 'package:flutter/material.dart';

import '../hooks/responsive.dart';
import '../theme/skin_system.dart';
import '../tokens/design_tokens.dart';

/// 玻璃拟态卡片容器 - 实现毛玻璃效果
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final double blur;
  final double opacity;
  final double radius;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.blur = 10.0,
    this.opacity = 0.8,
    this.radius = 16.0,
  });

  @override
  Widget build(BuildContext context) {
    final skin = context.skin.colors;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          width: width,
          height: height,
          margin: margin,
          padding: padding,
          decoration: BoxDecoration(
            color: skin.glassBg.withValues(alpha: opacity),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: skin.glassBorder.withValues(alpha: 0.2),
              width: 0.5,
            ),
            boxShadow: [
              BoxShadow(
                color: skin.text1.withValues(alpha: 0.1),
                blurRadius: 10.0,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

/// 玻璃拟态入口卡（Learn/Review 按钮）
class GlassEntryCard extends StatelessWidget {
  final String title;
  final int count;
  final VoidCallback? onTap;
  final double? width;

  const GlassEntryCard({
    super.key,
    required this.title,
    required this.count,
    this.onTap,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final skin = context.skin.colors;
    final w = width ?? context.responsive.glassCardWidth;

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16.0),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
          child: Container(
            width: w,
            height: 88,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: skin.glassBg.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(16.0),
              border: Border.all(
                color: skin.glassBorder.withValues(alpha: 0.2),
                width: 0.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: skin.text1.withValues(alpha: 0.1),
                  blurRadius: 10.0,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: MistralTypography.captionBold.copyWith(
                    color: skin.text1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$count',
                  style: MistralTypography.heading2.copyWith(
                    color: count > 0 ? skin.accent : skin.text3,
                    fontSize: 32,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 玻璃拟态胶囊按钮
class GlassPill extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;

  const GlassPill({super.key, required this.child, this.onTap, this.padding});

  @override
  Widget build(BuildContext context) {
    final skin = context.skin.colors;
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20.0),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
          child: Container(
            padding: padding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: skin.glassBg.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(20.0),
              border: Border.all(
                color: skin.glassBorder.withValues(alpha: 0.2),
                width: 0.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: skin.text1.withValues(alpha: 0.1),
                  blurRadius: 10.0,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// 玻璃拟态背景容器
class GlassBg extends StatelessWidget {
  final Widget child;
  const GlassBg({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final skin = context.skin.colors;
    return Container(
      color: skin.pageBg,
      child: child,
    );
  }
}

/// 玻璃拟态模态弹窗
class GlassModal extends StatelessWidget {
  final bool visible;
  final VoidCallback onClose;
  final Widget child;
  final double? width;

  const GlassModal({
    super.key,
    required this.visible,
    required this.onClose,
    required this.child,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();
    final skin = context.skin.colors;

    return GestureDetector(
      onTap: onClose,
      child: Container(
        color: skin.text1.withValues(alpha: 0.38),
        child: Center(
          child: GestureDetector(
            onTap: () {},
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16.0),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
                child: Container(
                  width: width ?? 320,
                  constraints: const BoxConstraints(maxHeight: 500),
                  decoration: BoxDecoration(
                    color: skin.glassBg.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(16.0),
                    border: Border.all(
                      color: skin.glassBorder.withValues(alpha: 0.2),
                      width: 0.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: skin.text1.withValues(alpha: 0.1),
                        blurRadius: 10.0,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(20),
                  child: child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
