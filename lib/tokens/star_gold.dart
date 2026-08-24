// lib/tokens/star_gold.dart
// 成就徽章色 Token 集 — 金/银/铜
// 来源：docs/hardcode_color_audit.md §6 Token 缺口分析
import 'package:flutter/material.dart';

/// 成就徽章色集
///
/// 用于成就系统、排行榜、徽章展示等场景。
/// 颜色在亮色/暗色主题下保持一致（金属色不受画布影响）。
class StarGold {
  // ─── 金色 ───────────────────────────────────────────────
  /// 成就金色（#FFD700）
  /// 用途：第一名、金牌、最高成就
  static const Color gold = Color(0xFFFFD700);

  /// 金色深色变体（用于文字/图标）
  static const Color goldDark = Color(0xFFC5A000);

  /// 金色浅色变体（用于背景）
  static const Color goldLight = Color(0xFFFFF8E1);

  // ─── 银色 ───────────────────────────────────────────────
  /// 成就银色（#C0C0C0）
  /// 用途：第二名、银牌
  static const Color silver = Color(0xFFC0C0C0);

  /// 银色深色变体
  static const Color silverDark = Color(0xFF9E9E9E);

  /// 银色浅色变体（用于背景）
  static const Color silverLight = Color(0xFFF5F5F5);

  // ─── 铜色 ───────────────────────────────────────────────
  /// 成就铜色（#CD7F32）
  /// 用途：第三名、铜牌
  static const Color bronze = Color(0xFFCD7F32);

  /// 铜色深色变体
  static const Color bronzeDark = Color(0xFF8D5A2A);

  /// 铜色浅色变体（用于背景）
  static const Color bronzeLight = Color(0xFFFFF3E0);
}
