// 由账号4生成
// 核心控件层：翻译自 widget/（v3.2 源码 1:1）
// 文件：BBCheckIn（签到组件）+ LearnButton（学习按钮带圆点）

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 签到状态（原版常量）
enum CheckInState {
  no(0), // CHECKIN_NO 未签到
  ing(1), // CHECKIN_ING 签到中
  yes(2); // CHECKIN_YES 已签到

  const CheckInState(this.value);
  final int value;
}

/// 签到组件（翻译自 BBCheckIn.java：图标 + 标题 + 描述）
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

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 139,
        height: 135,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.25),
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.5),
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 图标（原版 ivIcon）
            Icon(_iconForState, color: Colors.white, size: 36),
            const SizedBox(height: 8),
            // 标题（原版 tv_signin_title）
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            // 描述（原版 tv_signin_des）
            if (description.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
            ],
          ],
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
        return Icons.emoji_events; // 已签到：花朵/奖杯
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
    return GestureDetector(
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
