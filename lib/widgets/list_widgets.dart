// 由 Claude 团队生成 | Monster Word App

// 由 Claude 团队生成 | 移植自 v3.2 widget/MyExpandleListView.java, SubListView.java, MyViewPager.java, InfiniteViewPager.java, InfinitePagerAdapter.java
// 列表与翻页组件集合
import 'package:flutter/material.dart';

import '../theme/skin_system.dart';
import 'animations.dart';

// ─────────────────────────────────────────────────────────────
// ExpandableList — 可展开列表（移植自 MyExpandleListView.java）
// ─────────────────────────────────────────────────────────────
class ExpandableList<T> extends StatelessWidget {
  final List<ExpandableGroup<T>> groups;
  final Widget Function(T item) itemBuilder;
  final Widget Function(ExpandableGroup<T> group, bool expanded)? headerBuilder;
  final bool initiallyExpanded;

  const ExpandableList({
    super.key,
    required this.groups,
    required this.itemBuilder,
    this.headerBuilder,
    this.initiallyExpanded = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: groups.length,
      itemBuilder: (context, index) {
        return _ExpandableGroupWidget(
          group: groups[index],
          itemBuilder: itemBuilder,
          headerBuilder: headerBuilder,
          initiallyExpanded: initiallyExpanded,
        );
      },
    );
  }
}

class ExpandableGroup<T> {
  final String title;
  final List<T> items;
  final dynamic data;

  const ExpandableGroup({required this.title, required this.items, this.data});
}

class _ExpandableGroupWidget<T> extends StatefulWidget {
  final ExpandableGroup<T> group;
  final Widget Function(T item) itemBuilder;
  final Widget Function(ExpandableGroup<T> group, bool expanded)? headerBuilder;
  final bool initiallyExpanded;

  const _ExpandableGroupWidget({
    required this.group,
    required this.itemBuilder,
    this.headerBuilder,
    this.initiallyExpanded = false,
  });

  @override
  State<_ExpandableGroupWidget<T>> createState() => _ExpandableGroupWidgetState<T>();
}

class _ExpandableGroupWidgetState<T> extends State<_ExpandableGroupWidget<T>> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          child:
              widget.headerBuilder?.call(widget.group, _expanded) ??
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: skin.colors.divider, width: 0.5)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.group.title,
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: skin.colors.text1),
                      ),
                    ),
                    Icon(_expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: skin.colors.text3),
                  ],
                ),
              ),
        ),
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 200),
          crossFadeState: _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          firstChild: const SizedBox.shrink(),
          secondChild: Column(children: widget.group.items.map((item) => widget.itemBuilder(item)).toList()),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// SubList — 子列表（移植自 SubListView.java）
// ─────────────────────────────────────────────────────────────
class SubList<T> extends StatelessWidget {
  final List<T> items;
  final Widget Function(BuildContext, T, int) itemBuilder;
  final ScrollPhysics? physics;
  final EdgeInsetsGeometry? padding;
  final bool shrinkWrap;

  const SubList({
    super.key,
    required this.items,
    required this.itemBuilder,
    this.physics,
    this.padding,
    this.shrinkWrap = true,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: items.length,
      physics: physics ?? const NeverScrollableScrollPhysics(),
      padding: padding,
      shrinkWrap: shrinkWrap,
      itemBuilder: (context, index) => itemBuilder(context, items[index], index),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// InfinitePageView — 无限循环翻页（移植自 InfiniteViewPager.java + InfinitePagerAdapter.java）
// ─────────────────────────────────────────────────────────────
class InfinitePageView extends StatefulWidget {
  final int itemCount;
  final Widget Function(BuildContext, int) itemBuilder;
  final ValueChanged<int>? onPageChanged;
  final PageController? controller;
  final bool autoPlay;
  final Duration autoPlayInterval;
  final Axis scrollDirection;

  const InfinitePageView({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.onPageChanged,
    this.controller,
    this.autoPlay = false,
    this.autoPlayInterval = const Duration(seconds: 3),
    this.scrollDirection = Axis.horizontal,
  });

  @override
  State<InfinitePageView> createState() => _InfinitePageViewState();
}

class _InfinitePageViewState extends State<InfinitePageView> {
  late PageController _controller;
  late int _virtualIndex;
  static const int _kMiddle = 10000;

  @override
  void initState() {
    super.initState();
    _virtualIndex = _kMiddle;
    _controller = widget.controller ?? PageController(initialPage: _virtualIndex);
    if (widget.autoPlay) {
      _startAutoPlay();
    }
  }

  void _startAutoPlay() {
    Future.delayed(widget.autoPlayInterval, () {
      if (!mounted) return;
      _virtualIndex++;
      _controller.animateToPage(_virtualIndex, duration: const Duration(milliseconds: 300), curve: standardCurve);
      _startAutoPlay();
    });
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.itemCount == 0) return const SizedBox.shrink();
    return PageView.builder(
      controller: _controller,
      scrollDirection: widget.scrollDirection,
      onPageChanged: (virtualIndex) {
        _virtualIndex = virtualIndex;
        final realIndex = virtualIndex % widget.itemCount;
        widget.onPageChanged?.call(realIndex);
      },
      itemBuilder: (context, virtualIndex) {
        final realIndex = virtualIndex % widget.itemCount;
        return widget.itemBuilder(context, realIndex);
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────
// CustomPageView — 自定义翻页（移植自 MyViewPager.java / ViewPagerFixed.java）
// ─────────────────────────────────────────────────────────────
class CustomPageView extends StatelessWidget {
  final int itemCount;
  final Widget Function(BuildContext, int) itemBuilder;
  final ValueChanged<int>? onPageChanged;
  final PageController? controller;
  final bool pageSnapping;
  final double viewportFraction;
  final Axis scrollDirection;

  const CustomPageView({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.onPageChanged,
    this.controller,
    this.pageSnapping = true,
    this.viewportFraction = 1.0,
    this.scrollDirection = Axis.horizontal,
  });

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      itemCount: itemCount,
      controller: controller ?? PageController(viewportFraction: viewportFraction),
      onPageChanged: onPageChanged,
      pageSnapping: pageSnapping,
      scrollDirection: scrollDirection,
      itemBuilder: itemBuilder,
    );
  }
}

// ─────────────────────────────────────────────────────────────
// FullWidthHorizontalList — 全宽水平列表（移植自 component/FullHorzontalRecyclerView.java）
// ─────────────────────────────────────────────────────────────
class FullWidthHorizontalList<T> extends StatelessWidget {
  final List<T> items;
  final Widget Function(BuildContext, T, int) itemBuilder;
  final double height;
  final EdgeInsetsGeometry? padding;
  final double spacing;

  const FullWidthHorizontalList({
    super.key,
    required this.items,
    required this.itemBuilder,
    this.height = 120,
    this.padding,
    this.spacing = 12,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: padding ?? const EdgeInsets.symmetric(horizontal: 16),
        itemCount: items.length,
        separatorBuilder: (_, _) => SizedBox(width: spacing),
        itemBuilder: (context, index) => itemBuilder(context, items[index], index),
      ),
    );
  }
}
