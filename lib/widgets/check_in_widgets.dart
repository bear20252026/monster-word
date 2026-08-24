// 由 Claude 团队生成 | Monster Word App

// 由账号4生成
// 核心控件层：翻译自 widget/（v3.2 源码 1:1）
// 文件：BBCheckIn（签到组件）+ LearnButton（学习按钮带圆点）

import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'scale_down_on_press.dart';

/// 签到状态（原版常量）
enum CheckInState {
  no(0), // CHECKIN_NO 未签到
  ing(1), // CHECKIN_ING 签到中
  yes(2); // CHECKIN_YES 已签到

  const CheckInState(this.value);
  final int value;
}

/// 签到组件（翻译自 BBCheckIn.java：半透明玻璃卡片 + 日历图标 + 日期）
///
/// 原版样式：半透明玻璃效果，居中日历图标 + 签到文字 + 日期（08/19 Wed.）
class BBCheckIn extends StatelessWidget {
  final CheckInState state;
  final String title;
  final String description;
  final VoidCallback? onTap;

  const BBCheckIn({
    super.key,
    this.state = CheckInState.no,
    this.title = '签到',
    this.description = '',
    this.onTap,
  });

  /// 格式化日期为 "08/19 Wed." 格式
  static String formatDate() {
    final now = DateTime.now();
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    const weekdays = ['Mon.', 'Tue.', 'Wed.', 'Thu.', 'Fri.', 'Sat.', 'Sun.'];
    final weekday = weekdays[now.weekday - 1];
    return '$month/$day $weekday';
  }

  @override
  Widget build(BuildContext context) {
    return ScaleDownOnPress(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            width: 139,
            height: 135,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.5),
                width: 1.5,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 日历图标（原版 ivIcon）
                Icon(_iconForState, color: const Color(0xFFE8913A), size: 36),
                const SizedBox(height: 8),
                // 标题（原版 tv_signin_title）
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Color(0xFF1A1A1A),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                // 日期（原版 tv_signin_des：08/19 Wed.）
                const SizedBox(height: 4),
                Text(
                  description.isNotEmpty ? description : formatDate(),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF666666),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData get _iconForState {
    switch (state) {
      case CheckInState.no:
        return Icons.event_available; // 未签到：日历图标
      case CheckInState.ing:
        return Icons.event_note; // 签到中
      case CheckInState.yes:
        return Icons.emoji_events; // 已签到：奖杯
    }
  }
}

/// 学习按钮（翻译自 LearnButton.java：圆角背景 + 下方小圆点指示器）
class LearnButton extends StatelessWidget {
  final String text;
  final Color indicatorColor; // 原版 circleColor
  final Color bgColor;
  final Color textColor;
  final VoidCallback onTap;

  const LearnButton({
    super.key,
    required this.text,
    required this.indicatorColor,
    this.bgColor = Colors.transparent,
    this.textColor = AppColors.black87,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ScaleDownOnPress(
      onTap: onTap,
      child: Container(
        height: 64,
        margin: const EdgeInsets.symmetric(
          horizontal: AppDimens.bottomBarBtnMargin,
        ),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(AppDimens.radiusNormal),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              text,
              style: TextStyle(
                fontSize: AppDimens.learnBtnTextSize,
                color: textColor,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            // 圆点指示器（原版 onDraw 画的小圆）
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: indicatorColor,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
