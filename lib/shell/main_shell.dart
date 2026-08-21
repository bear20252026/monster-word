// 由账号4生成
// L4 主壳：三个一级 Tab（首页/词库/我的），透明悬浮底栏
// 翻译自 Figma MainShell.js
// 手机/平板同构，差异仅在图标尺寸和栏高（由 responsive 派生）

import 'package:flutter/material.dart';

import '../hooks/responsive.dart';
import '../widgets/glass_widgets.dart';

/// Tab 定义（原版 TABS）
class TabDef {
  final String id;
  final String label;
  final IconData icon;
  final Widget Function(BuildContext) builder;

  const TabDef({
    required this.id,
    required this.label,
    required this.icon,
    required this.builder,
  });
}

/// 主壳（原版 MainShell）
class MainShell extends StatefulWidget {
  final List<TabDef> tabs;
  final int initialTab;

  const MainShell({
    super.key,
    required this.tabs,
    this.initialTab = 0,
  });

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

  @override
  Widget build(BuildContext context) {
    final current = widget.tabs[_active];

    return Scaffold(
      body: Stack(
        children: [
          // Z2 内容：全屏铺满，Tab 栏悬浮其上
          Positioned.fill(
            child: current.builder(context),
          ),
          // Z3 底部 Tab 栏（透明，仅图标）
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _TabBar(
              tabs: widget.tabs,
              active: _active,
              onTap: switchTab,
            ),
          ),
        ],
      ),
    );
  }
}

/// 底部 Tab 栏（原版 TabBar 组件）
/// 透明悬浮、仅图标、手机/平板同构
class _TabBar extends StatelessWidget {
  final List<TabDef> tabs;
  final int active;
  final ValueChanged<int> onTap;

  const _TabBar({
    required this.tabs,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final resp = context.responsive;
    final iconSize = resp.tabIconSize;
    final height = resp.tabBarHeight;
    final bottomPad = MediaQuery.paddingOf(context).bottom;

    return Container(
      height: height + bottomPad,
      padding: EdgeInsets.only(bottom: bottomPad > 0 ? bottomPad : 8),
      // 半透明背景，确保图标可见
      decoration: BoxDecoration(
        color: skin.colors.pageBg.withValues(alpha: 0.85),
        border: Border(top: BorderSide(color: skin.colors.divider, width: 0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(tabs.length, (i) {
          final on = i == active;
          final t = tabs[i];
          return Expanded(
            child: GestureDetector(
              onTap: () => onTap(i),
              behavior: HitTestBehavior.opaque,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    t.icon,
                    size: iconSize,
                    color: on
                        ? skin.colors.accent
                        : skin.colors.tabBarIcon.withValues(alpha: 0.82),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}
