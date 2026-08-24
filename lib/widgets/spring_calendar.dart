// Spring Calendar：弹性签到日历
// 日期格子依次弹跳出现，已签到金色标记，连击特效
// 颜色可自定义，跟随主题系统
// 适用于：签到页面、学习打卡页面
import 'dart:math' as math;
import 'package:flutter/material.dart';

/// 单日签到数据
class CalendarDay {
  final DateTime date;
  final bool isCheckedIn;
  final int scareCoins;
  final bool isToday;
  final bool isCurrentMonth;

  const CalendarDay({
    required this.date,
    this.isCheckedIn = false,
    this.scareCoins = 0,
    this.isToday = false,
    this.isCurrentMonth = true,
  });
}

/// 弹性签到日历
class SpringCalendar extends StatefulWidget {
  final List<CalendarDay> days;
  final Color? activeColor;
  final Color? inactiveColor;
  final Color? todayColor;
  final double cellSize;
  final double spacing;
  final Function(CalendarDay)? onDayTap;
  final Duration animDuration;
  final bool showWeekday;

  const SpringCalendar({
    super.key,
    required this.days,
    this.activeColor,
    this.inactiveColor,
    this.todayColor,
    this.cellSize = 44,
    this.spacing = 6,
    this.onDayTap,
    this.animDuration = const Duration(milliseconds: 400),
    this.showWeekday = true,
  });

  @override
  State<SpringCalendar> createState() => _SpringCalendarState();
}

class _SpringCalendarState extends State<SpringCalendar>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _animations;
  late AnimationController _comboController;
  late Animation<double> _comboAnim;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(widget.days.length, (i) {
      return AnimationController(
        vsync: this,
        duration: widget.animDuration,
      );
    });
    _animations = _controllers.map((c) {
      return Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: c, curve: Curves.elasticOut),
      );
    }).toList();

    _comboController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _comboAnim = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _comboController, curve: Curves.easeOut),
    );

    // 依次弹跳出现
    _startStaggered();

    // 检查连续签到，触发连击特效
    _checkCombo();
  }

  void _startStaggered() async {
    for (int i = 0; i < _controllers.length; i++) {
      Future.delayed(Duration(milliseconds: 50 * i), () {
        if (mounted) _controllers[i].forward();
      });
    }
  }

  void _checkCombo() {
    // 计算连续签到天数
    int combo = 0;
    for (final day in widget.days.reversed) {
      if (day.isCheckedIn) {
        combo++;
      } else {
        break;
      }
    }
    if (combo >= 3) {
      _comboController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    _comboController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeColor = widget.activeColor ?? const Color(0xFFcba258);
    final inactiveColor = widget.inactiveColor ?? Colors.grey.withValues(alpha: 0.2);
    final todayColor = widget.todayColor ?? const Color(0xFF006241);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 星期标签
        if (widget.showWeekday)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: const ['日', '一', '二', '三', '四', '五', '六']
                  .map((d) => SizedBox(
                        width: 44,
                        child: Center(
                          child: Text(d, style: TextStyle(fontSize: 12, color: Colors.grey)),
                        ),
                      ))
                  .toList(),
            ),
          ),
        // 日期网格
        Wrap(
          spacing: widget.spacing,
          runSpacing: widget.spacing,
          children: List.generate(widget.days.length, (i) {
            final day = widget.days[i];
            return AnimatedBuilder(
              animation: _animations[i],
              builder: (context, child) {
                final scale = _animations[i].value.clamp(0.0, 1.0);
                return Transform.scale(
                  scale: scale,
                  child: _buildDayCell(day, activeColor, inactiveColor, todayColor, i),
                );
              },
            );
          }),
        ),
      ],
    );
  }

  Widget _buildDayCell(CalendarDay day, Color activeColor, Color inactiveColor,
      Color todayColor, int index) {
    final isCombo = day.isCheckedIn && index >= widget.days.length - 3;

    return GestureDetector(
      onTap: () => widget.onDayTap?.call(day),
      child: AnimatedBuilder(
        animation: _comboAnim,
        builder: (context, _) {
          final comboScale = isCombo ? _comboAnim.value : 1.0;
          return Transform.scale(
            scale: comboScale,
            child: Container(
              width: widget.cellSize,
              height: widget.cellSize,
              decoration: BoxDecoration(
                color: day.isCheckedIn
                    ? activeColor
                    : (day.isToday ? todayColor.withValues(alpha: 0.1) : inactiveColor),
                borderRadius: BorderRadius.circular(12),
                border: day.isToday
                    ? Border.all(color: todayColor, width: 2)
                    : null,
                boxShadow: day.isCheckedIn
                    ? [
                        BoxShadow(
                          color: activeColor.withValues(alpha: 0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${day.date.day}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: day.isCheckedIn ? FontWeight.w700 : FontWeight.w400,
                      color: day.isCheckedIn
                          ? Colors.white
                          : (day.isCurrentMonth ? Colors.black87 : Colors.grey),
                    ),
                  ),
                  if (day.isCheckedIn && day.scareCoins > 0)
                    Text(
                      '+${day.scareCoins}',
                      style: const TextStyle(
                        fontSize: 9,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// 迷你签到日历（一行展示最近 7 天）
class MiniSpringCalendar extends StatelessWidget {
  final List<bool> checkInHistory;
  final Color? activeColor;
  final double size;

  const MiniSpringCalendar({
    super.key,
    required this.checkInHistory,
    this.activeColor,
    this.size = 36,
  });

  @override
  Widget build(BuildContext context) {
    final active = activeColor ?? const Color(0xFFcba258);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        math.min(checkInHistory.length, 7),
        (i) {
          final checked = checkInHistory[i];
          return AnimatedContainer(
            duration: Duration(milliseconds: 300 + i * 50),
            curve: Curves.elasticOut,
            width: size,
            height: size,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: checked ? active : Colors.grey.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
              boxShadow: checked
                  ? [
                      BoxShadow(
                        color: active.withValues(alpha: 0.3),
                        blurRadius: 4,
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: Icon(
                checked ? Icons.check : Icons.circle_outlined,
                size: size * 0.5,
                color: checked ? Colors.white : Colors.grey.withValues(alpha: 0.5),
              ),
            ),
          );
        },
      ),
    );
  }
}
