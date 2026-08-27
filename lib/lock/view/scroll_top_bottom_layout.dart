// 由 Claude 团队生成 | 移植自 v3.2 lock/view/ScrollTopBottomLayout.java
// 上下滚动布局 - 锁屏核心交互组件

import 'package:flutter/material.dart';

/// 顶部显示/隐藏回调
abstract class TopShowCallback {
  void onTopShow();
  void onTopHide();
  void onTouchUp(bool isTap);
}

/// 滚动变化监听
abstract class OnScrollChangeListener {
  void onScrollChanged(int scrollY);
}

/// 上下滚动布局
/// 支持上下两个区域的滚动切换，用于锁屏界面的"下拉查看例句"交互
class ScrollTopBottomLayout extends StatefulWidget {
  final double topHeight;
  final bool initialShowTop;
  final TopShowCallback? topShowCallback;
  final OnScrollChangeListener? scrollChangeListener;
  final Widget topChild;
  final Widget bottomChild;

  const ScrollTopBottomLayout({
    super.key,
    required this.topHeight,
    this.initialShowTop = true,
    this.topShowCallback,
    this.scrollChangeListener,
    required this.topChild,
    required this.bottomChild,
  });

  @override
  State<ScrollTopBottomLayout> createState() => _ScrollTopBottomLayoutState();
}

class _ScrollTopBottomLayoutState extends State<ScrollTopBottomLayout> with SingleTickerProviderStateMixin {
  late ScrollController _scrollController;
  bool _showTop = true;
  bool _isScrolling = false;
  double _startY = 0;
  double _startScrollY = 0;

  // 滑动阈值
  static const double _flingDistance = 80.0;
  static const double _minFlingVelocity = 400.0;

  @override
  void initState() {
    super.initState();
    _showTop = widget.initialShowTop;
    _scrollController = ScrollController(initialScrollOffset: _showTop ? 0 : widget.topHeight);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// 设置是否显示顶部
  void setShowTop(bool show) {
    if (show) {
      _scrollController.jumpTo(0);
      _showTop = true;
      widget.topShowCallback?.onTopShow();
      widget.scrollChangeListener?.onScrollChanged(0);
    } else {
      _scrollController.jumpTo(widget.topHeight);
      _showTop = false;
      widget.topShowCallback?.onTopHide();
      widget.scrollChangeListener?.onScrollChanged(widget.topHeight.toInt());
    }
  }

  /// 动画显示/隐藏顶部
  Future<void> animateShowTop(bool show) async {
    final target = show ? 0.0 : widget.topHeight;
    final distance = (target - _scrollController.offset).abs();
    final duration = Duration(milliseconds: (distance / 2000.0 * 1000).toInt().clamp(100, 500));

    if (show) {
      _showTop = true;
      widget.topShowCallback?.onTopShow();
    } else {
      _showTop = false;
      widget.topShowCallback?.onTopHide();
    }

    await _scrollController.animateTo(target, duration: duration, curve: Curves.decelerate);
  }

  bool get isShowTop => _showTop;
  double get topHeight => widget.topHeight;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onVerticalDragStart: _onDragStart,
      onVerticalDragUpdate: _onDragUpdate,
      onVerticalDragEnd: _onDragEnd,
      onTapUp: (_) {
        widget.topShowCallback?.onTouchUp(true);
      },
      child: SingleChildScrollView(
        controller: _scrollController,
        physics: const NeverScrollableScrollPhysics(),
        child: Column(
          children: [
            SizedBox(height: widget.topHeight, child: widget.topChild),
            widget.bottomChild,
          ],
        ),
      ),
    );
  }

  void _onDragStart(DragStartDetails details) {
    _startY = details.globalPosition.dy;
    _startScrollY = _scrollController.offset;
    _isScrolling = false;
  }

  void _onDragUpdate(DragUpdateDetails details) {
    final deltaY = details.globalPosition.dy - _startY;

    if (!_isScrolling && deltaY.abs() > 10) {
      _isScrolling = true;
    }

    if (_isScrolling) {
      final newOffset = (_startScrollY - deltaY).clamp(0.0, widget.topHeight);
      _scrollController.jumpTo(newOffset);
      widget.scrollChangeListener?.onScrollChanged(newOffset.toInt());
    }
  }

  void _onDragEnd(DragEndDetails details) {
    final deltaY = details.velocity.pixelsPerSecond.dy;
    final velocity = details.velocity.pixelsPerSecond.dy;

    bool showTop;
    if (velocity.abs() > _minFlingVelocity) {
      showTop = velocity > 0; // 向下滑显示顶部
    } else {
      if (_showTop) {
        showTop = -deltaY <= _flingDistance;
      } else {
        showTop = deltaY > _flingDistance;
      }
    }

    animateShowTop(showTop);
    widget.topShowCallback?.onTouchUp(!_isScrolling);
  }
}
