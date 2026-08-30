// Monster Word — 统一 UI 反馈出口（健康评估 M5：止住 SnackBar/Dialog 复制扩散）
//
// 约定：新代码的用户反馈一律走本文件 helper，不再直接
// ScaffoldMessenger.of(context).showSnackBar(...)。
import 'package:flutter/material.dart';

/// 轻提示（替代散落各处的 ScaffoldMessenger.showSnackBar）
/// [type] 控制左侧色条语义色；[duration] 默认 2 秒。
void showMwToast(
  BuildContext context,
  String message, {
  MwToastType type = MwToastType.info,
  Duration duration = const Duration(seconds: 2),
}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;

  final scheme = Theme.of(context).colorScheme;
  final Color accent = switch (type) {
    MwToastType.success => Colors.green.shade600,
    MwToastType.error => scheme.error,
    MwToastType.info => scheme.primary,
  };

  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      duration: duration,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      backgroundColor: accent.withValues(alpha: 0.95),
    ),
  );
}

enum MwToastType { success, error, info }

/// 确认对话框：返回 true=确认，false/null=取消
Future<bool> showMwConfirm(
  BuildContext context, {
  required String title,
  required String content,
  String confirmLabel = '确定',
  String cancelLabel = '取消',
  bool danger = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(content),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(cancelLabel)),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: danger ? FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error) : null,
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result == true;
}

/// 结果对话框：单一"好的"按钮，成功/失败语义图标（替代手写 icon+AlertDialog 样板）
Future<void> showMwResult(
  BuildContext context, {
  required bool success,
  required String title,
  required String message,
}) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: Icon(
        success ? Icons.check_circle_outline : Icons.error_outline,
        color: success ? Colors.green : Theme.of(ctx).colorScheme.error,
        size: 48,
      ),
      title: Text(title),
      content: Text(message),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('好的'))],
    ),
  );
}
