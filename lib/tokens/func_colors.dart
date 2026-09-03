// lib/tokens/func_colors.dart
// 功能色 Token 集 — 补充缺失的信息蓝/警告橙/紫色
// 来源：docs/hardcode_color_audit.md §6 Token 缺口分析
import 'package:flutter/material.dart';

/// 功能色集（不随主题变化的语义色）
///
/// 用于提示、警告、特殊功能等场景。
/// 这些颜色在亮色/暗色主题下保持一致（语义色不受画布影响）。
class FuncColors {
  // ─── 信息蓝 ─────────────────────────────────────────────
  /// 信息提示色（Material Blue 500）
  /// 用途：提示、链接、信息类标签
  static const Color info = Color(0xFF2196F3);

  /// 信息蓝浅色变体（用于背景/选中态）
  static const Color infoLight = Color(0xFFBBDEFB);

  // ─── 成功绿 ─────────────────────────────────────────────
  /// 成功状态色（Material Green 500）
  /// 用途：成功提示、完成状态
  static const Color success = Color(0xFF4CAF50);

  /// 成功绿浅色变体（用于背景）
  static const Color successLight = Color(0xFFE8F5E9);

  // ─── 警告橙 ─────────────────────────────────────────────
  /// 警告状态色（Material Orange 500）
  /// 用途：警告标签、提醒
  static const Color warning = Color(0xFFFF9800);

  /// 警告橙浅色变体（用于背景）
  static const Color warningLight = Color(0xFFFFE0B2);

  // ─── 紫色 ───────────────────────────────────────────────
  /// 紫色（Material Purple 500）
  /// 用途：特殊功能、VIP、高级标签
  static const Color purple = Color(0xFF9C27B0);

  /// 紫色浅色变体（用于背景）
  static const Color purpleLight = Color(0xFFE1BEE7);

  // ─── 业务语义色（M5 收口，原页面字面量升级为具名 token）──
  /// 连击火焰橙（签到历史连击天数 > 0 的火焰色）
  static const Color streakFlame = Color(0xFFE8913A);

  /// 星级琥珀（评分星星，Material Amber）
  static const Color ratingStar = Color(0xFFFFC107);

  // ─── 通用辅助 ───────────────────────────────────────────
  /// 纯白（通用）
  static const Color white = Color(0xFFFFFFFF);

  /// 纯黑（通用）
  static const Color black = Color(0xFF000000);
}
