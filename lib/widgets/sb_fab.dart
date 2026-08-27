// Monster Word — 星巴克 Frap 悬浮按钮组件
// 规格来源：docs/component_spec.md §3（Frap 悬浮圆钮）
// 56px 圆形，CTA 绿 #00754A 底，白色图标，双层阴影，触控外扩 8px
// 按压反馈：包装 ScaleDownOnPress（scale 0.95 / 200ms easeOut）

import 'package:flutter/material.dart';

import 'scale_down_on_press.dart';

/// 星巴克 Frap 悬浮按钮
///
/// 规格（docs/component_spec.md §3）：
/// - 尺寸：56×56 圆形
/// - 填充：`#00754A` CTA 绿
/// - 图标：白色，默认 `Icons.play_arrow_rounded`
/// - 阴影：双层（基础光环 + 环境投影）
/// - 触控：视觉边缘外扩 8px
/// - 按压：scale(0.95) + 200ms easeOut（ScaleDownOnPress）
///
/// 扩展模式：传入 [label] 可展开为 Extended FAB（图标+文字横向排列）。
///
/// 用法：
/// ```dart
/// // 标准圆形
/// SbFab(onTap: () => startLearning())
///
/// // 自定义图标
/// SbFab(icon: Icons.add, onTap: () => add())
///
/// // Extended FAB（带文字）
/// SbFab(icon: Icons.play_arrow_rounded, label: '开始学习', onTap: () => start())
/// ```
class SbFab extends StatelessWidget {
  /// 点击回调。null 时禁用（不缩放不响应）。
  final VoidCallback? onTap;

  /// 图标，默认 `Icons.play_arrow_rounded`。
  final IconData icon;

  /// 可选文字标签。非 null 时展开为 Extended FAB。
  final String? label;

  /// 图标大小，默认 30。
  final double iconSize;

  /// 按钮尺寸（直径），默认 56。
  final double size;

  /// 填充色，默认 CTA 绿 `#00754A`。
  final Color fillColor;

  /// 图标/文字色，默认白色。
  final Color iconColor;

  const SbFab({
    super.key,
    required this.onTap,
    this.icon = Icons.play_arrow_rounded,
    this.label,
    this.iconSize = 30,
    this.size = 56,
    this.fillColor = const Color(0xFF00754A),
    this.iconColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasLabel = label != null && label!.isNotEmpty;

    // 内部按钮内容
    Widget buttonContent;
    if (hasLabel) {
      // Extended FAB：图标 + 文字横向排列
      buttonContent = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: iconSize, color: iconColor),
          const SizedBox(width: 8),
          Text(
            label!,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: iconColor, letterSpacing: -0.16),
          ),
        ],
      );
    } else {
      // 标准圆形：仅图标
      buttonContent = Icon(icon, size: iconSize, color: iconColor);
    }

    // 双层阴影（docs/component_spec.md §3）
    const shadows = <BoxShadow>[
      // 基础光环：0 0 6px rgba(0,0,0,.24)
      BoxShadow(blurRadius: 6, color: Color(0x3D000000)),
      // 环境投影：0 8px 12px rgba(0,0,0,.14)
      BoxShadow(offset: Offset(0, 8), blurRadius: 12, color: Color(0x24000000)),
    ];

    // 触控外扩 8px（docs/component_spec.md §3）
    return Padding(
      padding: const EdgeInsets.all(8),
      child: ScaleDownOnPress(
        onTap: onTap,
        behavior: HitTestBehavior.translucent,
        child: Container(
          width: hasLabel ? null : size,
          height: size,
          decoration: BoxDecoration(
            shape: hasLabel ? BoxShape.rectangle : BoxShape.circle,
            borderRadius: hasLabel ? BorderRadius.circular(size / 2) : null,
            boxShadow: shadows,
          ),
          child: Material(
            color: fillColor,
            shape: hasLabel
                ? RoundedRectangleBorder(borderRadius: BorderRadius.circular(size / 2))
                : const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: hasLabel ? 20 : 0, vertical: 0),
                child: Center(child: buttonContent),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
