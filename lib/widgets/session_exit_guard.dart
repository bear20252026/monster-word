// 会话退出保护：拦截系统返回键/手势返回，防止误触丢失学习进度
import 'package:flutter/material.dart';

import 'package:word_app/core/router/nav_utils.dart';

/// 学习类页面的返回保护（智能拦截）。
///
/// 用法：将页面的 Scaffold 用 [SessionExitGuard] 包裹：
/// ```dart
/// return SessionExitGuard(
///   subject: '本次学习',
///   child: Scaffold(...),
///   shouldIntercept: () => state.hasProgress, // 仅在有进度时拦截
/// );
/// ```
///
/// 智能拦截逻辑：
/// - [shouldIntercept] 返回 false（无进度/已完成）→ 直接安全退出，不弹确认
/// - [shouldIntercept] 返回 true（进行中/有未保存进度）→ 弹确认对话框
/// - [shouldIntercept] 为 null → 始终拦截（向后兼容）
/// - 页面内显式的 `Navigator.pop(context)` 不受影响（主动退出仍即时生效）。
class SessionExitGuard extends StatelessWidget {
  final Widget child;

  /// 确认框中的主体名称，如「本次学习」「拼写练习」
  final String subject;

  /// 返回 true 表示有未保存进度需要拦截退出；false 表示可直接退出。
  /// 为 null 时保持旧行为（始终拦截）。
  final bool Function()? shouldIntercept;

  const SessionExitGuard({
    super.key,
    required this.child,
    this.subject = '当前练习',
    this.shouldIntercept,
  });

  Future<bool> _confirmExit(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false, // 明确选择，避免误触
      builder: (ctx) => AlertDialog(
        title: Text('退出$subject？'),
        content: const Text('学习进度将保存到下次，确定要暂停吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('继续学习')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('暂停并保存')),
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
        // 智能判断：无进度时直接退出，不打扰用户
        if (shouldIntercept != null && !shouldIntercept!()) {
          if (context.mounted) {
            NavUtils.safePop(context);
          }
          return;
        }
        // 有进度 → 弹确认对话框
        final exit = await _confirmExit(context);
        if (exit && context.mounted) {
          NavUtils.safePop(context);
        }
      },
      child: child,
    );
  }
}
