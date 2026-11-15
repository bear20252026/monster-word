// lib/tokens/home_focus.dart
// 首页「墨玉焦点面板」专属色 Token 集（2026-11-15 首页重设计）。
//
// 设计意图：奶油画布上放一块深色墨玉面板作为唯一视觉锚点——
// 深绿近黑的底、奶油白文字、金色进度环与高对比 CTA，形成
// 「亮画布 × 暗焦点」的强对比，而不是上一版「奶油上叠奶油」的弱对比。
// 颜色为品牌固定色（不随主题切换），与 StarbucksCreamColors.greenBanner
// 同族但更深，专供首页焦点面板使用。
import 'package:flutter/material.dart';

class HomeFocusColors {
  /// 面板深底（墨玉近黑绿）
  static const Color panelDeep = Color(0xFF0B1F19);

  /// 面板浅底（深绿，渐变上端）
  static const Color panel = Color(0xFF14352C);

  /// 面板内分隔线（奶油白 14%）
  static const Color hairline = Color(0x24F4F1EA);

  /// 面板主文字（奶油白）
  static const Color onPanel = Color(0xFFF4F1EA);

  /// 面板次文字（奶油白 62%）
  static const Color onPanelMuted = Color(0x9EF4F1EA);

  /// 面板内进度环轨道（奶油白 12%）
  static const Color ringTrack = Color(0x1FF4F1EA);

  /// 面板内 CTA 前景（深绿，压在亮色按钮上）
  static const Color onCta = Color(0xFF0B1F19);
}
