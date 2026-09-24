// 弹性签到日历（灵感：inspira-ui spring-calendar）
//
// 特性：
// 1) 日期格子以弹簧曲线错峰入场（scale 过冲回弹）
// 2) 已签到日期显示弹跳对勾标记
// 3) 连续签到期数「连击」特效：火焰计数脉冲 + 今日签到后整卡弹跳、+10 浮层上升
// 4) 接入现有 check-in 逻辑：context.read<ScareCoinStore>().checkIn()（每日 +10 尖叫币）
// 5) 颜色全部来自 SkinSystem，跟随全局主题切换
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:word_app/features/scare_coin/application/scare_coin_store.dart';
import 'package:word_app/theme/skin_system.dart';
import 'package:word_app/tokens/design_tokens.dart';
import 'package:word_app/widgets/coin_feed_stage.dart';
import 'package:word_app/widgets/coin_swallow_celebration.dart';
import 'package:word_app/widgets/monster_icon.dart';

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
  bool _showSwallow = false; // 吞金币庆祝 overlay（播完自清，不常驻）
  bool _checking = false; // 忙态：checkIn() 在途，按钮 morph 为 spinner 并拦截连点
  bool _feeding = false; // 亲手投喂态：按钮让位给投喂台，币由用户拖进嘴
  double _tailStart = 0.0; // 投喂续演起点（0.32 币已到嘴）；点按自动为 0
  int _lastReward = 0; // 本次签到增量（金库窗滚动起点口径）
  int _lastBalance = 0; // 签到后最新余额（金库窗滚动终点）

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

  /// 点按自动签到：币从按钮弹射（celebrationStart 0）。
  Future<void> _onCheckIn() => _doCheckIn(celebrationStart: 0.0);

  /// 投喂成功：币已到嘴，续演后三幕（celebrationStart 0.32）。
  Future<void> _onFed() => _doCheckIn(celebrationStart: 0.32);

  /// 投喂台偷懒入口：回落自动签到。
  Future<void> _feedAuto() => _doCheckIn(celebrationStart: 0.0);

  /// 长按金币进入亲手投喂（今日已签／在途不进）。
  void _enterFeedMode() {
    if (_todayChecked || _checking || _feeding || _justChecked) return;
    setState(() => _feeding = true);
  }

  Future<void> _doCheckIn({required double celebrationStart}) async {
    if (_todayChecked || _checking) return;
    final store = context.read<ScareCoinStore>();
    setState(() {
      _checking = true;
      _feeding = false;
    });
    final newBalance = await store.checkIn();
    if (!mounted) return;
    if (newBalance == null) {
      // 并发已签过：落忙态、同步日历状态后收尾。
      setState(() => _checking = false);
      await _refresh();
      return;
    }
    widget.onChecked?.call();
    // 系统「减少动态效果」时跳过粒子庆祝，直接呈现结果（MEM-03 同约）。
    final reduceMotion = WidgetsBinding.instance.platformDispatcher.accessibilityFeatures.disableAnimations;
    setState(() {
      _justChecked = true;
      _checking = false;
      _showSwallow = !reduceMotion;
      _tailStart = celebrationStart;
      _lastReward = store.checkInReward;
      _lastBalance = newBalance;
    });
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
          style: TextStyle(fontSize: AppFontSizes.bodyMd, fontWeight: FontWeight.w700, color: skin.text1),
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
                        context.skin.colors.accent.withValues(alpha: 0.9),
                        MwColors.sunshine500.withValues(alpha: 0.9),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.local_fire_department_rounded, size: 14, color: AppColors.white100),
                      const SizedBox(width: 4),
                      Text(
                        '连击 $_streak',
                        style: MwTypography.micro.copyWith(fontWeight: FontWeight.w700, color: AppColors.white100),
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
                child: Text(
                  l,
                  style: MwTypography.micro.copyWith(fontWeight: FontWeight.w400, color: skin.text3),
                ),
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
                              fontSize: AppFontSizes.caption,
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
                    child: Icon(Icons.star_rounded, size: 11, color: context.skin.colors.accent.withValues(alpha: 0.9)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── 吞金币庆祝自清 ──
  void _hideSwallow() {
    if (!mounted) return;
    setState(() {
      _showSwallow = false;
      _tailStart = 0.0;
    });
  }

  // ── 底部签到按钮／亲手投喂台 ──
  Widget _buildCheckInButton(BuildContext context, dynamic skin) {
    // 进化口径：累计签到天数 → 阶段＋生长基线（投喂台／庆祝同源，越养越大）。
    final totalDays = _checkedDates.length;
    final evoStage = MonsterIcon.stageFor(totalDays);
    final growthBase = MonsterIcon.growthFor(totalDays);
    return Column(
      children: [
        // 亲手投喂态：按钮整体让位给投喂台（怪兽＋可拖金币）。
        if (_feeding) CoinFeedStage(onFed: _onFed, onAuto: _feedAuto, evoStage: evoStage, growthBase: growthBase),
        if (!_feeding)
          SizedBox(
            width: double.infinity,
            height: 46,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: _todayChecked ? skin.divider : skin.accent,
                foregroundColor: _todayChecked ? skin.text3 : AppColors.white100,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(context.design.radius.lg)),
              ),
              onPressed: (_todayChecked || _checking || _showSwallow) ? null : _onCheckIn,
              // 长按金币亲手投喂（今日已签／在途不进，见 _enterFeedMode）。
              onLongPress: _enterFeedMode,
              // 忙态 morph：金币图标以缩放转场变为 spinner（cojeev busy 态同构），
              // 在途拦截连点；庆祝时币已“离家”飞入兽嘴，留等大透明占位防布局跳动。
              icon: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
                child: _checking
                    ? const SizedBox(
                        key: ValueKey('busy'),
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.white100),
                      )
                    : _showSwallow
                    ? const SizedBox(key: ValueKey('launched'), width: 20, height: 20)
                    : _todayChecked
                    ? Icon(Icons.check_circle_outline, key: const ValueKey('done'), size: 20)
                    : const CoinBadge(key: ValueKey('coin'), size: 20),
              ),
              label: Text(
                _checking
                    ? '正在签到…'
                    : (_todayChecked ? '今日已签到，明天再来～' : '签到领 ${context.read<ScareCoinStore>().checkInReward} 尖叫币'),
                style: TextStyle(fontSize: AppFontSizes.bodySm, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        // 投喂入口小字：仅 idle 出现，点之亦入投喂台（长按是另一入口）。
        if (!_feeding && !_todayChecked && !_justChecked && !_checking && !_showSwallow)
          GestureDetector(
            onTap: _enterFeedMode,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('长按金币，亲手投喂更香', style: MwTypography.micro.copyWith(color: skin.text3)),
            ),
          ),
        // 吞金币庆祝：肚皮储蓄罐，播完自清；期间旧 +N 浮层让位，避免文案重叠。
        if (_showSwallow)
          CoinSwallowCelebration(
            reward: _lastReward,
            balance: _lastBalance,
            startAt: _tailStart,
            evoStage: evoStage,
            growthBase: growthBase,
            onDone: _hideSwallow,
          ),
        // +10 浮层：签到成功后上升淡出
        AnimatedBuilder(
          animation: _comboCtrl,
          builder: (context, _) {
            if (!_justChecked || !_comboCtrl.isAnimating || _showSwallow) {
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
                      style: MwTypography.heading4.copyWith(fontWeight: FontWeight.w900, color: skin.success),
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
      borderRadius: BorderRadius.circular(AppRadius.sm),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(icon, size: 20, color: skin.text2),
      ),
    );
  }
}
