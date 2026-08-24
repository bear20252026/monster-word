// 由 MotionEngineer 生成 | Monster Word App
// 星巴克模态框组件：居中款 + 底部弹出版
// 规格来源：docs/component_spec.md §8 + docs/motion_spec.md

import 'package:flutter/material.dart';

/// 星巴克模态框模式
enum SbModalMode {
  /// 居中弹出（类似 showDialog）
  center,

  /// 底部弹出（类似 showModalBottomSheet）
  bottom,
}

/// 星巴克模态框组件
///
/// 两种模式：居中 [SbModalMode.center] 和底部弹出 [SbModalMode.bottom]
/// 规格：白卡 12px 圆角、遮罩 rgba(0,0,0,0.55)、顶部预留 88px 给标题/关闭钮
///
/// 用法：
/// ```dart
/// SbModal.show(
///   context,
///   mode: SbModalMode.bottom,
///   title: '设置',
///   child: Column(children: [...]),
///   actions: [PillButton(label: '确认', onTap: () {})],
/// );
/// ```
class SbModal extends StatelessWidget {
  /// 标题文本（可选）
  final String? title;

  /// 内容区域
  final Widget child;

  /// 底部操作按钮区域（可选）
  final List<Widget>? actions;

  /// 是否显示右上角关闭按钮（默认 true）
  final bool showClose;

  /// 内边距（默认四边 24）
  final EdgeInsetsGeometry padding;

  /// 最大宽度约束（居中模式默认 360）
  final double? maxWidth;

  const SbModal({
    super.key,
    this.title,
    required this.child,
    this.actions,
    this.showClose = true,
    this.padding = const EdgeInsets.fromLTRB(24, 88, 24, 24),
    this.maxWidth,
  });

  /// 显示模态框的静态方法
  ///
  /// [mode] 选择居中或底部弹出模式
  /// [barrierDismissible] 点击遮罩是否关闭（默认 true）
  static Future<T?> show<T>(
    BuildContext context, {
    SbModalMode mode = SbModalMode.center,
    String? title,
    required Widget child,
    List<Widget>? actions,
    bool showClose = true,
    bool barrierDismissible = true,
    double? maxWidth,
  }) {
    final modal = SbModal(
      title: title,
      showClose: showClose,
      maxWidth: maxWidth,
      actions: actions,
      child: child,
    );

    switch (mode) {
      case SbModalMode.center:
        return _showCenter<T>(context, modal, barrierDismissible);
      case SbModalMode.bottom:
        return _showBottom<T>(context, modal, barrierDismissible);
    }
  }

  /// 居中弹出
  static Future<T?> _showCenter<T>(
    BuildContext context,
    SbModal modal,
    bool barrierDismissible,
  ) {
    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierColor: Colors.black.withOpacity(0.55),
      builder: (_) => Dialog(
        backgroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: modal.maxWidth ?? 360),
          child: modal, // ignore: sort_child_properties_last — modal is the final child
        ),
      ),
    );
  }

  /// 底部弹出
  static Future<T?> _showBottom<T>(
    BuildContext context,
    SbModal modal,
    bool barrierDismissible,
  ) {
    return showModalBottomSheet<T>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      barrierColor: Colors.black.withOpacity(0.55),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (_) => SafeArea(child: modal),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 内容区域
        Padding(
          padding: padding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 标题（如果有）
              if (title != null) ...[
                Text(
                  title!,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Color(0xDE000000), // rgba(0,0,0,0.87)
                  ),
                ),
                const SizedBox(height: 16),
              ],
              // 主内容
              Flexible(child: child),
              // 底部操作按钮（如果有）
              if (actions != null && actions!.isNotEmpty) ...[
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: actions!
                      .map((a) => Padding(
                            padding: const EdgeInsets.only(left: 12),
                            child: a,
                          ))
                      .toList(),
                ),
              ],
            ],
          ),
        ),
        // 右上角关闭按钮
        if (showClose)
          Positioned(
            top: 16,
            right: 16,
            child: _CloseButton(onTap: () => Navigator.of(context).pop()),
          ),
      ],
    );
  }
}

/// 32px 圆形描边关闭按钮（星巴克规格）
class _CloseButton extends StatelessWidget {
  final VoidCallback onTap;

  const _CloseButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 32,
      height: 32,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(
          side: BorderSide(color: Color(0x3F000000), width: 1), // rgba(0,0,0,0.25)
        ),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: const Icon(
            Icons.close,
            size: 18,
            color: Color(0x99000000), // rgba(0,0,0,0.6)
          ),
        ),
      ),
    );
  }
}
