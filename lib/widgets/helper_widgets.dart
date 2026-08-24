// 由 Claude 团队生成 | Monster Word App

// 由 Claude 团队生成 | 移植自 v3.2 widget/LearnReviewHelper.java, LoadInfoHelper.java, OnScrollLoadMoreListener.java, TextViewUtils.java, SplashTransition.java, MySpaceTransition.java, UserInfoManageReturnFadeTransition.java, CustomeTypefaceSpan.java, Fling/ScrollStateListener.java, Fling/IScrollFling.java
// 辅助工具与混合组件集合
import 'package:flutter/material.dart';
import '../theme/skin_system.dart';
import '../tokens/design_tokens.dart';

// ─────────────────────────────────────────────────────────────
// ScrollLoadMore — 滚动加载更多监听（移植自 OnScrollLoadMoreListener.java）
// ─────────────────────────────────────────────────────────────
class ScrollLoadMore extends StatefulWidget {
  final Widget child;
  final VoidCallback? onLoadMore;
  final double threshold;
  final bool isLoading;
  final Widget? loadingWidget;

  const ScrollLoadMore({
    super.key,
    required this.child,
    this.onLoadMore,
    this.threshold = 200,
    this.isLoading = false,
    this.loadingWidget,
  });

  @override
  State<ScrollLoadMore> createState() => _ScrollLoadMoreState();
}

class _ScrollLoadMoreState extends State<ScrollLoadMore> {
  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollUpdateNotification &&
            notification.metrics.maxScrollExtent - notification.metrics.pixels <
                widget.threshold &&
            !widget.isLoading) {
          widget.onLoadMore?.call();
        }
        return false;
      },
      child: Column(
        children: [
          Expanded(child: widget.child),
          if (widget.isLoading)
            widget.loadingWidget ??
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// ScrollStateNotifier — 滚动状态通知（移植自 Fling/ScrollStateListener.java）
// ─────────────────────────────────────────────────────────────
typedef ScrollStateCallback = void Function(ScrollState state);

enum ScrollState { idle, dragging, fling, settling }

class ScrollStateNotifier extends StatefulWidget {
  final Widget child;
  final ScrollStateCallback? onStateChanged;

  const ScrollStateNotifier({
    super.key,
    required this.child,
    this.onStateChanged,
  });

  @override
  State<ScrollStateNotifier> createState() => _ScrollStateNotifierState();
}

class _ScrollStateNotifierState extends State<ScrollStateNotifier> {
  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollStartNotification) {
          widget.onStateChanged?.call(
            notification.dragDetails != null
                ? ScrollState.dragging
                : ScrollState.settling,
          );
        } else if (notification is ScrollEndNotification) {
          widget.onStateChanged?.call(ScrollState.idle);
        }
        return false;
      },
      child: widget.child,
    );
  }
}

// ─────────────────────────────────────────────────────────────
// NoDataGuide — 无数据引导（移植自 component/NoDataGuideView.java）
// ─────────────────────────────────────────────────────────────
class NoDataGuide extends StatelessWidget {
  final String message;
  final IconData icon;
  final String? actionText;
  final VoidCallback? onAction;

  const NoDataGuide({
    super.key,
    this.message = '暂无数据',
    this.icon = Icons.inbox_outlined,
    this.actionText,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: skin.colors.text3.withAlpha(80)),
            const SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(fontSize: 16, color: skin.colors.text3),
              textAlign: TextAlign.center,
            ),
            if (actionText != null) ...[
              const SizedBox(height: 16),
              TextButton(
                onPressed: onAction,
                child: Text(actionText!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// TipLabel — 动态提示标签（移植自 widget/TipLabelDynamicView.java）
// ─────────────────────────────────────────────────────────────
class TipLabel extends StatelessWidget {
  final String text;
  final Color? backgroundColor;
  final Color? textColor;
  final double fontSize;
  final EdgeInsetsGeometry padding;
  final double borderRadius;

  const TipLabel({
    super.key,
    required this.text,
    this.backgroundColor,
    this.textColor,
    this.fontSize = 12,
    this.padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    this.borderRadius = 4,
  });

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor ?? skin.colors.accent.withAlpha(20),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: fontSize,
          color: textColor ?? skin.colors.accent,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// LableClassify — 标签分类视图（移植自 widget/LableClassifyView.java）
// ─────────────────────────────────────────────────────────────
class LableClassify extends StatelessWidget {
  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int>? onSelected;
  final double spacing;
  final double runSpacing;

  const LableClassify({
    super.key,
    required this.labels,
    this.selectedIndex = -1,
    this.onSelected,
    this.spacing = 8,
    this.runSpacing = 8,
  });

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Wrap(
      spacing: spacing,
      runSpacing: runSpacing,
      children: List.generate(labels.length, (i) {
        final isSelected = i == selectedIndex;
        return GestureDetector(
          onTap: () => onSelected?.call(i),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isSelected ? skin.colors.accent : skin.colors.cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? skin.colors.accent : skin.colors.divider,
              ),
            ),
            child: Text(
              labels[i],
              style: TextStyle(
                fontSize: 14,
                color: isSelected ? Colors.white : skin.colors.text2,
              ),
            ),
          ),
        );
      }),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// LableCard — 标签卡片（移植自 component/LableCardStyle1View.java, LableCardStyle2View.java, LableCardSytle3View.java）
// ─────────────────────────────────────────────────────────────
enum LableCardStyle { style1, style2, style3 }

class LableCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? value;
  final LableCardStyle style;
  final VoidCallback? onTap;

  const LableCard({
    super.key,
    required this.title,
    this.subtitle,
    this.value,
    this.style = LableCardStyle.style1,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: skin.colors.cardBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: skin.colors.divider),
        ),
        child: style == LableCardStyle.style1
            ? _buildStyle1(skin)
            : style == LableCardStyle.style2
                ? _buildStyle2(skin)
                : _buildStyle3(skin),
      ),
    );
  }

  Widget _buildStyle1(dynamic skin) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: skin.colors.text1)),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(subtitle!,
              style: TextStyle(fontSize: 12, color: skin.colors.text3)),
        ],
      ],
    );
  }

  Widget _buildStyle2(dynamic skin) {
    return Row(
      children: [
        Expanded(
          child: Text(title,
              style: TextStyle(fontSize: 14, color: skin.colors.text1)),
        ),
        if (value != null)
          Text(value!,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: skin.colors.accent)),
      ],
    );
  }

  Widget _buildStyle3(dynamic skin) {
    return Column(
      children: [
        if (value != null)
          Text(value!,
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: skin.colors.accent)),
        const SizedBox(height: 4),
        Text(title,
            style: TextStyle(fontSize: 13, color: skin.colors.text2)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// LearnStatusTag — 学习状态标签（移植自 component/LearnStatusLable.java）
// ─────────────────────────────────────────────────────────────
enum LearnStatus { newWord, learning, reviewing, mastered }

class LearnStatusTag extends StatelessWidget {
  final LearnStatus status;

  const LearnStatusTag({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    Color color;
    String text;
    switch (status) {
      case LearnStatus.newWord:
        color = Colors.blue;
        text = '新词';
        break;
      case LearnStatus.learning:
        color = skin.colors.accent;
        text = '学习中';
        break;
      case LearnStatus.reviewing:
        color = Colors.orange;
        text = '复习中';
        break;
      case LearnStatus.mastered:
        color = Colors.green;
        text = '已掌握';
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// LearnReviewBand — 学习复习条带（移植自 component/LearnReviewBand.java）
// ─────────────────────────────────────────────────────────────
class LearnReviewBand extends StatelessWidget {
  final int learnCount;
  final int reviewCount;
  final VoidCallback? onLearnTap;
  final VoidCallback? onReviewTap;

  const LearnReviewBand({
    super.key,
    required this.learnCount,
    required this.reviewCount,
    this.onLearnTap,
    this.onReviewTap,
  });

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: onLearnTap,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: skin.colors.accent.withAlpha(20),
                borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(8)),
              ),
              child: Column(
                children: [
                  Text('$learnCount',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: skin.colors.accent)),
                  const SizedBox(height: 2),
                  Text('待学习',
                      style: TextStyle(
                          fontSize: 12, color: skin.colors.text3)),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: GestureDetector(
            onTap: onReviewTap,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.orange.withAlpha(20),
                borderRadius: const BorderRadius.horizontal(
                    right: Radius.circular(8)),
              ),
              child: Column(
                children: [
                  Text('$reviewCount',
                      style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange)),
                  const SizedBox(height: 2),
                  Text('待复习',
                      style: TextStyle(
                          fontSize: 12, color: skin.colors.text3)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// CustomSelected — 自定义选中视图（移植自 widget/CustomSelectedView.java）
// ─────────────────────────────────────────────────────────────
class CustomSelected extends StatelessWidget {
  final Widget child;
  final bool selected;
  final VoidCallback? onTap;
  final Color? selectedColor;
  final double borderRadius;

  const CustomSelected({
    super.key,
    required this.child,
    this.selected = false,
    this.onTap,
    this.selectedColor,
    this.borderRadius = 8,
  });

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: selected
              ? (selectedColor ?? skin.colors.accent).withAlpha(20)
              : null,
          borderRadius: BorderRadius.circular(borderRadius),
          border: selected
              ? Border.all(
                  color: selectedColor ?? skin.colors.accent, width: 1.5)
              : null,
        ),
        child: child,
      ),
    );
  }
}
