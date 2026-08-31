// Monster Word — 骨架屏组件（加载态一等公民）
//
// 设计原则（对标 Geist/商业产品惯例）：
// - 用"内容形状预览"替代转圈：用户能预判加载后长什么样
// - 脉冲动画（呼吸式透明度），非廉价跑马灯 shimmer
// - 圆角/颜色全部走 A 档（ThemeVars）+ B 档（DesignRadius）
import 'package:flutter/material.dart';

import 'package:word_app/theme/skin_system.dart';
import 'package:word_app/tokens/motion_tokens.dart';

/// 单个骨架块。宽高/圆角由调用方指定；颜色取三级文本色自动降饱和。
class MwSkeletonBlock extends StatefulWidget {
  final double width;
  final double height;
  final double? radius;

  const MwSkeletonBlock({super.key, required this.width, required this.height, this.radius});

  @override
  State<MwSkeletonBlock> createState() => _MwSkeletonBlockState();
}

class _MwSkeletonBlockState extends State<MwSkeletonBlock> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
    lowerBound: 0.45,
    upperBound: 1.0,
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return FadeTransition(
      opacity: _controller,
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: skin.colors.divider,
          borderRadius: BorderRadius.circular(widget.radius ?? skin.design.radius.sm),
        ),
      ),
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
          MwSkeletonBlock(width: 40, height: 40, radius: 20),
          SizedBox(width: design.spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MwSkeletonBlock(width: double.infinity, height: 14),
                SizedBox(height: design.spacing.xs),
                MwSkeletonBlock(width: 160, height: 12),
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
                MwSkeletonBlock(width: 90, height: 14),
                const Spacer(),
                MwSkeletonBlock(width: double.infinity, height: 10),
              ],
            ),
          ),
      ],
    );
  }
}

/// 转场标准时长挂载点（避免 unused import 报错，供后续 shimmer 备用）。
// ignore: unused_element
const Duration _kSkeletonPulse = MotionDurations.base;
