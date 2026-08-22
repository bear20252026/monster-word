// 由账号4生成
// Apple Design Language 组件库
// 去掉玻璃拟态/BackdropFilter，全部改为苹果纯色卡片+清晰布局
import 'package:flutter/material.dart';

import '../hooks/responsive.dart';
import '../theme/skin_system.dart';
import '../tokens/design_tokens.dart';

/// 苹果风格卡片容器（替代 GlassSurface）
class AppleCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final Color? color;
  final double radius;

  const AppleCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.color,
    this.radius = AppleRadius.md,
  });

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Container(
      width: width,
      height: height,
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? skin.colors.cardBg,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: skin.colors.divider, width: 0.5),
      ),
      child: child,
    );
  }
}

/// 苹果风格入口卡（替代 GlassCard：Learn/Review）
class AppleEntryCard extends StatelessWidget {
  final String title;
  final int count;
  final VoidCallback? onTap;
  final double? width;

  const AppleEntryCard({
    super.key,
    required this.title,
    required this.count,
    this.onTap,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final w = width ?? context.responsive.glassCardWidth;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: w,
        height: 88,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: skin.colors.cardBg,
          borderRadius: BorderRadius.circular(AppleRadius.md),
          border: Border.all(color: skin.colors.divider, width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              style: AppleTypography.captionStrong.copyWith(color: skin.colors.text3),
            ),
            const SizedBox(height: 8),
            Text(
              '$count',
              style: AppleTypography.displayLg.copyWith(
                color: count > 0 ? skin.colors.accent : skin.colors.text3,
                fontSize: 32,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 苹果风格胶囊按钮（替代 GlassPill）
class ApplePill extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;

  const ApplePill({super.key, required this.child, this.onTap, this.padding});

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: padding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: skin.colors.cardBg,
          borderRadius: BorderRadius.circular(AppleRadius.pill),
          border: Border.all(color: skin.colors.divider, width: 0.5),
        ),
        child: child,
      ),
    );
  }
}

/// 苹果风格纯色背景（替代 WallpaperBg：去掉壁纸，用纯色背景）
class AppleBg extends StatelessWidget {
  final Widget child;
  const AppleBg({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Container(
      color: skin.colors.pageBg,
      child: child,
    );
  }
}

/// 苹果风格模态弹窗（替代 ModalSheet）
class AppleModal extends StatelessWidget {
  final bool visible;
  final VoidCallback onClose;
  final Widget child;
  final double? width;

  const AppleModal({
    super.key,
    required this.visible,
    required this.onClose,
    required this.child,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();
    final skin = context.skin;

    return GestureDetector(
      onTap: onClose,
      child: Container(
        color: Colors.black38,
        child: Center(
          child: GestureDetector(
            onTap: () {},
            child: Container(
              width: width ?? 320,
              constraints: const BoxConstraints(maxHeight: 500),
              decoration: BoxDecoration(
                color: skin.colors.cardBg,
                borderRadius: BorderRadius.circular(AppleRadius.lg),
                border: Border.all(color: skin.colors.divider, width: 0.5),
              ),
              padding: const EdgeInsets.all(20),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
