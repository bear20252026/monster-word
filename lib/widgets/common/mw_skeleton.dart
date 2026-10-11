// Monster Word — 骨架屏组件（加载态一等公民）
//
// 设计原则（对标 Geist/商业产品惯例）：
// - 用"内容形状预览"替代转圈：用户能预判加载后长什么样
// - 脉冲动画（呼吸式透明度），非廉价跑马灯 shimmer
// - 圆角/颜色全部走 A 档（ThemeVars）+ B 档（DesignRadius）
// - 全部块共享一只帧时钟（2026-10-08 性能审计：一页 10+ 块各建
//   repeat(reverse) 控制器即 10+ 常驻 ticker；现在无论多少块只有一帧回调）
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'package:word_app/theme/skin_system.dart';

/// 骨架脉冲共享时钟：单个帧回调驱动所有骨架块，监听数归零即停。
class _PulseClock extends ChangeNotifier {
  _PulseClock._();

  static final _PulseClock instance = _PulseClock._();

  static const Duration _period = Duration(milliseconds: 900);
  static const double _minOpacity = 0.45;

  double _value = 1.0;
  int _listeners = 0;
  bool _scheduled = false;
  DateTime? _start;

  double get value => _value;

  @override
  void addListener(VoidCallback listener) {
    super.addListener(listener);
    _listeners++;
    _ensureTicking();
  }

  @override
  void removeListener(VoidCallback listener) {
    super.removeListener(listener);
    _listeners--;
    if (_listeners <= 0) {
      _listeners = 0;
      _start = null;
    }
  }

  void _ensureTicking() {
    if (_scheduled) return;
    _scheduled = true;
    _tick();
  }

  void _tick() {
    if (_listeners == 0) {
      _scheduled = false;
      return;
    }
    final now = DateTime.now();
    _start ??= now;
    final t = (now.difference(_start!).inMicroseconds % _period.inMicroseconds) / _period.inMicroseconds;
    // 三角波：0.45 → 1 → 0.45（呼吸感），与旧 repeat(reverse) 视觉等价。
    final phase = t < 0.5 ? t * 2 : (1 - t) * 2;
    _value = _minOpacity + (1 - _minOpacity) * phase;
    notifyListeners();
    SchedulerBinding.instance.scheduleFrameCallback((_) => _tick());
  }
}

/// 单个骨架块。宽高/圆角由调用方指定；颜色取三级文本色自动降饱和。
class MwSkeletonBlock extends StatelessWidget {
  final double width;
  final double height;
  final double? radius;

  const MwSkeletonBlock({super.key, required this.width, required this.height, this.radius});

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    // reduce-motion：静态半透明呈现（不注册帧时钟）。
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final block = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: skin.colors.divider,
        borderRadius: BorderRadius.circular(radius ?? skin.design.radius.sm),
      ),
    );
    if (reduceMotion) return block;
    return AnimatedBuilder(
      animation: _PulseClock.instance,
      builder: (context, child) => Opacity(opacity: _PulseClock.instance.value, child: child),
      child: block,
    );
  }
}

/// 列表行骨架（头像 + 两行文字）——学习列表/词表页通用。
class MwSkeletonListItem extends StatelessWidget {
  const MwSkeletonListItem({super.key});

  @override
  Widget build(BuildContext context) {
    final design = context.design;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: design.spacing.page, vertical: design.spacing.sm),
      child: Row(
        children: [
          const MwSkeletonBlock(width: 40, height: 40, radius: 20),
          SizedBox(width: design.spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const MwSkeletonBlock(width: double.infinity, height: 14),
                SizedBox(height: design.spacing.xs),
                const MwSkeletonBlock(width: 160, height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 页面级骨架：标题 + 三个列表行（最常用的首屏加载形态）。
class MwSkeletonPage extends StatelessWidget {
  final int rows;
  const MwSkeletonPage({super.key, this.rows = 4});

  @override
  Widget build(BuildContext context) {
    final design = context.design;
    return Padding(
      padding: EdgeInsets.all(design.spacing.page),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MwSkeletonBlock(width: 180, height: 24, radius: design.radius.sm),
          SizedBox(height: design.spacing.lg),
          for (int i = 0; i < rows; i++) ...[const MwSkeletonListItem(), SizedBox(height: design.spacing.sm)],
        ],
      ),
    );
  }
}

/// 卡片网格骨架（首页/词书网格用）。
class MwSkeletonGrid extends StatelessWidget {
  final int count;
  const MwSkeletonGrid({super.key, this.count = 6});

  @override
  Widget build(BuildContext context) {
    final design = context.design;
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: design.spacing.md,
      crossAxisSpacing: design.spacing.md,
      childAspectRatio: 2.4,
      children: [
        for (int i = 0; i < count; i++)
          Container(
            padding: EdgeInsets.all(design.spacing.md),
            decoration: BoxDecoration(
              color: context.skin.colors.cardBg,
              borderRadius: BorderRadius.circular(design.radius.card),
              border: Border.all(color: context.skin.colors.divider),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const MwSkeletonBlock(width: 90, height: 14),
                const Spacer(),
                const MwSkeletonBlock(width: double.infinity, height: 10),
              ],
            ),
          ),
      ],
    );
  }
}
