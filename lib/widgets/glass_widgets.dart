// 由账号4生成
// L2 玻璃组件：GlassSurface / GlassCard / GlassPill / WallpaperBg / ModalSheet
// 翻译自 Figma Primitives.js，玻璃拟态核心实现

import 'dart:ui';

import 'package:flutter/material.dart';

import '../hooks/responsive.dart';
import '../theme/skin_system.dart';
import '../tokens/design_tokens.dart';

/// 玻璃材质基座（原版 GlassSurface）
/// ClipRRect + BackdropFilter + 半透明渐变 + 白描边
class GlassSurface extends StatelessWidget {
  final Widget child;
  final bool strong; // true = glassBgStrong，签到卡等更实的玻璃
  final double radius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;

  const GlassSurface({
    super.key,
    required this.child,
    this.strong = false,
    this.radius = AppRadius.glass,
    this.padding,
    this.margin,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final bg = strong ? skin.colors.glassBgStrong : skin.colors.glassBg;
    final border = skin.colors.glassBorder;

    return Container(
      width: width,
      height: height,
      margin: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: strong ? AppGlass.blurStrong : AppGlass.blur,
            sigmaY: strong ? AppGlass.blurStrong : AppGlass.blur,
          ),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(color: border, width: 1),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// 首页玻璃入口卡（原版 GlassEntryCard：Learn/Review）
class GlassCard extends StatelessWidget {
  final String title; // 'Learn' 或 'Review'
  final int count;    // 待学/待复习数
  final VoidCallback? onTap;
  final double? width;

  const GlassCard({
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
    final countColor = count > 0 ? skin.colors.onGlassAccent : skin.colors.onGlassText2;

    return GestureDetector(
      onTap: onTap,
      child: GlassSurface(
        width: w,
        height: 88,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              style: AppTypography.body.copyWith(
                color: skin.colors.onGlassText2,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$count',
              style: AppTypography.metricLg.copyWith(
                color: countColor,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 玻璃胶囊按钮（原版 GlassPill）
class GlassPill extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final bool strong;
  final EdgeInsetsGeometry? padding;

  const GlassPill({
    super.key,
    required this.child,
    this.onTap,
    this.strong = false,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: GlassSurface(
        strong: strong,
        radius: AppRadius.pill,
        padding: padding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: child,
      ),
    );
  }
}

/// 壁纸背景（原版 WallpaperBg：Z0 壁纸 + Z1 遮罩 + Z2 内容）
class WallpaperBg extends StatelessWidget {
  final Widget child;

  const WallpaperBg({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final gradient = skin.wallpaperGradient;
    final scrim = skin.scrimColor;
    final wallpaper = skin.wallpaper;

    return Stack(
      children: [
        // Z0: 壁纸照片（或兜底渐变）
        Positioned.fill(
          child: wallpaper?.uri != null
              ? Image.network(wallpaper!.uri!, fit: BoxFit.cover)
              : Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: gradient,
                    ),
                  ),
                ),
        ),
        // Z1: 主题遮罩（明亮≈无 / 深邃=黑55% / 极夜=黑72%）
        Positioned.fill(
          child: Container(color: scrim),
        ),
        // Z2: 内容
        child,
      ],
    );
  }
}

/// 模态底部弹窗（原版 ModalSheet：Z4 层级）
class ModalSheet extends StatelessWidget {
  final bool visible;
  final VoidCallback onClose;
  final Widget child;
  final double? width;

  const ModalSheet({
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
        color: Colors.black54, // 遮罩
        child: Center(
          child: GestureDetector(
            onTap: () {}, // 防止穿透
            child: Container(
              width: width ?? 320,
              constraints: const BoxConstraints(maxHeight: 500),
              decoration: BoxDecoration(
                color: skin.colors.modalGlassBg,
                borderRadius: BorderRadius.circular(AppRadius.sheet),
                border: Border.all(color: skin.colors.glassBorder, width: 1),
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

/// 皮肤系统快捷访问
extension SkinExt on BuildContext {
  SkinSystem get skin {
    final widget = dependOnInheritedWidgetOfExactType<_SkinProvider>();
    return widget?.skin ?? SkinSystem();
  }
}

/// 皮肤注入 Widget（包裹在 MaterialApp 外层）
class SkinProvider extends InheritedWidget {
  final SkinSystem skin;
  const SkinProvider({super.key, required this.skin, required super.child});

  static SkinSystem of(BuildContext context) {
    final provider = context.dependOnInheritedWidgetOfExactType<SkinProvider>();
    return provider?.skin ?? SkinSystem();
  }

  @override
  bool updateShouldNotify(SkinProvider oldWidget) => skin.themeId != oldWidget.skin.themeId;
}

/// 内部使用的皮肤 Provider
class _SkinProvider extends InheritedWidget {
  final SkinSystem skin;
  const _SkinProvider({required this.skin, required super.child});

  @override
  bool updateShouldNotify(_SkinProvider old) => skin.themeId != old.skin.themeId;
}
