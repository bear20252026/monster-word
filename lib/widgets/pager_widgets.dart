// 由 Claude 团队生成 | Monster Word App

// 由账号4生成
// 翻页控件：翻译自 widget/ 中的翻页类
// 文件：InfinitePagerAdapter, InfiniteViewPager, ViewPagerFixed, MyViewPager, PageNumView

import 'package:flutter/material.dart';
import 'animations.dart';

/// 无限循环翻页视图（翻译自 InfiniteViewPager + InfinitePagerAdapter.dart）
/// 支持自动循环的 PageView
class InfinitePageView extends StatefulWidget {
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final ValueChanged<int>? onPageChanged;
  final bool autoPlay;
  final Duration autoPlayInterval;
  final Duration autoPlayAnimationDuration;
  final ScrollPhysics? physics;
  final Axis scrollDirection;
  final bool enableInfiniteScroll;

  const InfinitePageView({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.onPageChanged,
    this.autoPlay = false,
    this.autoPlayInterval = const Duration(seconds: 3),
    this.autoPlayAnimationDuration = const Duration(milliseconds: 800),
    this.physics,
    this.scrollDirection = Axis.horizontal,
    this.enableInfiniteScroll = true,
  });

  @override
  State<InfinitePageView> createState() => _InfinitePageViewState();
}

class _InfinitePageViewState extends State<InfinitePageView> {
  late PageController _controller;
  bool _isAutoPlaying = false;

  @override
  void initState() {
    super.initState();
    final initialPage =
        widget.enableInfiniteScroll ? widget.itemCount * 500 : 0;
    _controller = PageController(initialPage: initialPage);
    if (widget.autoPlay) {
      _startAutoPlay();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _isAutoPlaying = false;
    super.dispose();
  }

  void _startAutoPlay() {
    _isAutoPlaying = true;
    Future.doWhile(() async {
      await Future.delayed(widget.autoPlayInterval);
      if (!_isAutoPlaying || !mounted) return false;
      if (_controller.hasClients) {
        final nextPage = _controller.page!.toInt() + 1;
        _controller.animateToPage(
          nextPage,
          duration: widget.autoPlayAnimationDuration,
          curve: standardCurve,
        );
      }
      return _isAutoPlaying;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.itemCount == 0) return const SizedBox.shrink();
    return PageView.builder(
      controller: _controller,
      scrollDirection: widget.scrollDirection,
      physics: widget.physics ?? const BouncingScrollPhysics(),
      onPageChanged: (index) {
        final realIndex = index % widget.itemCount;
        widget.onPageChanged?.call(realIndex);
      },
      itemBuilder: (context, index) {
        final realIndex = index % widget.itemCount;
        return widget.itemBuilder(context, realIndex);
      },
    );
  }
}

/// 可控制触摸的 PageView（翻译自 MyViewPager.dart）
/// 支持动态启用/禁用滑动
class ControlledPageView extends StatefulWidget {
  final List<Widget> children;
  final PageController? controller;
  final ValueChanged<int>? onPageChanged;
  final bool enableTouch;
  final ScrollPhysics? physics;

  const ControlledPageView({
    super.key,
    required this.children,
    this.controller,
    this.onPageChanged,
    this.enableTouch = true,
    this.physics,
  });

  @override
  State<ControlledPageView> createState() => _ControlledPageViewState();
}

class _ControlledPageViewState extends State<ControlledPageView> {
  late PageController _controller;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? PageController();
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
    return PageView(
      controller: _controller,
      onPageChanged: widget.onPageChanged,
      physics: widget.enableTouch
          ? (widget.physics ?? const BouncingScrollPhysics())
          : const NeverScrollableScrollPhysics(),
      children: widget.children,
    );
  }
}

/// 固定翻页视图（翻译自 ViewPagerFixed.dart）
/// 基础的 PageView，无特殊处理
class FixedPageView extends StatelessWidget {
  final List<Widget> children;
  final PageController? controller;
  final ValueChanged<int>? onPageChanged;
  final Axis scrollDirection;

  const FixedPageView({
    super.key,
    required this.children,
    this.controller,
    this.onPageChanged,
    this.scrollDirection = Axis.horizontal,
  });

  @override
  Widget build(BuildContext context) {
    return PageView(
      controller: controller,
      onPageChanged: onPageChanged,
      scrollDirection: scrollDirection,
      children: children,
    );
  }
}
