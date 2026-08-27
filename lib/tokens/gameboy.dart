// Game Boy 复古像素色彩令牌 — word_machine_page / home_screen 共享
import 'package:flutter/material.dart';

/// Game Boy 风格像素色彩（豁免换肤：像素风设计不跟随星巴克主题）
class GameBoyPalette {
  GameBoyPalette._();

  // ── 屏幕四色 ──
  static const screenBg = Color(0xFF9BBC0F); // Game Boy 绿底
  static const screenDark = Color(0xFF0F380F); // 深绿（文字/状态栏）
  static const screenMid = Color(0xFF306230); // 中绿（次要文字/选项底）
  static const screenLight = Color(0xFF8BAC0F); // 浅绿（高亮文字/分数）

  // ── 机身 ──
  static const bodyGray = Color(0xFFB0B0B0); // 机身灰
  static const bodyDark = Color(0xFF505050); // 深灰（边框/品牌名）

  // ── 按键 ──
  static const buttonRed = Color(0xFFCC3333); // B 键红
  static const buttonPurple = Color(0xFF8844CC); // A 键紫
  static const dpadGray = Color(0xFF404040); // 方向键灰

  // ── 状态指示 ──
  static const powerOn = Color(0xFF4CAF50); // 电源灯亮（绿）
  static const powerOff = Color(0xFFF44336); // 电源灯灭（红）
  static const powerOnGlow = Color(0x994CAF50); // 电源灯辉光（60% 透明）

  // ── 答题反馈 ──
  static const errorBg = Color(0xFF5A1010); // 选错背景
  static const errorFg = Color(0xFFFF6666); // 选错文字 / 错误状态文字

  // ── 通用 ──
  static const shadowBlack = Color(0xFF000000); // 阴影（使用时配 withValues alpha）
  static const textWhite = Color(0xFFFFFFFF); // 按键标签白字
  static const borderTransparent = Colors.transparent; // 未选中边框
  static const pageBackdrop = Color(0xFF2C2C2C); // 页面底色（深灰，衬托机身）
}
