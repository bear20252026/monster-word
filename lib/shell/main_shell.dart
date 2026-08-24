// 由账号4生成
// L4 主壳：三个一级 Tab（首页/词库/我的），透明悬浮底栏
// 翻译自 Figma MainShell.js
// 手机/平板同构，差异仅在图标尺寸和栏高（由 responsive 派生）

import 'package:flutter/material.dart';

import '../hooks/responsive.dart';
import '../theme/skin_system.dart';
import '../tokens/starbucks_tokens.dart';
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
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // Z2 内容：使用 IndexedStack 避免切换时白屏
          Positioned.fill(
            child: IndexedStack(
              index: _active,
              children: widget.tabs
                  .map((t) => t.builder(context))
                  .toList(),
            ),
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
        duration: const Duration(milliseconds: 300),
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

  // 星巴克底部导航栏配色（batch4a）
  static const Color _selectedColor = StarbucksCreamColors.greenHouse; // #006241 星巴克绿
  // 未选中色由 context.skin.colors.text3 动态获取（随主题切换）

  @override
  Widget build(BuildContext context) {
    final resp = context.responsive;
    final iconSize = resp.tabIconSize;
    final height = resp.tabBarHeight;
    final bottomPad = MediaQuery.paddingOf(context).bottom;
    final skin = context.skin;

    // 星巴克底栏：奶油画布实心 + 顶部发丝线（batch4a 线框图规格）
    return Container(
      height: height + bottomPad,
      padding: EdgeInsets.only(bottom: bottomPad > 0 ? bottomPad : 8),
      decoration: BoxDecoration(
        color: skin.colors.pageBg, // 奶油画布 #F2F0EB（亮）/ 墨绿 #101B17（暗）
        border: Border(top: BorderSide(color: skin.colors.divider, width: 0.5)),
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
                      color: on ? _selectedColor : skin.colors.text3,
                    ),
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
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
    );
  }
}
