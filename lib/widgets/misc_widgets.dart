// 由 Claude 团队生成 | Monster Word App

// 由账号4生成
// 杂项控件：翻译自 widget/ 中的其他类
// 文件：VerticalDotLine, WalkmanWaveSurfaceView, MainView, MyWebView, NewLinearLayout, ThirdPartIconView

import 'package:flutter/material.dart';
import 'dart:math' as math;

/// 垂直虚线（翻译自 VerticalDotLine.dart）
class VerticalDotLine extends StatelessWidget {
  final double width;
  final double height;
  final Color color;
  final double dashWidth;
  final double dashSpace;

  const VerticalDotLine({
    super.key,
    this.width = 1,
    this.height = 100,
    this.color = const Color(0x33000000),
    this.dashWidth = 2,
    this.dashSpace = 4,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(width, height),
      painter: _VerticalDotLinePainter(
        color: color,
        dashWidth: dashWidth,
        dashSpace: dashSpace,
      ),
    );
  }
}

class _VerticalDotLinePainter extends CustomPainter {
  final Color color;
  final double dashWidth;
  final double dashSpace;

  _VerticalDotLinePainter({
    required this.color,
    required this.dashWidth,
    required this.dashSpace,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = size.width
      ..style = PaintingStyle.stroke;

    double y = 0;
    while (y < size.height) {
      canvas.drawLine(
        Offset(size.width / 2, y),
        Offset(size.width / 2, y + dashWidth),
        paint,
      );
      y += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 主界面视图（翻译自 MainView.dart）
/// 支持下拉手势监听
class MainScrollView extends StatefulWidget {
  final Widget child;
  final ValueChanged<double>? onScrollY;
  final VoidCallback? onScrollEnd;

  const MainScrollView({
    super.key,
    required this.child,
    this.onScrollY,
    this.onScrollEnd,
  });

  @override
  State<MainScrollView> createState() => _MainScrollViewState();
}

class _MainScrollViewState extends State<MainScrollView> {
  double _startY = 0;
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onVerticalDragStart: (details) {
        _startY = details.globalPosition.dy;
        _isDragging = false;
      },
      onVerticalDragUpdate: (details) {
        final dy = details.globalPosition.dy - _startY;
        if (!_isDragging && dy > 10) {
          _isDragging = true;
        }
        if (_isDragging) {
          widget.onScrollY?.call(dy);
        }
      },
      onVerticalDragEnd: (_) {
        if (_isDragging) {
          widget.onScrollEnd?.call();
        }
      },
      child: widget.child,
    );
  }
}

/// 自定义 WebView 容器（翻译自 MyWebView.dart）
/// 使用 webview_flutter 或 flutter_inappwebview
class CustomWebView extends StatelessWidget {
  final String? initialUrl;
  final String? initialHtml;
  final ValueChanged<String>? onPageStarted;
  final ValueChanged<String>? onPageFinished;
  final ValueChanged<double>? onScrollChanged;
  final bool enableJavaScript;

  const CustomWebView({
    super.key,
    this.initialUrl,
    this.initialHtml,
    this.onPageStarted,
    this.onPageFinished,
    this.onScrollChanged,
    this.enableJavaScript = true,
  });

  @override
  Widget build(BuildContext context) {
    // 需要引入 webview_flutter 或 flutter_inappwebview
    // 这里提供基础结构，实际使用时需补充 WebView 实现
    return Container(
      color: Colors.transparent,
      child: const Center(
        child: Text('WebView placeholder - requires webview_flutter'),
      ),
    );
  }
}

/// 新版线性布局（翻译自 NewLinearLayout.dart）
/// Android API 24+ 的 post() 兼容处理
/// Flutter 中不需要此控件，直接使用 Column/Row 即可
/// 这里提供一个带 post 延迟功能的容器
class PostCapableColumn extends StatelessWidget {
  final List<Widget> children;
  final MainAxisAlignment mainAxisAlignment;
  final CrossAxisAlignment crossAxisAlignment;
  final MainAxisSize mainAxisSize;

  const PostCapableColumn({
    super.key,
    required this.children,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.crossAxisAlignment = CrossAxisAlignment.center,
    this.mainAxisSize = MainAxisSize.min,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: mainAxisAlignment,
      crossAxisAlignment: crossAxisAlignment,
      mainAxisSize: mainAxisSize,
      children: children,
    );
  }
}

/// 第三方图标容器（翻译自 ThirdPartIconView.dart）
/// 简单的图标容器，用于显示第三方登录图标等
class ThirdPartyIcon extends StatelessWidget {
  final IconData? icon;
  final Widget? child;
  final double size;
  final Color? color;
  final VoidCallback? onTap;

  const ThirdPartyIcon({
    super.key,
    this.icon,
    this.child,
    this.size = 44,
    this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color?.withValues(alpha: 0.1),
        ),
        child: Center(
          child: child ??
              (icon != null ? Icon(icon, size: size * 0.5, color: color) : null),
        ),
      ),
    );
  }
}

/// 随身听波浪动画（翻译自 WalkmanWaveSurfaceView.dart）
/// 模拟音频播放时的波浪效果
class WalkmanWaveAnimation extends StatefulWidget {
  final bool isPlaying;
  final Color waveColor;
  final Color logoColor;
  final double size;

  const WalkmanWaveAnimation({
    super.key,
    this.isPlaying = false,
    this.waveColor = Colors.blue,
    this.logoColor = Colors.white,
    this.size = 200,
  });

  @override
  State<WalkmanWaveAnimation> createState() => _WalkmanWaveAnimationState();
}

class _WalkmanWaveAnimationState extends State<WalkmanWaveAnimation>
    with TickerProviderStateMixin {
  late AnimationController _waveController;
  late AnimationController _logoController;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    );
    if (widget.isPlaying) {
      _waveController.repeat();
      _logoController.repeat();
    }
  }

  @override
  void didUpdateWidget(WalkmanWaveAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying && !oldWidget.isPlaying) {
      _waveController.repeat();
      _logoController.repeat();
    } else if (!widget.isPlaying && oldWidget.isPlaying) {
      _waveController.stop();
      _logoController.stop();
    }
  }

  @override
  void dispose() {
    _waveController.dispose();
    _logoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: Listenable.merge([_waveController, _logoController]),
        builder: (context, child) {
          return CustomPaint(
            painter: _WavePainter(
              waveProgress: _waveController.value,
              logoAngle: _logoController.value * 2 * math.pi,
              waveColor: widget.waveColor,
              logoColor: widget.logoColor,
              isPlaying: widget.isPlaying,
            ),
          );
        },
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  final double waveProgress;
  final double logoAngle;
  final Color waveColor;
  final Color logoColor;
  final bool isPlaying;

  _WavePainter({
    required this.waveProgress,
    required this.logoAngle,
    required this.waveColor,
    required this.logoColor,
    required this.isPlaying,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // 画波浪
    if (isPlaying) {
      final wavePaint = Paint()
        ..color = waveColor.withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;

      for (int i = 0; i < 3; i++) {
        final waveRadius = radius * (0.3 + i * 0.2) * waveProgress;
        final opacity = (1 - waveProgress).clamp(0.0, 1.0);
        wavePaint.color = waveColor.withValues(alpha: 0.3 * opacity);
        canvas.drawCircle(center, waveRadius, wavePaint);
      }
    }

    // 画中心 logo
    final logoPaint = Paint()
      ..color = logoColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius * 0.2, logoPaint);
  }

  @override
  bool shouldRepaint(_WavePainter oldDelegate) =>
      oldDelegate.waveProgress != waveProgress ||
      oldDelegate.isPlaying != isPlaying;
}
