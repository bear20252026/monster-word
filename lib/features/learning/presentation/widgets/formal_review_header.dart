import 'package:flutter/material.dart';

import 'package:word_app/core/presentation/responsive.dart';
import 'package:word_app/theme/skin_system.dart';
import 'package:word_app/tokens/design_tokens.dart';

/// 顶部进度和词条操作栏。
///
/// 进度和动作均由页面协调层传入，避免展示组件直接操作会话状态。
class FormalReviewHeader extends StatelessWidget {
  const FormalReviewHeader({
    super.key,
    required this.done,
    required this.total,
    required this.isFavorite,
    required this.onBack,
    required this.onToggleFavorite,
    required this.onRevealAnswer,
    required this.onMarkAsKnown,
    required this.onShowMore,
  });

  final int done;
  final int total;
  final bool isFavorite;
  final VoidCallback onBack;
  final VoidCallback onToggleFavorite;
  final VoidCallback onRevealAnswer;
  final VoidCallback onMarkAsKnown;
  final VoidCallback onShowMore;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin.colors;
    final responsive = context.responsive;
    return Container(
      height: context.design.spacing.navH,
      margin: const EdgeInsets.only(top: 4),
      padding: EdgeInsets.symmetric(horizontal: responsive.horizontalPadding * 0.5),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_ios_new, size: 20, color: skin.onGlassText1),
            tooltip: '返回',
            onPressed: onBack,
          ),
          Text(
            '$done/$total',
            style: TextStyle(
              fontSize: 16 * responsive.fontScale,
              fontWeight: FontWeight.w600,
              color: skin.onGlassText1,
            ),
          ),
          IconButton(
            icon: Icon(
              isFavorite ? Icons.star : Icons.star_border,
              size: 22,
              color: isFavorite ? MwColors.accent : skin.onGlassText1,
            ),
            tooltip: '收藏',
            onPressed: onToggleFavorite,
          ),
          GestureDetector(
            onTap: onRevealAnswer,
            child: Text(
              'abc',
              style: TextStyle(
                fontSize: 16 * responsive.fontScale,
                fontWeight: FontWeight.w700,
                color: skin.onGlassText1,
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: onMarkAsKnown,
            child: Text(
              '熟',
              style: TextStyle(
                fontSize: 16 * responsive.fontScale,
                fontWeight: FontWeight.w700,
                color: skin.onGlassText1,
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(Icons.more_horiz, size: 22, color: skin.onGlassText1),
            tooltip: '更多',
            onPressed: onShowMore,
          ),
        ],
      ),
    );
  }
}
