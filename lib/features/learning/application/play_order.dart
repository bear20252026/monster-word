// 由 Claude 团队生成 | Monster Word App

import 'package:flutter/material.dart';

/// 随身听播放顺序。
///
/// 从 play_order_page 下沉到 application 层：播放顺序既被设置页（PlayOrderPage）
/// 消费，也被随身听播放器状态（StereoPlayerState）消费，属于应用层概念。
enum PlayOrder {
  sequential('顺序播放', Icons.format_list_numbered),
  reverse('逆序播放', Icons.format_list_numbered_rtl),
  random('随机播放', Icons.shuffle),
  alphabetical('字母顺序', Icons.sort_by_alpha);

  final String label;
  final IconData icon;
  const PlayOrder(this.label, this.icon);
}
