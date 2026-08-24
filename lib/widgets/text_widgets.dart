// 由 Claude 团队生成 | Monster Word App

// 由 Claude 团队生成 | 移植自 v3.2 widget/AutoFitTextView.java, AutoFitEditTextView.java, MyTextView.java, MyAnimatedNumTextView.java, TextViewUtils.java, AssetsTypefaceTextView.java
// 文本类组件集合
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../theme/skin_system.dart';
import 'animations.dart';
// ─────────────────────────────────────────────────────────────
// AutoFitText — 自动适配字号文本（移植自 AutoFitTextView.java）
// ─────────────────────────────────────────────────────────────
class AutoFitText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final double minFontSize;
  final double maxFontSize;
  final int maxLines;
  final TextAlign textAlign;

  const AutoFitText(
    this.text, {
    super.key,
    this.style,
    this.minFontSize = 10,
    this.maxFontSize = 24,
    this.maxLines = 1,
    this.textAlign = TextAlign.center,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        double fontSize = maxFontSize;
        final defaultStyle = style ?? DefaultTextStyle.of(context).style;
        while (fontSize >= minFontSize) {
          final tp = TextPainter(
            text: TextSpan(
              text: text,
              style: defaultStyle.copyWith(fontSize: fontSize),
            ),
            maxLines: maxLines,
            textDirection: TextDirection.ltr,
          )..layout(maxWidth: constraints.maxWidth);
          if (!tp.didExceedMaxLines) {
            break;
          }
          fontSize -= 1;
        }
        return Text(
          text,
          style: (style ?? DefaultTextStyle.of(context).style)
              .copyWith(fontSize: fontSize),
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
          textAlign: textAlign,
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────
// AnimatedNumberText — 数字动画文本（移植自 MyAnimatedNumTextView.java）
// ─────────────────────────────────────────────────────────────
class AnimatedNumberText extends StatefulWidget {
  final int number;
  final TextStyle? style;
  final Duration duration;
  final String prefix;
  final String suffix;

  const AnimatedNumberText({
    super.key,
    required this.number,
    this.style,
    this.duration = const Duration(milliseconds: 300),
    this.prefix = '',
    this.suffix = '',
  });

  @override
  State<AnimatedNumberText> createState() => _AnimatedNumberTextState();
}

class _AnimatedNumberTextState extends State<AnimatedNumberText>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  Animation<int>? _animation;
  int _displayNumber = 0;

  @override
  void initState() {
    super.initState();
    _displayNumber = widget.number;
  }

  @override
  void didUpdateWidget(AnimatedNumberText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.number != widget.number) {
      _controller?.dispose();
      _controller = AnimationController(
        vsync: this,
        duration: widget.duration,
      );
      _animation = IntTween(
        begin: _displayNumber,
        end: widget.number,
      ).animate(CurvedAnimation(
        parent: _controller!,
        curve: standardCurve,
      ))
        ..addListener(() {
          setState(() {
            _displayNumber = _animation!.value;
          });
        });
      _controller!.forward();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      '${widget.prefix}$_displayNumber${widget.suffix}',
      style: widget.style,
    );
  }
}

// ─────────────────────────────────────────────────────────────
// BadgeView — 角标视图（移植自 MyBadgeView.java）
// ─────────────────────────────────────────────────────────────
class BadgeView extends StatelessWidget {
  final Widget child;
  final int count;
  final bool showBadge;
  final Color? badgeColor;
  final Color? textColor;
  final double size;

  const BadgeView({
    super.key,
    required this.child,
    this.count = 0,
    this.showBadge = true,
    this.badgeColor,
    this.textColor,
    this.size = 16,
  });

  @override
  Widget build(BuildContext context) {
    if (!showBadge || count <= 0) return child;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          right: -4,
          top: -4,
          child: Container(
            padding: count > 9
                ? const EdgeInsets.symmetric(horizontal: 4, vertical: 1)
                : null,
            constraints: BoxConstraints(
              minWidth: size,
              minHeight: size,
            ),
            decoration: BoxDecoration(
              color: badgeColor ?? context.skin.colors.danger,
              borderRadius: BorderRadius.circular(size / 2),
            ),
            child: count > 0
                ? Text(
                    count > 99 ? '99+' : '$count',
                    style: TextStyle(
                      color: textColor ?? Colors.white,
                      fontSize: size * 0.65,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  )
                : null,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// MiddleToast — 居中 Toast（移植自 MiddleToast.java）
// ─────────────────────────────────────────────────────────────
class MiddleToast {
  static void show(BuildContext context, String message,
      {Duration duration = const Duration(seconds: 2)}) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => _ToastWidget(
        message: message,
        onDismiss: () => entry.remove(),
        duration: duration,
      ),
    );
    overlay.insert(entry);
  }
}

class _ToastWidget extends StatefulWidget {
  final String message;
  final VoidCallback onDismiss;
  final Duration duration;

  const _ToastWidget({
    required this.message,
    required this.onDismiss,
    required this.duration,
  });

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    )..forward();
    Future.delayed(widget.duration, () {
      if (mounted) {
        _controller.reverse().then((_) => widget.onDismiss());
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              widget.message,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// AutoLinkText — 自动链接文本（移植自 AutoLinkStyleTextView.java / component/AutoLinkStyleTextView.java）
// ─────────────────────────────────────────────────────────────
class AutoLinkText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextStyle? linkStyle;
  final void Function(String url)? onLinkTap;

  const AutoLinkText(
    this.text, {
    super.key,
    this.style,
    this.linkStyle,
    this.onLinkTap,
  });

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final defaultLinkStyle = linkStyle ??
        TextStyle(
          color: skin.colors.accent,
          decoration: TextDecoration.underline,
        );
    return RichText(
      text: _buildTextSpan(text, style ?? DefaultTextStyle.of(context).style,
          defaultLinkStyle, onLinkTap),
    );
  }

  static TextSpan _buildTextSpan(
    String text,
    TextStyle defaultStyle,
    TextStyle linkStyle,
    void Function(String)? onLinkTap,
  ) {
    final urlPattern = RegExp(
      r'(https?://[^\s]+)',
      caseSensitive: false,
    );
    final spans = <InlineSpan>[];
    int lastEnd = 0;
    for (final match in urlPattern.allMatches(text)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(
          text: text.substring(lastEnd, match.start),
          style: defaultStyle,
        ));
      }
      final url = match.group(0)!;
      spans.add(TextSpan(
        text: url,
        style: linkStyle,
        recognizer: TapGestureRecognizer()..onTap = () => onLinkTap?.call(url),
      ));
      lastEnd = match.end;
    }
    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd), style: defaultStyle));
    }
    return TextSpan(children: spans);
  }
}
