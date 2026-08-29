import 'package:flutter/material.dart';

import '../theme/skin_system.dart';

/// 签到概览统计卡片
/// 显示总签到天数、连续天数、本月进度
class CheckInStatsCard extends StatelessWidget {
  final int totalCheckIns;
  final int currentStreak;
  final double monthlyProgress;
  final DateTime selectedMonth;

  const CheckInStatsCard({
    super.key,
    required this.totalCheckIns,
    required this.currentStreak,
    required this.monthlyProgress,
    required this.selectedMonth,
  });

  @override
  Widget build(BuildContext context) {
    final skin = context.skin.colors;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: skin.cardBg,
        borderRadius: BorderRadius.circular(context.design.radius.xl),
        boxShadow: const [
          BoxShadow(color: Color(0x23000000), blurRadius: 0.5, offset: Offset(0, 0)),
          BoxShadow(color: Color(0x3D000000), blurRadius: 1.0, offset: Offset(0, 1)),
        ],
      ),
      child: Row(
        children: [
          // 总签到天数
          Expanded(
            child: Column(
              children: [
                Text(
                  '$totalCheckIns',
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: skin.accent),
                ),
                const SizedBox(height: 4),
                Text('累计天数', style: TextStyle(fontSize: 13, color: skin.text3)),
              ],
            ),
          ),
          // 分割线
          Container(width: 1, height: 40, color: skin.divider),
          // 连续天数
          Expanded(
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$currentStreak',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: currentStreak > 0 ? const Color(0xFFE8913A) : skin.text3,
                      ),
                    ),
                    if (currentStreak > 0)
                      Padding(
                        padding: const EdgeInsets.only(left: 2, bottom: 4),
                        child: Text('🔥', style: TextStyle(fontSize: currentStreak >= 7 ? 20 : 16)),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text('连续天数', style: TextStyle(fontSize: 13, color: skin.text3)),
              ],
            ),
          ),
          // 分割线
          Container(width: 1, height: 40, color: skin.divider),
          // 本月进度环
          Expanded(
            child: Column(
              children: [
                SizedBox(
                  width: 52,
                  height: 52,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // 背景环
                      CircularProgressIndicator(value: 1.0, strokeWidth: 5, color: skin.divider),
                      // 进度环
                      CircularProgressIndicator(
                        value: monthlyProgress.clamp(0.0, 1.0),
                        strokeWidth: 5,
                        color: skin.accent,
                        strokeCap: StrokeCap.round,
                      ),
                      // 中心文字
                      Text(
                        '${(monthlyProgress * 100).round()}%',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: skin.text1),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text('本月进度', style: TextStyle(fontSize: 13, color: skin.text3)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
