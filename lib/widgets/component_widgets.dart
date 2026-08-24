// 由 Claude 团队生成 | Monster Word App

// 由 Claude 团队生成 | 移植自 v3.2 widget/component/ 下的通用组件
// 通用组件集合：按钮、文本、进度条、图片等
import 'package:flutter/material.dart';
import '../theme/skin_system.dart';
import '../tokens/design_tokens.dart';
// ─────────────────────────────────────────────────────────────
// CustomButton — 自定义按钮（移植自 component/CustomButton.java）
// ─────────────────────────────────────────────────────────────
enum ButtonVariant { filled, outlined, text, elevated }

class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final ButtonVariant variant;
  final Color? color;
  final Color? textColor;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final Widget? icon;
  final bool enabled;
  final double? width;
  final double? height;

  const CustomButton({
    super.key,
    required this.text,
    this.onPressed,
    this.variant = ButtonVariant.filled,
    this.color,
    this.textColor,
    this.borderRadius = 8,
    this.padding,
    this.icon,
    this.enabled = true,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final btnColor = color ?? skin.colors.accent;
    final txtColor = textColor ?? (variant == ButtonVariant.filled ? AppColors.white100 : btnColor);

    return SizedBox(
      width: width,
      height: height ?? 44,
      child: switch (variant) {
        ButtonVariant.filled => ElevatedButton(
            onPressed: enabled ? onPressed : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: btnColor,
              foregroundColor: txtColor,
              padding: padding ?? const EdgeInsets.symmetric(horizontal: 20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(borderRadius),
              ),
              elevation: 0,
            ),
            child: _buildChild(txtColor),
          ),
        ButtonVariant.outlined => OutlinedButton(
            onPressed: enabled ? onPressed : null,
            style: OutlinedButton.styleFrom(
              foregroundColor: btnColor,
              padding: padding ?? const EdgeInsets.symmetric(horizontal: 20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(borderRadius),
              ),
              side: BorderSide(color: btnColor),
            ),
            child: _buildChild(txtColor),
          ),
        ButtonVariant.text => TextButton(
            onPressed: enabled ? onPressed : null,
            style: TextButton.styleFrom(
              foregroundColor: btnColor,
              padding: padding ?? const EdgeInsets.symmetric(horizontal: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(borderRadius),
              ),
            ),
            child: _buildChild(txtColor),
          ),
        ButtonVariant.elevated => ElevatedButton(
            onPressed: enabled ? onPressed : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: skin.colors.cardBg,
              foregroundColor: skin.colors.text1,
              padding: padding ?? const EdgeInsets.symmetric(horizontal: 20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(borderRadius),
              ),
              elevation: 2,
            ),
            child: _buildChild(skin.colors.text1),
          ),
      },
    );
  }

  Widget _buildChild(Color color) {
    if (icon != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon!,
          const SizedBox(width: 8),
          Text(text, style: TextStyle(color: color)),
        ],
      );
    }
    return Text(text);
  }
}

// ─────────────────────────────────────────────────────────────
// CustomText — 自定义文本（移植自 component/CustomTextView.java / widget/MyTextView.java）
// ─────────────────────────────────────────────────────────────
class CustomText extends StatelessWidget {
  final String text;
  final double? fontSize;
  final FontWeight? fontWeight;
  final Color? color;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow overflow;
  final double? letterSpacing;
  final double? height;
  final String? fontFamily;

  const CustomText(
    this.text, {
    super.key,
    this.fontSize,
    this.fontWeight,
    this.color,
    this.textAlign,
    this.maxLines,
    this.overflow = TextOverflow.ellipsis,
    this.letterSpacing,
    this.height,
    this.fontFamily,
  });

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Text(
      text,
      style: TextStyle(
        fontSize: fontSize ?? 14,
        fontWeight: fontWeight,
        color: color ?? skin.colors.text1,
        letterSpacing: letterSpacing,
        height: height,
        fontFamily: fontFamily,
      ),
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: maxLines != null ? overflow : null,
    );
  }
}

// ─────────────────────────────────────────────────────────────
// DrawableCenterText — Drawable 居中文本（移植自 component/DrawableCenterTextView.java）
// ─────────────────────────────────────────────────────────────
class DrawableCenterText extends StatelessWidget {
  final String text;
  final IconData? leftIcon;
  final IconData? rightIcon;
  final double iconSize;
  final double spacing;
  final TextStyle? style;
  final Color? iconColor;

  const DrawableCenterText({
    super.key,
    required this.text,
    this.leftIcon,
    this.rightIcon,
    this.iconSize = 16,
    this.spacing = 4,
    this.style,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (leftIcon != null) ...[
          Icon(leftIcon, size: iconSize, color: iconColor ?? skin.colors.text2),
          SizedBox(width: spacing),
        ],
        Text(text, style: style),
        if (rightIcon != null) ...[
          SizedBox(width: spacing),
          Icon(rightIcon, size: iconSize, color: iconColor ?? skin.colors.text2),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// CustomVectorIcon — 矢量图片（移植自 component/CustomVectorImageView.java）
// ─────────────────────────────────────────────────────────────
class CustomVectorIcon extends StatelessWidget {
  final IconData icon;
  final double size;
  final Color? color;
  final String? semanticLabel;

  const CustomVectorIcon({
    super.key,
    required this.icon,
    this.size = 24,
    this.color,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Icon(icon, size: size, color: color, semanticLabel: semanticLabel);
  }
}

// ─────────────────────────────────────────────────────────────
// ShadowBox — 阴影布局（移植自 component/ShadowLayout.java）
// ─────────────────────────────────────────────────────────────
class ShadowBox extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final Color? shadowColor;
  final double blurRadius;
  final Offset offset;
  final Color? backgroundColor;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;

  const ShadowBox({
    super.key,
    required this.child,
    this.borderRadius = 8,
    this.shadowColor,
    this.blurRadius = 8,
    this.offset = const Offset(0, 2),
    this.backgroundColor,
    this.padding,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor ?? skin.colors.cardBg,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: shadowColor ?? MistralColors.black15,
            blurRadius: blurRadius,
            offset: offset,
          ),
        ],
      ),
      child: child,
    );
  }
}

// ─────────────────────────────────────────────────────────────
// VerticalLevel — 垂直等级视图（移植自 component/VerticalLevelView.java）
// ─────────────────────────────────────────────────────────────
class VerticalLevel extends StatelessWidget {
  final int level;
  final int maxLevel;
  final double width;
  final double height;
  final Color? activeColor;
  final Color? inactiveColor;

  const VerticalLevel({
    super.key,
    required this.level,
    this.maxLevel = 5,
    this.width = 4,
    this.height = 40,
    this.activeColor,
    this.inactiveColor,
  });

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final aColor = activeColor ?? skin.colors.accent;
    final iColor = inactiveColor ?? skin.colors.divider;
    final segmentHeight = height / maxLevel;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(maxLevel, (i) {
        final isActive = i < level;
        return Container(
          width: width,
          height: segmentHeight,
          margin: const EdgeInsets.symmetric(vertical: 1),
          decoration: BoxDecoration(
            color: isActive ? aColor : iColor,
            borderRadius: BorderRadius.circular(width / 2),
          ),
        );
      }),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// ImageCell — 自定义图片单元格（移植自 component/MyImageView.java）
// ─────────────────────────────────────────────────────────────
class ImageCell extends StatelessWidget {
  final ImageProvider? image;
  final double size;
  final double borderRadius;
  final VoidCallback? onTap;

  const ImageCell({
    super.key,
    this.image,
    this.size = 48,
    this.borderRadius = 8,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: image != null
            ? Image(
                image: image!,
                width: size,
                height: size,
                fit: BoxFit.cover,
              )
            : Container(
                width: size,
                height: size,
                color: skin.colors.divider,
                child: Icon(Icons.image, size: size * 0.4, color: skin.colors.text3),
              ),
      ),
    );
  }
}
