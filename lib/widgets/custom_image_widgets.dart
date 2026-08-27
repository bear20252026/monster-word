// 由 Claude 团队生成 | Monster Word App

// 由账号4生成
// 图片相关控件：翻译自 widget/ 中的图片类
// 文件：CustomImageView, MyRatioImageView, RoundImageView, FullScreenImageView, ClipParallaxImageView

import 'package:flutter/material.dart';

/// 自定义图片（翻译自 CustomImageView.dart）
/// 支持圆形和圆角两种裁剪模式
class CustomClipImage extends StatelessWidget {
  final ImageProvider image;
  final bool isCircle;
  final double radius;
  final double? width;
  final double? height;
  final BoxFit fit;

  const CustomClipImage({
    super.key,
    required this.image,
    this.isCircle = true,
    this.radius = 10.0,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: isCircle ? BorderRadius.circular(999) : BorderRadius.circular(radius),
      child: Image(image: image, width: width, height: height, fit: fit),
    );
  }
}

/// 固定比例图片（翻译自 MyRatioImageView.dart）
/// 支持宽高比、圆角、边框、遮罩
class RatioImageView extends StatelessWidget {
  final ImageProvider? image;
  final double ratio; // height / width
  final double radius;
  final int cornerType; // 0=all, 1=top only
  final bool showBorder;
  final Color borderColor;
  final double borderWidth;
  final bool enableMask;
  final Color maskColor;
  final Widget? topOverlay;
  final BoxFit fit;

  const RatioImageView({
    super.key,
    this.image,
    this.ratio = 0.0,
    this.radius = 0.0,
    this.cornerType = 0,
    this.showBorder = false,
    this.borderColor = Colors.transparent,
    this.borderWidth = 0.0,
    this.enableMask = false,
    this.maskColor = const Color(0x61000000),
    this.topOverlay,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: ratio > 0 ? 1.0 / ratio : 1.0,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: _borderRadius(),
          border: showBorder ? Border.all(color: borderColor, width: borderWidth) : null,
        ),
        child: ClipRRect(
          borderRadius: _borderRadius(),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (image != null) Image(image: image!, fit: fit),
              if (enableMask) Container(color: maskColor),
              if (topOverlay != null) Positioned.fill(child: topOverlay!),
            ],
          ),
        ),
      ),
    );
  }

  BorderRadius _borderRadius() {
    if (cornerType == 1) {
      return BorderRadius.only(topLeft: Radius.circular(radius), topRight: Radius.circular(radius));
    }
    return BorderRadius.circular(radius);
  }
}

/// 圆角图片（翻译自 RoundImageView.dart）
/// 支持四个角分别设置不同圆角
class RoundCornerImage extends StatelessWidget {
  final ImageProvider image;
  final double topLeft;
  final double topRight;
  final double bottomLeft;
  final double bottomRight;
  final double? width;
  final double? height;
  final BoxFit fit;

  const RoundCornerImage({
    super.key,
    required this.image,
    this.topLeft = 0,
    this.topRight = 0,
    this.bottomLeft = 0,
    this.bottomRight = 0,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.only(
        topLeft: Radius.circular(topLeft),
        topRight: Radius.circular(topRight),
        bottomLeft: Radius.circular(bottomLeft),
        bottomRight: Radius.circular(bottomRight),
      ),
      child: Image(image: image, width: width, height: height, fit: fit),
    );
  }
}

/// 全屏图片（翻译自 FullScreenImageView.dart）
/// 自动铺满容器并支持视差效果
class FullScreenImageView extends StatelessWidget {
  final ImageProvider image;
  final double parallaxFactor;

  const FullScreenImageView({super.key, required this.image, this.parallaxFactor = 0.0});

  @override
  Widget build(BuildContext context) {
    return Image(
      image: image,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      alignment: Alignment(0, parallaxFactor),
    );
  }
}

/// 视差裁剪图片（翻译自 ClipParallaxImageView.dart）
class ClipParallaxImage extends StatelessWidget {
  final ImageProvider image;
  final double parallaxFactor;
  final BorderRadius? borderRadius;

  const ClipParallaxImage({super.key, required this.image, this.parallaxFactor = 0.0, this.borderRadius});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.zero,
      child: Image(image: image, fit: BoxFit.cover, alignment: Alignment(0, parallaxFactor)),
    );
  }
}
