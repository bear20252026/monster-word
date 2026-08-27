// 会话退出保护：拦截系统返回键/手势返回，防止误触丢失学习进度
import 'package:flutter/material.dart';

/// 学习类页面的返回保护。
///
/// 用法：将页面的 Scaffold 用 [SessionExitGuard] 包裹：
/// ```dart
/// return SessionExitGuard(
///   subject: '本次学习',
///   child: Scaffold(...),
/// );
/// ```
///
/// 行为：
/// - 系统返回 / 手势返回被拦截，弹出确认框；
/// - 页面内显式的 `Navigator.pop(context)` 不受影响（主动退出仍即时生效）。
class SessionExitGuard extends StatelessWidget {
  final Widget child;

  /// 确认框中的主体名称，如「本次学习」「拼写练习」
  final String subject;

  const SessionExitGuard({super.key, required this.child, this.subject = '当前练习'});

  Future<bool> _confirmExit(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false, // 明确选择，避免误触
      builder: (ctx) => AlertDialog(
        title: Text('退出$subject？'),
        content: const Text('退出后本次进度将不会保存。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('继续学习')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('退出')),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final exit = await _confirmExit(context);
        if (exit && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: child,
    );
  }
}
