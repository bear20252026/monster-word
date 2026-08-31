// 主壳：三个一级 Tab（首页/词库/我的），透明悬浮底栏
// 渲染自 Figma MainShell.js
// 手机/平板同构，差异仅在图标尺寸和栏高（由 responsive 生成）
import 'package:flutter/material.dart';

import 'package:word_app/tokens/starbucks_tokens.dart';
import 'package:word_app/widgets/app_dock.dart';

/// Tab 定义（原版 TABS）
class TabDef {
  final String id;
  final String label;
  final IconData icon;
  final Widget Function(BuildContext) builder;

  const TabDef({required this.id, required this.label, required this.icon, required this.builder});
}

/// 主壳（原版 MainShell）
class MainShell extends StatefulWidget {
  final List<TabDef> tabs;
  final int initialTab;

  const MainShell({super.key, required this.tabs, this.initialTab = 0});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late int _active;

  @override
  void initState() {
    super.initState();
    _active = widget.initialTab;
  }

  void switchTab(int index) {
    setState(() => _active = index);
  }

  /// 双击退出（体验审计 P1：学习途中误触返回直接退到桌面）
  DateTime? _lastBackPress;

  Future<bool> _onWillPop() async {
    final now = DateTime.now();
    if (_lastBackPress == null || now.difference(_lastBackPress!) > const Duration(seconds: 2)) {
      _lastBackPress = now;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('再按一次退出应用'), duration: Duration(milliseconds: 1500)));
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        body: Stack(
          children: [
            // Z2 内容：使用 IndexedStack 避免切换时白屏
            Positioned.fill(
              child: IndexedStack(index: _active, children: widget.tabs.map((t) => t.builder(context)).toList()),
            ),
            // Z3 底部 Dock 导航（macOS 风格浮动栏）
            Positioned(
              left: 0,
              right: 0,
              bottom: MediaQuery.of(context).padding.bottom,
              child: FloatingDock(
                items: widget.tabs.map((t) => DockItem(icon: t.icon, label: t.label)).toList(),
                currentIndex: _active,
                onTap: switchTab,
                activeColor: StarbucksCreamColors.greenHouse,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
