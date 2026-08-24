// 由 Claude 团队生成 | Monster Word App

// 由 Claude 团队生成 | 移植自 v3.2 widget/SlideBar.java, SegmentedGroup.java, VerticalDotLine.java, MyBadgeView.java, GuideView2.java, LabGuideView.java, MiddleToast.java, MyCustomeDialog.java, BottomInformationDialog.java, MyWebView.java
// 特殊功能组件集合
import 'package:flutter/material.dart';
import '../theme/skin_system.dart';
import '../tokens/design_tokens.dart';

// ─────────────────────────────────────────────────────────────
// SlideBar — 字母索引滑动条（移植自 SlideBar.java）
// ─────────────────────────────────────────────────────────────
class SlideBar extends StatefulWidget {
  final ValueChanged<String>? onLetterChanged;
  final Color? textColor;
  final Color? activeColor;
  final double fontSize;
  final double width;

  const SlideBar({
    super.key,
    this.onLetterChanged,
    this.textColor,
    this.activeColor,
    this.fontSize = 11,
    this.width = 24,
  });

  @override
  State<SlideBar> createState() => _SlideBarState();
}

class _SlideBarState extends State<SlideBar> {
  static const _letters = [
    'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M',
    'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z',
  ];
  int _choose = -1;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final tColor = widget.textColor ?? const Color(0xFF212121);
    final aColor = widget.activeColor ?? skin.colors.accent;

    return GestureDetector(
      onVerticalDragUpdate: (details) {
        final box = context.findRenderObject() as RenderBox;
        final y = details.localPosition.dy;
        final letterHeight = box.size.height / _letters.length;
        final index = (y / letterHeight).floor().clamp(0, _letters.length - 1);
        if (index != _choose) {
          setState(() => _choose = index);
          widget.onLetterChanged?.call(_letters[index]);
        }
      },
      onVerticalDragEnd: (_) => setState(() => _choose = -1),
      child: SizedBox(
        width: widget.width,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(_letters.length, (i) {
            final isActive = i == _choose;
            return SizedBox(
              height: 18,
              child: Center(
                child: Text(
                  _letters[i],
                  style: TextStyle(
                    fontSize: widget.fontSize,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                    color: isActive ? aColor : tColor,
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// SegmentedSelector — 分段选择器（移植自 SegmentedGroup.java）
// ─────────────────────────────────────────────────────────────
class SegmentedSelector extends StatelessWidget {
  final List<String> segments;
  final int selectedIndex;
  final ValueChanged<int>? onSelectionChanged;
  final Color? selectedColor;
  final Color? unselectedColor;
  final double height;

  const SegmentedSelector({
    super.key,
    required this.segments,
    this.selectedIndex = 0,
    this.onSelectionChanged,
    this.selectedColor,
    this.unselectedColor,
    this.height = 36,
  });

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final sColor = selectedColor ?? skin.colors.accent;
    final uColor = unselectedColor ?? skin.colors.cardBg;

    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: skin.colors.divider),
      ),
      child: Row(
        children: List.generate(segments.length, (i) {
          final isSelected = i == selectedIndex;
          return Expanded(
            child: GestureDetector(
              onTap: () => onSelectionChanged?.call(i),
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected ? sColor : uColor,
                  borderRadius: BorderRadius.horizontal(
                    left: i == 0 ? const Radius.circular(7) : Radius.zero,
                    right: i == segments.length - 1
                        ? const Radius.circular(7)
                        : Radius.zero,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  segments[i],
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    color: isSelected ? Colors.white : skin.colors.text2,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// VerticalDotLine — 垂直虚线（移植自 VerticalDotLine.java）
// ─────────────────────────────────────────────────────────────
class VerticalDotLine extends StatelessWidget {
  final double width;
  final double dashHeight;
  final double dashGap;
  final Color? color;

  const VerticalDotLine({
    super.key,
    this.width = 1,
    this.dashHeight = 2,
    this.dashGap = 4,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return CustomPaint(
      size: Size(width, double.infinity),
      painter: _DotLinePainter(
        color: color ?? skin.colors.divider,
        dashHeight: dashHeight,
        dashGap: dashGap,
        strokeWidth: width,
      ),
    );
  }
}

class _DotLinePainter extends CustomPainter {
  final Color color;
  final double dashHeight;
  final double dashGap;
  final double strokeWidth;

  _DotLinePainter({
    required this.color,
    required this.dashHeight,
    required this.dashGap,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;
    double y = 0;
    while (y < size.height) {
      canvas.drawLine(
        Offset(size.width / 2, y),
        Offset(size.width / 2, y + dashHeight),
        paint,
      );
      y += dashHeight + dashGap;
    }
  }

  @override
  bool shouldRepaint(_DotLinePainter old) => color != old.color;
}

// ─────────────────────────────────────────────────────────────
// GuideOverlay — 新手引导遮罩（移植自 GuideView2.java / LabGuideView.java）
// ─────────────────────────────────────────────────────────────
class GuideOverlay extends StatelessWidget {
  final List<GuideStep> steps;
  final int currentStep;
  final VoidCallback? onNext;
  final VoidCallback? onSkip;

  const GuideOverlay({
    super.key,
    required this.steps,
    this.currentStep = 0,
    this.onNext,
    this.onSkip,
  });

  static void show(
    BuildContext context, {
    required List<GuideStep> steps,
    VoidCallback? onComplete,
  }) {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) => _GuideOverlayDialog(
        steps: steps,
        onComplete: onComplete,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (currentStep >= steps.length) return const SizedBox.shrink();
    final step = steps[currentStep];
    return Stack(
      children: [
        // 高亮区域
        if (step.highlightRect != null)
          Positioned.fromRect(
            rect: step.highlightRect!,
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 2),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        // 提示文本
        if (step.message != null)
          Positioned(
            top: (step.highlightRect?.bottom ?? 100) + 12,
            left: 16,
            right: 16,
            child: Material(
              color: Colors.transparent,
              child: Text(
                step.message!,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}

class GuideStep {
  final Rect? highlightRect;
  final String? message;
  final Widget? customContent;

  const GuideStep({this.highlightRect, this.message, this.customContent});
}

class _GuideOverlayDialog extends StatefulWidget {
  final List<GuideStep> steps;
  final VoidCallback? onComplete;

  const _GuideOverlayDialog({required this.steps, this.onComplete});

  @override
  State<_GuideOverlayDialog> createState() => _GuideOverlayDialogState();
}

class _GuideOverlayDialogState extends State<_GuideOverlayDialog> {
  int _currentStep = 0;

  @override
  Widget build(BuildContext context) {
    if (_currentStep >= widget.steps.length) {
      Navigator.of(context).pop();
      widget.onComplete?.call();
      return const SizedBox.shrink();
    }
    final step = widget.steps[_currentStep];
    return GestureDetector(
      onTap: () {
        if (_currentStep < widget.steps.length - 1) {
          setState(() => _currentStep++);
        } else {
          Navigator.of(context).pop();
          widget.onComplete?.call();
        }
      },
      child: Material(
        color: Colors.transparent,
        child: Stack(
          children: [
            if (step.customContent != null)
              Center(child: step.customContent!)
            else if (step.message != null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        step.message!,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 18),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        '${_currentStep + 1}/${widget.steps.length}  点击继续',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              right: 16,
              child: TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  widget.onComplete?.call();
                },
                child: const Text('跳过',
                    style: TextStyle(color: Colors.white70)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// AppDialog — 自定义弹窗（移植自 MyCustomeDialog.java / BottomInformationDialog.java）
// ─────────────────────────────────────────────────────────────
class AppDialog {
  static Future<T?> show<T>(
    BuildContext context, {
    required Widget child,
    bool barrierDismissible = true,
    double? width,
    double borderRadius = 16,
  }) {
    final skin = context.skin;
    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (context) => Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: width ?? MediaQuery.of(context).size.width * 0.85,
            constraints: const BoxConstraints(maxHeight: 500),
            decoration: BoxDecoration(
              color: skin.colors.cardBg,
              borderRadius: BorderRadius.circular(borderRadius),
            ),
            padding: const EdgeInsets.all(20),
            child: child,
          ),
        ),
      ),
    );
  }

  static Future<T?> showBottom<T>(
    BuildContext context, {
    required Widget child,
    bool barrierDismissible = true,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        padding: const EdgeInsets.all(20),
        child: child,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// CustomWebView — 自定义 WebView（移植自 MyWebView.java）
// 使用 webview_flutter 包，需在 pubspec.yaml 中添加依赖
// ─────────────────────────────────────────────────────────────
class CustomWebView extends StatelessWidget {
  final String url;
  final String? initialTitle;
  final JavaScriptMode javaScriptMode;
  final void Function(String)? onPageFinished;
  final void Function(String)? onUrlChanged;

  const CustomWebView({
    super.key,
    required this.url,
    this.initialTitle,
    this.javaScriptMode = JavaScriptMode.unrestricted,
    this.onPageFinished,
    this.onUrlChanged,
  });

  @override
  Widget build(BuildContext context) {
    // 需要 webview_flutter 依赖
    // return WebView(
    //   initialUrl: url,
    //   javascriptMode: javaScriptMode,
    //   onPageFinished: onPageFinished,
    //   navigationDelegate: (request) {
    //     onUrlChanged?.call(request.url);
    //     return NavigationDecision.navigate;
    //   },
    // );
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.web, size: 48, color: Colors.grey),
          const SizedBox(height: 8),
          Text('WebView: $url', style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 4),
          const Text('需要添加 webview_flutter 依赖',
              style: TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }
}

// 需要导入 WebView 相关
// import 'package:webview_flutter/webview_flutter.dart';
enum JavaScriptMode {
  unrestricted,
  disabled,
}
