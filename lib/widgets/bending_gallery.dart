// Bending Gallery：弯曲画廊效果
// 3D 透视 + 鼠标/触摸交互弯曲 + 缩放效果
// 颜色/曲率/间距均可自定义
// 适用于：词书选择页、成就徽章展示、功能入口展示
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../tokens/design_tokens.dart';

class BendingGalleryItem {
  final Widget child;
  final String? label;
  final VoidCallback? onTap;
  final Color? color;

  const BendingGalleryItem({required this.child, this.label, this.onTap, this.color});
}

class BendingGallery extends StatefulWidget {
  final List<BendingGalleryItem> items;
  final double height;
  final double itemWidth;
  final double spacing;
  final double curvature; // 弯曲程度 (0 = 平面, 1 = 最大弯曲)
  final bool enableInteraction; // 是否启用交互弯曲
  final Duration animDuration;
  final Color? activeColor;

  const BendingGallery({
    super.key,
    required this.items,
    this.height = 160,
    this.itemWidth = 100,
    this.spacing = 8,
    this.curvature = 0.3,
    this.enableInteraction = true,
    this.animDuration = const Duration(milliseconds: 300),
    this.activeColor,
  });

  @override
  State<BendingGallery> createState() => _BendingGalleryState();
}

class _BendingGalleryState extends State<BendingGallery> {
  double _pointerX = 0.5; // 指针位置 (0-1)
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onHover: widget.enableInteraction
          ? (event) {
              setState(() {
                _pointerX = (event.localPosition.dx / (widget.items.length * (widget.itemWidth + widget.spacing)))
                    .clamp(0.0, 1.0);
                _isHovering = true;
              });
            }
          : null,
      onExit: (_) {
        setState(() => _isHovering = false);
      },
      child: SizedBox(
        height: widget.height,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(widget.items.length, (i) {
                final item = widget.items[i];
                // 计算每个 item 的弯曲偏移
                final itemCenter = (i + 0.5) / widget.items.length;
                final distFromPointer = (itemCenter - _pointerX).abs();
                final bendOffset = _isHovering ? math.sin(distFromPointer * math.pi) * widget.curvature * -30 : 0.0;
                final scale = _isHovering ? 1.0 + (1 - distFromPointer) * 0.15 : 1.0;

                return AnimatedContainer(
                  duration: widget.animDuration,
                  curve: Curves.easeOutCubic,
                  transform: Matrix4.identity()
                    ..translate(0.0, bendOffset)
                    ..scale(scale),
                  child: GestureDetector(onTap: item.onTap, child: _buildItem(item, i)),
                );
              }),
            );
          },
        ),
      ),
    );
  }

  Widget _buildItem(BendingGalleryItem item, int index) {
    return Container(
      width: widget.itemWidth,
      margin: EdgeInsets.symmetric(horizontal: widget.spacing / 2),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            height: widget.height * 0.7,
            decoration: BoxDecoration(
              color: item.color ?? widget.activeColor ?? const Color(0xFF006241),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: (item.color ?? MistralColors.ink).withValues(alpha: 0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(child: item.child),
          ),
          if (item.label != null) ...[
            const SizedBox(height: 6),
            Text(
              item.label!,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ],
        ],
      ),
    );
  }
}

/// 3D 透视弯曲画廊（更强烈的 3D 效果）
class PerspectiveGallery extends StatefulWidget {
  final List<BendingGalleryItem> items;
  final double height;
  final double itemWidth;
  final Function(int)? onSelected;

  const PerspectiveGallery({super.key, required this.items, this.height = 180, this.itemWidth = 120, this.onSelected});

  @override
  State<PerspectiveGallery> createState() => _PerspectiveGalleryState();
}

class _PerspectiveGalleryState extends State<PerspectiveGallery> {
  int _selectedIndex = -1;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(widget.items.length, (i) {
          final isSelected = i == _selectedIndex;
          final distFromCenter = (i - widget.items.length / 2).abs();
          final maxDist = widget.items.length / 2;
          final normalizedDist = distFromCenter / maxDist;

          return GestureDetector(
            onTap: () {
              setState(() => _selectedIndex = i);
              widget.onSelected?.call(i);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutBack,
              transform: Matrix4.identity()
                ..rotateY((i - widget.items.length / 2) * 0.15)
                ..translate(0.0, isSelected ? -15.0 : normalizedDist * 20)
                ..scale(isSelected ? 1.1 : (1.0 - normalizedDist * 0.2)),
              child: Container(
                width: widget.itemWidth,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: widget.items[i].color ?? const Color(0xFF006241),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: MistralColors.black15,
                      blurRadius: isSelected ? 16 : 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(child: widget.items[i].child),
              ),
            ),
          );
        }),
      ),
    );
  }
}
