// 由账号4生成
// L4 主壳：三个一级 Tab（首页/词库/我的），透明悬浮底栏
// 翻译自 Figma MainShell.js
// 手机/平板同构，差异仅在图标尺寸和栏高（由 responsive 派生）

import 'dart:ui';
import 'package:flutter/material.dart';

import '../hooks/responsive.dart';
import '../theme/skin_system.dart';
import '../widgets/animations.dart';

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
/// 带 AnimatedContainer 下划线动画 + 弹性点击反馈
/// 原版配色：选中 #E8913A（橙色），未选中 #999999（灰色）
class _TabBar extends StatefulWidget {
  final List<TabDef> tabs;
  final int active;
  final ValueChanged<int> onTap;

  const _TabBar({
    required this.tabs,
    required this.active,
    required this.onTap,
  });

  @override
  State<_TabBar> createState() => _TabBarState();
}

class _TabBarState extends State<_TabBar> with TickerProviderStateMixin {
  late final List<AnimationController> _bounceControllers;
  late final List<Animation<double>> _bounceAnims;

  @override
  void initState() {
    super.initState();
    _bounceControllers = List.generate(widget.tabs.length, (i) {
      return AnimationController(
        duration: const Duration(milliseconds: 350),
        vsync: this,
      );
    });
    _bounceAnims = _bounceControllers.map((c) {
      return TweenSequence<double>([
        TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.85), weight: 30),
        TweenSequenceItem(tween: Tween(begin: 0.85, end: 1.0), weight: 70),
      ]).animate(CurvedAnimation(parent: c, curve: SpringCurve()));
    }).toList();
  }

  @override
  void dispose() {
    for (final c in _bounceControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _onTap(int i) {
    _bounceControllers[i].forward(from: 0);
    widget.onTap(i);
  }

  // 原版底部导航栏配色（深色选中 + 灰色未选中）
  static const Color _selectedColor = Color(0xFF1F1F1F); // 选中深色
  static const Color _unselectedColor = Color(0xFF999999); // 未选中灰色

  @override
  Widget build(BuildContext context) {
    final resp = context.responsive;
    final iconSize = resp.tabIconSize;
    final height = resp.tabBarHeight;
    final bottomPad = MediaQuery.paddingOf(context).bottom;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          height: height + bottomPad,
          padding: EdgeInsets.only(bottom: bottomPad > 0 ? bottomPad : 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.6),
            border: Border(top: BorderSide(color: Colors.white.withOpacity(0.3), width: 0.5)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(widget.tabs.length, (i) {
              final on = i == widget.active;
              final t = widget.tabs[i];
              return Expanded(
                child: GestureDetector(
                  onTap: () => _onTap(i),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ScaleTransition(
                        scale: _bounceAnims[i],
                        child: Icon(
                          t.icon,
                          size: iconSize,
                          color: on ? _selectedColor : _unselectedColor,
                        ),
                      ),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        curve: standardCurve,
                        margin: const EdgeInsets.only(top: 4),
                        width: on ? 18 : 0,
                        height: 2,
                        decoration: BoxDecoration(
                          color: on ? _selectedColor : Colors.transparent,
                          borderRadius: BorderRadius.circular(1),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
