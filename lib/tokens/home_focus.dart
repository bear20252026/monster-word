// lib/tokens/home_focus.dart
// 首页「纸面编辑感」定稿色 Token 集（2026-11-15）。
//
// 定稿语言：纯奶油纸面 + 单一分组卡；饱和墨绿只出现在进度环 / 主按钮 /
// 选中态，金色仅用于达成。onCta 为金色达成按钮上的深墨字。
// 深色面板族（panel/panelDeep/onPanel 等）保留为令牌定义，当前首页不再
// 消费，避免「亮画布上突然一块暗面板」的割裂感。
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
