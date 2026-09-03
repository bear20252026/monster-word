// Monster Word — 全局前进/返回悬浮控件（桌面端）+ Alt+←/→ 快捷键（全平台）
//
// - 返回：优先走当前 Navigator 的真实 pop（页面实例与状态保留，多层级）；
//   栈底时回退到 NavigationHistoryService.mayGoBack 判定，避免黑屏。
// - 前进：NavigationHistoryService.goForward()（按快照重新 push）。
// - 仅桌面端（windows/macos/linux）渲染悬浮 pill；移动端依赖系统返回手势，
//   但快捷键与历史栈仍在（供后续接入）。
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:word_app/core/router/navigation_history.dart';
import 'package:word_app/theme/skin_system.dart';

class GlobalNavHistoryBar extends StatefulWidget {
  final NavigationHistoryService history;
  final Widget child;
  const GlobalNavHistoryBar({super.key, required this.history, required this.child});

  @override
  State<GlobalNavHistoryBar> createState() => _GlobalNavHistoryBarState();
}

class _GlobalNavHistoryBarState extends State<GlobalNavHistoryBar> {
  @override
  void initState() {
    super.initState();
    widget.history.addListener(_onChange);
  }

  @override
  void dispose() {
    widget.history.removeListener(_onChange);
    super.dispose();
  }

  bool _scheduled = false;

  void _onChange() {
    if (!mounted || _scheduled) return;
    _scheduled = true;
    // notifyListeners 可能在 build 阶段（初始路由 push）触发，
    // setState 必须延迟到帧末，否则 markNeedsBuild 冲突。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (mounted) setState(() {});
    });
  }

  bool get _isDesktop {
    if (kIsWeb) return false;
    return switch (defaultTargetPlatform) {
      TargetPlatform.windows || TargetPlatform.macOS || TargetPlatform.linux => true,
      _ => false,
    };
  }

  void _goBack() {
    final navigator = widget.history.navigatorKey.currentState;
    if (navigator != null && navigator.canPop()) {
      // 学习会话等受保护页面由 SessionExitGuard 拦截确认，这里只负责导航。
      navigator.pop();
    }
  }

  void _goForward() => widget.history.goForward();

  @override
  Widget build(BuildContext context) {
    Widget child = widget.child;
    if (_isDesktop) {
      // 桌面端：右下角悬浮 back/forward pill + 全局键盘快捷键
      child = CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.arrowLeft, alt: true): _goBack,
          const SingleActivator(LogicalKeyboardKey.arrowRight, alt: true): _goForward,
        },
        child: Focus(autofocus: true, skipTraversal: true, child: child),
      );
      child = Stack(
        children: [
          child,
          Positioned(right: 16, bottom: 16, child: _buildPill(context)),
        ],
      );
    }
    return child;
  }

  Widget _buildPill(BuildContext context) {
    final skin = context.skin;
    final navigator = widget.history.navigatorKey.currentState;
    final canBack = navigator?.canPop() ?? false;
    final canForward = widget.history.canGoForward;
    final colors = skin.colors;

    return AnimatedOpacity(
      opacity: (canBack || canForward) ? 1 : 0.25,
      duration: const Duration(milliseconds: 200),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            decoration: BoxDecoration(
              color: colors.cardBg.withValues(alpha: 0.82),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: colors.divider),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 3, offset: const Offset(0, 1)),
                BoxShadow(color: Colors.black.withValues(alpha: 0.10), blurRadius: 16, offset: const Offset(0, 6)),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _NavButton(
                  icon: Icons.arrow_back_ios_new_rounded,
                  tooltip: '返回 (Alt+←)',
                  enabled: canBack,
                  color: colors,
                  onTap: _goBack,
                ),
                const SizedBox(width: 2),
                _NavButton(
                  icon: Icons.arrow_forward_ios_rounded,
                  tooltip: '前进 (Alt+→)',
                  enabled: canForward,
                  color: colors,
                  onTap: _goForward,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool enabled;
  final VoidCallback onTap;
  final ThemeVars color;

  const _NavButton({
    required this.icon,
    required this.tooltip,
    required this.enabled,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    // 注意：本组件渲染于 MaterialApp.builder 层（Navigator/Overlay 之外）。
    // 此处任何依赖 Overlay 的组件（Tooltip/SnackBar/Popup…）都会抛
    // "No Overlay widget found"，且异常未被隔离时会全屏替换为错误页
    // （2026-08-31 用户实测：鼠标划过导航按钮即触发全屏"页面出错了"）。
    // 因此这里禁止使用 Tooltip，悬停提示改由 InkWell 无提示处理。
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Icon(icon, size: 16, color: enabled ? color.text1 : color.text3.withValues(alpha: 0.5)),
      ),
    );
  }
}
