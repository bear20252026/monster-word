// 由 Claude 团队生成 | Monster Word App

// 由 Claude 团队生成 | 移植自 v3.2 widget/CircularImageView.java, RoundImageView.java, ClipParallaxImageView.java, FullScreenImageView.java, CustomImageView.java, MyRatioImageView.java
// 图片类组件集合
import 'package:flutter/material.dart';

import '../theme/skin_system.dart';
import '../tokens/design_tokens.dart';

// ─────────────────────────────────────────────────────────────
// CircularImage — 圆形头像图片（移植自 CircularImageView.java）
// ─────────────────────────────────────────────────────────────
class CircularImage extends StatelessWidget {
  final ImageProvider? image;
  final double size;
  final Color? borderColor;
  final double borderWidth;
  final Widget? placeholder;

  const CircularImage({
    super.key,
    this.image,
    this.size = 48,
    this.borderColor,
    this.borderWidth = 0,
    this.placeholder,
  });

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: borderWidth > 0 ? Border.all(color: borderColor ?? skin.colors.divider, width: borderWidth) : null,
        image: image != null ? DecorationImage(image: image!, fit: BoxFit.cover) : null,
      ),
      child: image == null ? placeholder ?? Icon(Icons.person, size: size * 0.5, color: skin.colors.text3) : null,
    );
  }
}

// ─────────────────────────────────────────────────────────────
// RoundImage — 圆角图片（移植自 RoundImageView.java）
// ─────────────────────────────────────────────────────────────
class RoundImage extends StatelessWidget {
  final ImageProvider? image;
  final double borderRadius;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;

  const RoundImage({
    super.key,
    this.image,
    this.borderRadius = 8,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
  });

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: image != null
          ? Image(image: image!, width: width, height: height, fit: fit)
          : Container(
              width: width,
              height: height,
              color: skin.colors.divider,
              child: placeholder ?? Icon(Icons.image, color: skin.colors.text3),
            ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// RatioImage — 固定比例图片（移植自 MyRatioImageView.java）
// ─────────────────────────────────────────────────────────────
class RatioImage extends StatelessWidget {
  final ImageProvider? image;
  final double aspectRatio;
  final double borderRadius;
  final BoxFit fit;

  const RatioImage({super.key, this.image, this.aspectRatio = 16 / 9, this.borderRadius = 0, this.fit = BoxFit.cover});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: aspectRatio,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: image != null
            ? Image(image: image!, fit: fit)
            : Container(color: MistralColors.slate.withValues(alpha: 0.2)),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// ParallaxImage — 视差图片（移植自 ClipParallaxImageView.java）
// ─────────────────────────────────────────────────────────────
class ParallaxImage extends StatelessWidget {
  final ImageProvider image;
  final double height;
  final double parallaxFactor; // 0.0 ~ 1.0
  final BoxFit fit;
  final Widget? child;

  const ParallaxImage({
    super.key,
    required this.image,
    this.height = 200,
    this.parallaxFactor = 0.3,
    this.fit = BoxFit.cover,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: OverflowBox(
        maxHeight: height * (1 + parallaxFactor),
        child: Image(image: image, fit: fit, width: double.infinity, height: double.infinity),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// FullScreenImageViewer — 全屏图片查看器（移植自 FullScreenImageView.java）
// ─────────────────────────────────────────────────────────────
class FullScreenImageViewer extends StatelessWidget {
  final ImageProvider image;
  final String? heroTag;

  const FullScreenImageViewer({super.key, required this.image, this.heroTag});

  static void show(BuildContext context, ImageProvider image, {String? heroTag}) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: MistralColors.ink,
        pageBuilder: (context, _, _) {
          return FullScreenImageViewer(image: image, heroTag: heroTag);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: InteractiveViewer(
            child: heroTag != null
                ? Hero(
                    tag: heroTag!,
                    child: Image(image: image),
                  )
                : Image(image: image),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// CustomIcon — 自定义图标视图（移植自 CustomImageView.java / ThirdPartIconView.java）
// ─────────────────────────────────────────────────────────────
class CustomIcon extends StatelessWidget {
  final IconData? icon;
  final String? assetPath;
  final double size;
  final Color? color;

  const CustomIcon({super.key, this.icon, this.assetPath, this.size = 24, this.color});

  @override
  Widget build(BuildContext context) {
    if (assetPath != null) {
      return Image.asset(assetPath!, width: size, height: size, color: color);
    }
    return Icon(icon ?? Icons.help_outline, size: size, color: color);
  }
}
