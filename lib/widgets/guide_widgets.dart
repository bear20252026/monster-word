// 由 Claude 团队生成 | Monster Word App

// 由账号4生成
// 引导控件：翻译自 widget/ 中的引导类
// 文件：GuideView2, LabGuideView

import 'package:flutter/material.dart';
import 'animations.dart';
import '../tokens/design_tokens.dart';

/// 新手引导提示（翻译自 GuideView2.dart）
/// 在指定 View 附近显示带箭头的提示气泡
class GuideTooltip extends StatefulWidget {
  final Widget child;
  final String message;
  final bool showArrow;
  final bool arrowOnTop;
  final IconData? emoji;
  final VoidCallback? onDismiss;
  final Duration showDelay;
  final Color bgColor;
  final Color textColor;
  final int theme; // 0=normal, 1=dark

  const GuideTooltip({
    super.key,
    required this.child,
    required this.message,
    this.showArrow = true,
    this.arrowOnTop = false,
    this.emoji,
    this.onDismiss,
    this.showDelay = const Duration(milliseconds: 200),
    this.bgColor = AppColors.white100,
    this.textColor = MistralColors.ink,
    this.theme = 0,
  });

  @override
  State<GuideTooltip> createState() => _GuideTooltipState();
}

class _GuideTooltipState extends State<GuideTooltip>
    with SingleTickerProviderStateMixin {
  bool _visible = false;
  late AnimationController _controller;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: standardCurve),
    );
    _scaleAnim = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void show() {
    setState(() => _visible = true);
    _controller.forward();
  }

  void dismiss() {
    _controller.reverse().then((_) {
      setState(() => _visible = false);
      widget.onDismiss?.call();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!widget.arrowOnTop && _visible) _buildTooltip(),
        widget.child,
        if (widget.arrowOnTop && _visible) _buildTooltip(),
      ],
    );
  }

  Widget _buildTooltip() {
    return FadeTransition(
      opacity: _fadeAnim,
      child: ScaleTransition(
        scale: _scaleAnim,
        alignment: widget.arrowOnTop
            ? Alignment.bottomCenter
            : Alignment.topCenter,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: widget.theme == 1 ? MistralColors.ink : widget.bgColor,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: MistralColors.black15,
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.emoji != null) ...[
                Icon(widget.emoji, size: 20, color: widget.textColor),
                const SizedBox(width: 4),
              ],
              Flexible(
                child: Text(
                  widget.message,
                  style: TextStyle(
                    color: widget.theme == 1 ? AppColors.white100 : widget.textColor,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 引导提示箭头方向
enum GuideArrowDirection { top, bottom }

/// 实验室引导视图（翻译自 LabGuideView.dart）
/// 带箭头的引导气泡，支持上下箭头
class LabGuideBubble extends StatelessWidget {
  final String message;
  final bool arrowOnTop;
  final IconData? emoji;
  final Color bgColor;
  final Color textColor;
  final int theme; // 0=normal, 1=dark

  const LabGuideBubble({
    super.key,
    required this.message,
    this.arrowOnTop = false,
    this.emoji,
    this.bgColor = AppColors.white100,
    this.textColor = MistralColors.ink,
    this.theme = 0,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = theme == 1;
    return CustomPaint(
      painter: _BubbleArrowPainter(
        arrowOnTop: arrowOnTop,
        color: isDark ? MistralColors.ink : bgColor,
      ),
      child: Container(
        margin: EdgeInsets.only(
          top: arrowOnTop ? 8 : 0,
          bottom: arrowOnTop ? 0 : 8,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? MistralColors.ink : bgColor,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (emoji != null) ...[
              Icon(emoji, size: 20, color: textColor),
              const SizedBox(width: 4),
            ],
            Text(
              message,
              style: TextStyle(
                color: isDark ? AppColors.white100 : textColor,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BubbleArrowPainter extends CustomPainter {
  final bool arrowOnTop;
  final Color color;

  _BubbleArrowPainter({required this.arrowOnTop, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    if (arrowOnTop) {
      path.moveTo(size.width / 2 - 8, 0);
      path.lineTo(size.width / 2, -8);
      path.lineTo(size.width / 2 + 8, 0);
    } else {
      path.moveTo(size.width / 2 - 8, size.height);
      path.lineTo(size.width / 2, size.height + 8);
      path.lineTo(size.width / 2 + 8, size.height);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 引导类型常量（翻译自 GuideView2 中的常量）
class GuideType {
  static const int learnTip = 13;
  static const int learnFirstRight = 14;
  static const int learnSecondRight = 15;
  static const int learnThirdRight = 16;
  static const int learnFourthRight = 17;
  static const int learnWrong = 21;
  static const int learnLookExample = 23;
  static const int switchSound = 24;
  static const int downloadOffline = 25;
  static const int dictTip = 26;
  static const int selectExtensiveMode = 27;
  static const int shareAchievementMigrate = 28;
}
