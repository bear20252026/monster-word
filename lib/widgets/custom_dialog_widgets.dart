// 由 Claude 团队生成 | Monster Word App

// 由账号4生成
// 弹窗/Toast 控件：翻译自 widget/ 中的弹窗类
// 文件：MyCustomeDialog, MiddleToast, BottomInformationDialog

import 'package:flutter/material.dart';

import '../tokens/design_tokens.dart';
import 'animations.dart';

/// 自定义弹窗（翻译自 MyCustomeDialog.dart）
/// 带模糊背景遮罩的弹窗
class CustomBlurDialog extends StatelessWidget {
  final Widget child;
  final bool barrierDismissible;
  final Color barrierColor;

  const CustomBlurDialog({
    super.key,
    required this.child,
    this.barrierDismissible = true,
    this.barrierColor = const Color(0x60000000),
  });

  /// 显示弹窗
  static Future<T?> show<T>(
    BuildContext context, {
    required Widget child,
    bool barrierDismissible = true,
    Color barrierColor = const Color(0x60000000),
  }) {
    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierColor: barrierColor,
      builder: (_) => child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(backgroundColor: Colors.transparent, elevation: 0, child: child);
  }
}

/// 居中 Toast（翻译自 MiddleToast.dart）
class MiddleToast {
  static OverlayEntry? _entry;
  static bool _isVisible = false;

  /// 显示居中 Toast
  static void show(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 2),
    IconData? icon,
  }) {
    if (_isVisible) {
      hide();
    }
    _isVisible = true;
    _entry = OverlayEntry(
      builder: (_) => _MiddleToastWidget(message: message, icon: icon, onDismiss: hide),
    );
    Overlay.of(context).insert(_entry!);
    Future.delayed(duration, hide);
  }

  static void hide() {
    if (_entry != null) {
      _entry!.remove();
      _entry = null;
      _isVisible = false;
    }
  }
}

class _MiddleToastWidget extends StatefulWidget {
  final String message;
  final IconData? icon;
  final VoidCallback onDismiss;

  const _MiddleToastWidget({required this.message, this.icon, required this.onDismiss});

  @override
  State<_MiddleToastWidget> createState() => _MiddleToastWidgetState();
}

class _MiddleToastWidgetState extends State<_MiddleToastWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 225));
    _fadeAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: standardCurve));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(color: MistralColors.ink, borderRadius: BorderRadius.circular(12)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, color: AppColors.white100, size: 36),
                const SizedBox(height: 8),
              ],
              Text(
                widget.message,
                style: const TextStyle(color: AppColors.white100, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 底部信息弹窗（翻译自 BottomInformationDialog.dart）
class BottomInfoSheet extends StatelessWidget {
  final String? title;
  final Widget child;
  final bool showHandle;

  const BottomInfoSheet({super.key, this.title, required this.child, this.showHandle = true});

  /// 显示底部弹窗
  static Future<T?> show<T>(BuildContext context, {String? title, required Widget child, bool showHandle = true}) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BottomInfoSheet(title: title, showHandle: showHandle, child: child),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white100,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showHandle) ...[
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: MistralColors.slate.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
          if (title != null) ...[
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(title!, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ],
          Flexible(child: child),
        ],
      ),
    );
  }
}
