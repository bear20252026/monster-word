part of 'class_checkin_page.dart';

/// 弹性签到日历卡片（集成 spring_calendar 组件，数据来自尖叫币账本）
///
/// 只展示本月 1 号至今天：已签格金色对勾+尖叫币角标，今日高亮；
/// 签到状态变化时通过 ValueKey 重建以重放错峰入场动画。
class _SpringCalendarCard extends StatefulWidget {
  final ThemeVars skin;
  const _SpringCalendarCard({required this.skin});

  @override
  State<_SpringCalendarCard> createState() => _SpringCalendarCardState();
}

class _SpringCalendarCardState extends State<_SpringCalendarCard> {
  Set<String> _dates = {};
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final dates = await context.read<ScareCoinStore>().checkinDates();
    if (!mounted) return;
    setState(() {
      _dates = dates;
      _loaded = true;
    });
  }

  String _iso(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final skin = widget.skin;
    final now = DateTime.now();

    // 周日为一周起始（与 SpringCalendar 内置表头一致），补齐月初空白
    final leadingBlanks = DateTime(now.year, now.month).weekday % 7;
    final days = <CalendarDay>[
      for (var i = leadingBlanks; i > 0; i--)
        CalendarDay(date: DateTime(now.year, now.month, 1 - i), isCurrentMonth: false),
      for (var d = 1; d <= now.day; d++)
        CalendarDay(
          date: DateTime(now.year, now.month, d),
          isCheckedIn: _dates.contains(_iso(DateTime(now.year, now.month, d))),
          isToday: d == now.day,
          scareCoins: _dates.contains(_iso(DateTime(now.year, now.month, d))) ? 10 : 0,
        ),
    ];

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: skin.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: skin.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('我的签到日历', style: MistralTypography.heading5.copyWith(color: skin.text1)),
              const Spacer(),
              Icon(Icons.auto_awesome, size: 16, color: skin.accent),
            ],
          ),
          SizedBox(height: 12),
          if (!_loaded)
            SizedBox(height: 120, child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
          else
            // ValueKey：签到数变化时重建组件，重放弹性入场动画
            SpringCalendar(
              key: ValueKey('spring_cal_${_dates.length}'),
              days: days,
              activeColor: skin.accent,
              todayColor: skin.success,
              onDayTap: (_) {},
            ),
        ],
      ),
    );
  }
}
