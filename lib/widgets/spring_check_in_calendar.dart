// 弹性签到日历（灵感：inspira-ui spring-calendar）
//
// 特性：
// 1) 日期格子以弹簧曲线错峰入场（scale 过冲回弹）
// 2) 已签到日期显示弹跳对勾标记
// 3) 连续签到期数「连击」特效：🔥 计数脉冲 + 今日签到后整卡弹跳、+10 浮层上升
// 4) 接入现有 check-in 逻辑：context.read<ScareCoinStore>().checkIn()（每日 +10 尖叫币）
// 5) 颜色全部来自 SkinSystem，跟随全局主题切换
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/scare_coin/scare_coin_store.dart';
import '../theme/skin_system.dart';
import '../tokens/design_tokens.dart';
import 'monster_icon.dart';

/// 弹性签到日历
///
/// 用法（通常放在 bottom sheet 或卡片中）：
/// ```dart
/// SpringCheckInCalendar(onChecked: () => refreshBalance())
/// ```
class SpringCheckInCalendar extends StatefulWidget {
  final VoidCallback? onChecked;

  const SpringCheckInCalendar({super.key, this.onChecked});

  @override
  State<SpringCheckInCalendar> createState() => _SpringCheckInCalendarState();
}

class _SpringCheckInCalendarState extends State<SpringCheckInCalendar> with TickerProviderStateMixin {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  Set<String> _checkedDates = {};
  int _streak = 0;
  bool _todayChecked = false;
  bool _justChecked = false; // 本次会话内刚完成签到（触发连击特效）

  late final AnimationController _entranceCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );
  late final AnimationController _bounceCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  late final AnimationController _comboCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void initState() {
    super.initState();
    _refresh(animate: true);
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    _bounceCtrl.dispose();
    _comboCtrl.dispose();
    super.dispose();
  }

  Future<void> _refresh({bool animate = false}) async {
    final store = context.read<ScareCoinStore>();
    final dates = await store.checkinDates();
    final streak = await store.streak();
    if (!mounted) return;
    setState(() {
      _checkedDates = dates;
      _streak = streak;
      _todayChecked = dates.contains(_iso(DateTime.now()));
    });
    if (animate) {
      _entranceCtrl.forward(from: 0);
    }
  }

  String _iso(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _onCheckIn() async {
    if (_todayChecked) return;
    final newBalance = await context.read<ScareCoinStore>().checkIn();
    if (newBalance == null) return; // 已签过（并发保护）
    widget.onChecked?.call();
    if (!mounted) return;
    setState(() => _justChecked = true);
    await _refresh();
    _bounceCtrl.forward(from: 0);
    _comboCtrl.forward(from: 0);
  }

  void _shiftMonth(int delta) {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta);
    });
    _entranceCtrl.forward(from: 0); // 切月重放弹性入场
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin.colors;
    final now = DateTime.now();
    final todayIso = _iso(now);

    // 本月网格：周一为一周起始
    final firstDay = DateTime(_month.year, _month.month);
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final leadingBlanks = (firstDay.weekday - 1) % 7; // Monday=1 → offset 0

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: skin.cardBg,
        borderRadius: BorderRadius.circular(context.design.radius.xl),
        border: Border.all(color: skin.divider),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(skin),
          const SizedBox(height: 14),
          _buildWeekdayRow(skin),
          const SizedBox(height: 8),
          AnimatedBuilder(
            animation: Listenable.merge([_entranceCtrl, _bounceCtrl]),
            builder: (context, child) {
              return Column(
                children: [
                  for (var row = 0; row < ((leadingBlanks + daysInMonth) / 7).ceil(); row++)
                    Row(
                      children: [
                        for (var col = 0; col < 7; col++)
                          Expanded(child: _buildCellOrNull(row, col, leadingBlanks, daysInMonth, todayIso, skin)),
                      ],
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          _buildCheckInButton(context, skin),
        ],
      ),
    );
  }

  // ── 头部：月份切换 + 连击徽章 ──
  Widget _buildHeader(dynamic skin) {
    return Row(
      children: [
        Text(
          '${_month.year}年${_month.month}月',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: skin.text1),
        ),
        const Spacer(),
        // 连击特效徽章
        AnimatedBuilder(
          animation: _comboCtrl,
          builder: (context, _) {
            final pulse = _justChecked && _comboCtrl.isAnimating
                ? 1.0 + 0.35 * (1 - _comboCtrl.value) * (1 - _comboCtrl.value)
                : 1.0;
            final opacity = _streak > 0 ? 1.0 : 0.45;
            return Transform.scale(
              scale: _justChecked ? pulse : 1.0,
              child: Opacity(
                opacity: opacity,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.highlightOrange.withValues(alpha: 0.9),
                        MistralColors.sunshine500.withValues(alpha: 0.9),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('🔥', style: TextStyle(fontSize: 13)),
                      const SizedBox(width: 4),
                      Text(
                        '连击 $_streak',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.white100),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(width: 8),
        _MonthArrow(icon: Icons.chevron_left, onTap: () => _shiftMonth(-1), skin: skin),
        _MonthArrow(icon: Icons.chevron_right, onTap: () => _shiftMonth(1), skin: skin),
      ],
    );
  }

  Widget _buildWeekdayRow(dynamic skin) {
    const labels = ['一', '二', '三', '四', '五', '六', '日'];
    return Row(
      children: labels
          .map(
            (l) => Expanded(
              child: Center(
                child: Text(l, style: TextStyle(fontSize: 12, color: skin.text3)),
              ),
            ),
          )
          .toList(),
    );
  }

  /// 单个日期格；越界处返回占位
  Widget _buildCellOrNull(int row, int col, int leadingBlanks, int daysInMonth, String todayIso, dynamic skin) {
    final index = row * 7 + col - leadingBlanks;
    if (index < 0 || index >= daysInMonth) {
      return const SizedBox(height: 44);
    }
    final date = DateTime(_month.year, _month.month, index + 1);
    final iso = _iso(date);
    final isChecked = _checkedDates.contains(iso);
    final isToday = iso == todayIso;
    final isFuture = date.isAfter(DateTime.now());

    // 错峰弹簧入场：格子按序延迟，elasticOut 过冲
    final cellCount = ((leadingBlanks + daysInMonth) / 7).ceil() * 7;
    final start = (index / cellCount) * 0.55;
    final entrance = CurvedAnimation(
      parent: _entranceCtrl,
      curve: Interval(start, (start + 0.45).clamp(0.0, 1.0), curve: Curves.elasticOut),
    );

    // 今日刚签到的弹跳标记
    final isBounceTarget = isToday && _justChecked;
    final bounce = CurvedAnimation(parent: _bounceCtrl, curve: Curves.elasticOut);
    final bounceScale = isBounceTarget ? 1.0 + 0.5 * (1 - bounce.value) * bounce.value * 2 : 1.0;

    return SizedBox(
      height: 44,
      child: Center(
        child: ScaleTransition(
          scale: entrance,
          child: Transform.scale(
            scale: bounceScale.clamp(0.8, 1.6),
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                // 背景圆
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isChecked
                        ? (isToday ? skin.success : skin.success.withValues(alpha: 0.75))
                        : isToday
                        ? skin.accent.withValues(alpha: 0.15)
                        : skin.pageBg,
                    shape: BoxShape.circle,
                    border: Border.all(color: isToday && !isChecked ? skin.accent : Colors.transparent, width: 1.6),
                  ),
                  child: Center(
                    child: isChecked
                        ? const Icon(Icons.check_rounded, size: 18, color: AppColors.white100)
                        : Text(
                            '${index + 1}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isToday ? FontWeight.w800 : FontWeight.w500,
                              color: isFuture ? skin.text3.withValues(alpha: 0.45) : skin.text1,
                            ),
                          ),
                  ),
                ),
                // 已签到的小星星角标（弹跳标记的余韵）
                if (isChecked && !isToday)
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Icon(Icons.star_rounded, size: 11, color: AppColors.highlightOrange.withValues(alpha: 0.9)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── 底部签到按钮 ──
  Widget _buildCheckInButton(BuildContext context, dynamic skin) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 46,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: _todayChecked ? skin.divider : skin.accent,
              foregroundColor: _todayChecked ? skin.text3 : AppColors.white100,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(context.design.radius.lg)),
            ),
            onPressed: _todayChecked ? null : _onCheckIn,
            icon: Icon(_todayChecked ? Icons.check_circle_outline : Icons.redeem, size: 20),
            label: Text(
              _todayChecked ? '今日已签到，明天再来～' : '签到领 ${context.read<ScareCoinStore>().checkInReward} 尖叫币',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        // +10 浮层：签到成功后上升淡出
        AnimatedBuilder(
          animation: _comboCtrl,
          builder: (context, _) {
            if (!_justChecked || !_comboCtrl.isAnimating) {
              return const SizedBox(height: 0);
            }
            final t = _comboCtrl.value;
            return Opacity(
              opacity: (1 - t).clamp(0.0, 1.0),
              child: Transform.translate(
                offset: Offset(0, -46 * t),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '+${context.read<ScareCoinStore>().checkInReward}',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: skin.success),
                    ),
                    const SizedBox(width: 4),
                    MonsterIcon(size: 24, bodyColor: skin.success),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

/// 月份切换箭头按钮
class _MonthArrow extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final dynamic skin;

  const _MonthArrow({required this.icon, required this.onTap, required this.skin});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(icon, size: 20, color: skin.text2),
      ),
    );
  }
}
