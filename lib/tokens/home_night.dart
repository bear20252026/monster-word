// lib/tokens/home_night.dart
// 首页「星夜航程」专属色 Token 集（2026-11-15 推倒重设计）。
//
// 艺术方向：小怪兽的夜航观测站——深空墨蓝画布上悬着极光与星野，
// 今日进度是一枚发光的星环仪表，任务/词书/目标是玻璃质感的航行日志。
// 色彩纪律：极光青是唯一高饱和主色（环/主按钮/选中/图标），
// 紫与品红只做背景极光的低语，金色仅用于「达成」，余者皆星白中性。
// 颜色为品牌固定色（不随主题切换），首页自成一体的夜间世界。
import 'package:flutter/material.dart';

class HomeNightColors {
  // ─── 深空画布 ───────────────────────────────────────────
  /// 深空底（近黑墨蓝）
  static const Color space = Color(0xFF060B16);

  /// 深空上层（极光晕染的墨蓝）
  static const Color spaceLift = Color(0xFF0C1626);

  /// 面板底（深空之上的玻璃层）
  static const Color panel = Color(0xFF0E1A2E);

  /// 面板抬升（渐变上端）
  static const Color panelLift = Color(0xFF16263E);

  // ─── 极光主色族 ─────────────────────────────────────────
  /// 极光青（唯一高饱和主色：星环/主按钮/选中/图标）
  static const Color aurora = Color(0xFF3DE8C8);

  /// 极光青·冰蓝端（渐变与星环扫光的另一端）
  static const Color auroraIce = Color(0xFF59C2FF);

  /// 电紫（背景极光低语）
  static const Color nebula = Color(0xFF7C6CFF);

  /// 品红（背景极光边缘的一抹暖息）
  static const Color ember = Color(0xFFFF5C8A);

  // ─── 星白中性 ───────────────────────────────────────────
  /// 主文字（星白）
  static const Color text1 = Color(0xFFF1F5FB);

  /// 次文字（雾蓝白）
  static const Color text2 = Color(0xFFB7C3D8);

  /// 弱文字（远星灰）
  static const Color text3 = Color(0xFF76839B);

  /// 发丝描边（星白 14%）
  static const Color hairline = Color(0x24F1F5FB);

  /// 玻璃面板底（深空 55%）
  static const Color glass = Color(0x8C0B1424);

  /// 星环轨道（星白 10%）
  static const Color track = Color(0x1AF1F5FB);

  /// 主按钮上的墨字（压在极光青上）
  static const Color onAurora = Color(0xFF06131C);

  /// 星尘（噪点/星野用，星白）
  static const Color stardust = Color(0xFFF1F5FB);
}
