// Monster Word — 星巴克金色胶囊徽章
// 来源规格：docs/component_spec.md §5（GoldPillBadge）
// 使用纪律：金色仅限成就/星标/奖励场景，禁止作通用强调色

import 'package:flutter/material.dart';
import '../theme/skin_system.dart';
import 'scale_down_on_press.dart';

/// 星巴克金色胶囊徽章
///
/// 用于星标单词数、成就徽章、奖励标识等场景。
/// 白底/透明底 + 金色描边 + 金色文字，可选前缀图标。
///
/// 使用纪律：金色 `#CBA258` 仅限成就/星标/奖励仪式，不作通用强调色。
///
/// 用法：
/// ```dart
/// SbBadge(text: '128 ★')
/// SbBadge(text: '黄金段位', icon: Icons.star)
/// SbBadge(text: '连续打卡', icon: Icons.emoji_events, onTap: () {})
/// ```
class SbBadge extends StatelessWidget {
  /// 徽章文字，如 '128 ★' 或 '黄金段位'
  final String text;

  /// 可选前缀图标（金色星星、奖杯等）
  final IconData? icon;

  /// 点击回调。null 时不可点击（纯展示）。
  final VoidCallback? onTap;

  const SbBadge({
    super.key,
    required this.text,
    this.icon,
    this.onTap,
  });

  static const Color _gold = Color(0xFFCBA258);
  static const EdgeInsets _padding = EdgeInsets.symmetric(
    vertical: 4,
    horizontal: 12,
  );

  @override
  Widget build(BuildContext context) {
    final badge = Material(
      color: Colors.transparent,
      shape: const StadiumBorder(
        side: BorderSide(width: 1, color: _gold),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: _padding,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: _gold),
                const SizedBox(width: 4),
              ],
              Text(
                text,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _gold,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (onTap != null) {
      return ScaleDownOnPress(onTap: onTap, child: badge);
    }
    return badge;
  }
}
