// CoinBadge：签到金币徽章 — 品牌金圆＋星形矢量标（emoji 守卫禁 ★ 字符，一律用 Icons）。
// 公开给签到按钮复用同一视觉物（idle 态即此币，发射后币“离家”飞入兽嘴）。
import 'package:flutter/material.dart';

import 'package:word_app/tokens/design_tokens.dart';

class CoinBadge extends StatelessWidget {
  final double size;

  const CoinBadge({super.key, this.size = 36});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [MwColors.sunshine300, MwColors.mutedGold],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: MwColors.mutedGold, width: size >= 28 ? 2 : 1.5),
        boxShadow: [
          BoxShadow(
            color: MwColors.sunshine300.withValues(alpha: AppAlphas.o55),
            blurRadius: 12 * size / 36,
            offset: Offset(0, 3 * size / 36),
          ),
        ],
      ),
      child: Icon(Icons.star_rounded, size: size * 0.56, color: AppColors.white100),
    );
  }
}
