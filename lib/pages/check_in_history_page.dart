// 签到历史页面：双月日历视图 + 概览卡片 + 签到详情列表
// 参考 Calendar Interactive UI Kit (Penpot) 设计模式
// 路由：/check_in_history
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../features/checkin/application/check_in_history_reader.dart';
import '../hooks/responsive.dart';
import '../theme/skin_system.dart';
import '../tokens/design_tokens.dart';
import '../widgets/scale_down_on_press.dart';
import '../widgets/monster_icon.dart';

class CheckInHistoryPage extends StatefulWidget {
  const CheckInHistoryPage({super.key});
  static const routeName = '/check_in_history';

  @override
  State<CheckInHistoryPage> createState() => _CheckInHistoryPageState();
}

class _CheckInHistoryPageState extends State<CheckInHistoryPage> with SingleTickerProviderStateMixin {
  DateTime _currentMonth = DateTime(DateTime.now().year, DateTime.now().month);
  Set<String> _checkedDates = {};
  int _streak = 0;
  int _totalDays = 0;
  bool _isLoading = true;

  late final AnimationController _monthAnimCtrl;
  late final Animation<double> _monthFadeAnim;
  late final Animation<Offset> _monthSlideAnim;
  late final AnimationController _progressAnimCtrl;
  late final Animation<double> _progressAnim;

  @override
  void initState() {
    super.initState();
    _monthAnimCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _monthFadeAnim = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _monthAnimCtrl, curve: Curves.easeOut));
    _monthSlideAnim = Tween<Offset>(
      begin: const Offset(0.3, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _monthAnimCtrl, curve: Curves.easeOutCubic));
    _progressAnimCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _progressAnim = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _progressAnimCtrl, curve: Curves.easeOutCubic));
    _refresh();
  }

  @override
  void dispose() {
    _monthAnimCtrl.dispose();
    _progressAnimCtrl.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      final checkInReader = context.read<CheckInHistoryReader>();
      final dates = await checkInReader.getCheckedDates();
      final streak = await checkInReader.getStreak();
      if (!mounted) return;
      setState(() {
        _checkedDates = dates;
        _streak = streak;
        _totalDays = dates.length;
        _isLoading = false;
      });
      // 进度环入场动画
      _progressAnimCtrl.forward(from: 0);
      // 月份切换动画
      _monthAnimCtrl.forward(from: 0);
    } catch (e) {
      debugPrint('[CheckInHistory] refresh error: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('加载签到数据失败，请重试')));
      }
    }
  }

  void _shiftMonth(int delta) {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + delta);
    });
    _monthAnimCtrl.forward(from: 0);
  }

  String _iso(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  int get _currentMonthCheckedCount {
    final prefix = '${_currentMonth.year}-${_currentMonth.month.toString().padLeft(2, '0')}';
    return _checkedDates.where((d) => d.startsWith(prefix)).length;
  }

  int get _daysInCurrentMonth => DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day;

  double get _monthlyProgress => _daysInCurrentMonth > 0 ? _currentMonthCheckedCount / _daysInCurrentMonth : 0.0;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin.colors;
    final resp = context.responsive;

    return Scaffold(
      backgroundColor: skin.pageBg,
      body: SafeArea(
        child: _isLoading
            ? Center(child: CircularProgressIndicator(color: skin.accent))
            : _totalDays == 0
            ? _buildEmptyState(skin, resp)
            : _buildContent(skin, resp),
      ),
    );
  }

  // ── 空状态 ──
  Widget _buildEmptyState(ThemeVars skin, AppResponsive resp) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(resp.pageMargin),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 插画占位
            Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(color: skin.cardBgAlt, shape: BoxShape.circle),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(Icons.calendar_today, size: 64, color: skin.divider),
                  Positioned(
                    bottom: 30,
                    right: 30,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(color: skin.accent, shape: BoxShape.circle),
                      child: const Icon(Icons.add, size: 18, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Text('还没有签到记录', style: MistralTypography.heading5.copyWith(color: skin.text1)),
            const SizedBox(height: 8),
            Text('每天签到，养成学习好习惯', style: MistralTypography.bodyMd.copyWith(color: skin.text3)),
            const SizedBox(height: 32),
            SizedBox(
              width: 200,
              height: 48,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: skin.accent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.pill)),
                ),
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.redeem, size: 20),
                label: const Text('去签到', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 主内容 ──
  Widget _buildContent(ThemeVars skin, AppResponsive resp) {
    return CustomScrollView(
      slivers: [
        // 顶部导航栏
        SliverToBoxAdapter(child: _buildNavBar(skin, resp)),
        // 概览卡片
        SliverToBoxAdapter(child: _buildSummaryCard(skin, resp)),
        // 双月日历
        SliverToBoxAdapter(child: _buildDualMonthCalendar(skin, resp)),
        // 签到详情列表标题
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(resp.pageMargin, 24, resp.pageMargin, 8),
            child: Text('签到详情', style: MistralTypography.heading5.copyWith(color: skin.text1)),
          ),
        ),
        // 签到详情列表
        _buildDetailList(skin, resp),
        // 底部留白
        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ],
    );
  }

  // ── 导航栏 ──
  Widget _buildNavBar(ThemeVars skin, AppResponsive resp) {
    return Container(
      height: AppSpacing.navH,
      padding: EdgeInsets.symmetric(horizontal: resp.horizontalPadding),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
            color: skin.text1,
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 4),
          Text('签到历史', style: MistralTypography.heading5.copyWith(color: skin.text1)),
        ],
      ),
    );
  }

  // ── 概览卡片（总天数 / 连续天数 / 本月进度环） ──
  Widget _buildSummaryCard(ThemeVars skin, AppResponsive resp) {
    return Padding(
      padding: EdgeInsets.fromLTRB(resp.pageMargin, 8, resp.pageMargin, 16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: skin.cardBg,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          boxShadow: const [
            BoxShadow(color: Color(0x23000000), blurRadius: 0.5, offset: Offset(0, 0)),
            BoxShadow(color: Color(0x3D000000), blurRadius: 1, offset: Offset(0, 1)),
          ],
        ),
        child: Row(
          children: [
            // 总签到天数
            Expanded(
              child: Column(
                children: [
                  Text(
                    '$_totalDays',
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: skin.accent),
                  ),
                  const SizedBox(height: 4),
                  Text('累计天数', style: MistralTypography.caption.copyWith(color: skin.text3)),
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
                        '$_streak',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          color: _streak > 0 ? const Color(0xFFE8913A) : skin.text3,
                        ),
                      ),
                      if (_streak > 0)
                        Padding(
                          padding: const EdgeInsets.only(left: 2, bottom: 4),
                          child: Text('🔥', style: TextStyle(fontSize: _streak >= 7 ? 20 : 16)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('连续天数', style: MistralTypography.caption.copyWith(color: skin.text3)),
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
                        // 进度环（带入场动画）
                        AnimatedBuilder(
                          animation: _progressAnim,
                          builder: (context, child) {
                            return CircularProgressIndicator(
                              value: _monthlyProgress * _progressAnim.value,
                              strokeWidth: 5,
                              color: skin.accent,
                              strokeCap: StrokeCap.round,
                            );
                          },
                        ),
                        // 中心文字
                        AnimatedBuilder(
                          animation: _progressAnim,
                          builder: (context, child) {
                            return Text(
                              '${(_monthlyProgress * _progressAnim.value * 100).round()}%',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: skin.text1),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text('本月进度', style: MistralTypography.caption.copyWith(color: skin.text3)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 双月日历视图 ──
  Widget _buildDualMonthCalendar(ThemeVars skin, AppResponsive resp) {
    final prevMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: resp.pageMargin),
      child: Column(
        children: [
          // 月份切换箭头
          Row(
            children: [
              const Spacer(),
              _MonthSwitchArrow(icon: Icons.chevron_left, onTap: () => _shiftMonth(-1), skin: skin),
              const SizedBox(width: 8),
              // 月份标签
              Text(
                '${_currentMonth.year}年${_currentMonth.month}月',
                style: MistralTypography.heading5.copyWith(color: skin.text1),
              ),
              const SizedBox(width: 8),
              _MonthSwitchArrow(
                icon: Icons.chevron_right,
                onTap: _currentMonth.month == DateTime.now().month && _currentMonth.year == DateTime.now().year
                    ? null
                    : () => _shiftMonth(1),
                skin: skin,
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 12),
          // 上月日历（始终半透明的辅助视图）
          Opacity(opacity: 0.45, child: _buildMonthGrid(prevMonth, skin, isPrevious: true)),
          const SizedBox(height: 8),
          // 当月日历（主视图，带弹性入场动画）
          FadeTransition(
            opacity: _monthFadeAnim,
            child: SlideTransition(
              position: _monthSlideAnim,
              child: _buildMonthGrid(_currentMonth, skin, isPrevious: false),
            ),
          ),
        ],
      ),
    );
  }

  // ── 单月日历网格 ──
  Widget _buildMonthGrid(DateTime month, ThemeVars skin, {required bool isPrevious}) {
    final firstDay = DateTime(month.year, month.month);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    // 周一为起始：Monday=1 → offset 0
    final leadingBlanks = (firstDay.weekday - 1) % 7;
    final totalCells = leadingBlanks + daysInMonth;
    final rows = (totalCells / 7).ceil();
    final now = DateTime.now();
    final todayIso = _iso(now);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: skin.cardBg,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: skin.divider, width: 0.5),
      ),
      child: Column(
        children: [
          // 星期标签
          Row(
            children: ['一', '二', '三', '四', '五', '六', '日']
                .map(
                  (l) => Expanded(
                    child: Center(
                      child: Text(l, style: TextStyle(fontSize: 12, color: skin.text3)),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 6),
          // 日期网格
          for (var row = 0; row < rows; row++)
            Row(
              children: [
                for (var col = 0; col < 7; col++)
                  Expanded(
                    child: _buildDayCell(row, col, leadingBlanks, daysInMonth, month, todayIso, skin, isPrevious),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  // ── 单个日期单元格 ──
  Widget _buildDayCell(
    int row,
    int col,
    int leadingBlanks,
    int daysInMonth,
    DateTime month,
    String todayIso,
    ThemeVars skin,
    bool isPrevious,
  ) {
    final index = row * 7 + col - leadingBlanks;
    if (index < 0 || index >= daysInMonth) {
      return const SizedBox(height: 40);
    }

    final date = DateTime(month.year, month.month, index + 1);
    final iso = _iso(date);
    final isChecked = _checkedDates.contains(iso);
    final isToday = iso == todayIso;
    final isFuture = date.isAfter(DateTime.now());
    // 连续签到标记：与前后日期连续
    final isConsecutive = isChecked && _isConsecutiveDay(date);

    return SizedBox(
      height: 40,
      child: Center(
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: isChecked
                ? skin.success
                : isToday
                ? skin.accent.withValues(alpha: 0.12)
                : Colors.transparent,
            shape: BoxShape.circle,
            border: isToday ? Border.all(color: skin.vipGoldBg, width: 2) : null,
            boxShadow: isChecked
                ? [BoxShadow(color: skin.success.withValues(alpha: 0.3), blurRadius: 4, offset: const Offset(0, 1))]
                : null,
          ),
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              // 日期数字或对勾
              isChecked
                  ? const Icon(Icons.check_rounded, size: 18, color: Colors.white)
                  : Text(
                      '${index + 1}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isToday ? FontWeight.w800 : FontWeight.w500,
                        color: isFuture
                            ? skin.text3.withValues(alpha: 0.4)
                            : isPrevious
                            ? skin.text3
                            : skin.text1,
                      ),
                    ),
              // 🔥 连续签到标记
              if (isConsecutive) Positioned(top: -3, right: -3, child: Text('🔥', style: TextStyle(fontSize: 10))),
            ],
          ),
        ),
      ),
    );
  }

  /// 判断某天是否与前后签到日连续
  bool _isConsecutiveDay(DateTime date) {
    final prev = _iso(date.subtract(const Duration(days: 1)));
    final next = _iso(date.add(const Duration(days: 1)));
    return _checkedDates.contains(prev) || _checkedDates.contains(next);
  }

  // ── 签到详情列表（按日期分组） ──
  Widget _buildDetailList(ThemeVars skin, AppResponsive resp) {
    // 按日期分组（取当月）
    final prefix = '${_currentMonth.year}-${_currentMonth.month.toString().padLeft(2, '0')}';
    final monthDates = _checkedDates.where((d) => d.startsWith(prefix)).toList()..sort((a, b) => b.compareTo(a));

    if (monthDates.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.all(resp.pageMargin),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: skin.cardBgAlt, borderRadius: BorderRadius.circular(AppRadius.lg)),
            child: Center(
              child: Text('本月还没有签到记录', style: MistralTypography.bodyMd.copyWith(color: skin.text3)),
            ),
          ),
        ),
      );
    }

    return SliverPadding(
      padding: EdgeInsets.symmetric(horizontal: resp.pageMargin),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          final iso = monthDates[index];
          final parts = iso.split('-');
          final month = int.parse(parts[1]);
          final day = int.parse(parts[2]);
          final weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
          final date = DateTime(int.parse(parts[0]), month, day);
          final weekday = weekdays[(date.weekday - 1) % 7];
          final isToday = iso == _iso(DateTime.now());

          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: skin.cardBg,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: isToday ? skin.accent.withValues(alpha: 0.3) : skin.divider),
              ),
              child: Row(
                children: [
                  // 签到状态图标
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(color: skin.success.withValues(alpha: 0.12), shape: BoxShape.circle),
                    child: Icon(Icons.check_circle, size: 20, color: skin.success),
                  ),
                  const SizedBox(width: 12),
                  // 日期信息
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              '$month月$day日',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: skin.text1),
                            ),
                            const SizedBox(width: 8),
                            Text(weekday, style: MistralTypography.caption.copyWith(color: skin.text3)),
                            if (isToday) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: skin.accent.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '今天',
                                  style: TextStyle(fontSize: 11, color: skin.accent, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '签到成功 +${context.read<CheckInHistoryReader>().checkInReward} 尖叫币',
                          style: MistralTypography.caption.copyWith(color: skin.text3),
                        ),
                      ],
                    ),
                  ),
                  // 尖叫币图标
                  MonsterIcon(size: 20, showCircle: true, circleColor: skin.vipGoldBg.withValues(alpha: 0.15)),
                ],
              ),
            ),
          );
        }, childCount: monthDates.length),
      ),
    );
  }
}

/// 月份切换箭头
class _MonthSwitchArrow extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final ThemeVars skin;

  const _MonthSwitchArrow({required this.icon, required this.onTap, required this.skin});

  @override
  Widget build(BuildContext context) {
    return ScaleDownOnPress(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: onTap != null ? skin.cardBgAlt : skin.divider.withValues(alpha: 0.3),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 18, color: onTap != null ? skin.text1 : skin.text3),
      ),
    );
  }
}
