part of '../home_screen.dart';

/// 签到条：火焰图标 + 连签天数/召唤，点击打开弹性签到日历。
class _CheckInStrip extends StatefulWidget {
  const _CheckInStrip();

  @override
  State<_CheckInStrip> createState() => _CheckInStripState();
}

class _CheckInStripState extends State<_CheckInStrip> {
  bool? _checkedToday;
  int _streakDays = 0;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final reader = context.read<CheckinStatusReader>();
    final results = await Future.wait([reader.hasCheckedInToday(), reader.getStreakDays()]);
    if (!mounted) return;
    setState(() {
      _checkedToday = results[0] as bool;
      _streakDays = results[1] as int;
    });
  }

  Future<void> _openSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetCtx) => Padding(
        padding: EdgeInsets.only(left: 20, right: 20, top: 12, bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 24),
        child: const SpringCheckInCalendar(),
      ),
    );
    unawaited(_reload());
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final checked = _checkedToday;
    // 加载中：占位避免布局跳动
    if (checked == null) return const SizedBox(height: 56);

    return ScaleDownOnPress(
      onTap: _openSheet,
      child: MwCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(color: skin.colors.accent.withValues(alpha: 0.10), shape: BoxShape.circle),
              child: Icon(
                Icons.local_fire_department_rounded,
                size: 18,
                color: checked ? skin.colors.accent : skin.colors.text3,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                checked ? '已连续签到 $_streakDays 天，保持下去' : '今天还没签到，别断啦',
                style: MwTypography.bodySm.copyWith(fontWeight: FontWeight.w600, color: skin.colors.text1),
              ),
            ),
            if (!checked)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: ShapeDecoration(color: skin.colors.accent, shape: const StadiumBorder()),
                child: Text(
                  '签到 +10',
                  style: MwTypography.micro.copyWith(fontWeight: FontWeight.w700, color: AppColors.white100),
                ),
              )
            else
              Icon(Icons.chevron_right, size: 20, color: skin.colors.text3),
          ],
        ),
      ),
    );
  }
}

/// 当前词书条：显示在学词书，点击进入词书选择。
class _BookStrip extends StatelessWidget {
  const _BookStrip();

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Selector<LearningStatisticsState, String?>(
      selector: (_, s) => s.currentBook?.name,
      builder: (context, bookName, _) => ScaleDownOnPress(
        onTap: () => Navigator.pushNamed(context, RouteNames.libSelect),
        child: MwCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(color: skin.colors.accent.withValues(alpha: 0.10), shape: BoxShape.circle),
                child: Icon(Icons.collections_bookmark_outlined, size: 18, color: skin.colors.accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('当前词书', style: TextStyle(fontSize: 11, color: skin.colors.text3)),
                    const SizedBox(height: 1),
                    Text(
                      bookName ?? '还没有选择词书',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: MwTypography.bodySm.copyWith(fontWeight: FontWeight.w600, color: skin.colors.text1),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: ShapeDecoration(
                  shape: StadiumBorder(side: BorderSide(color: skin.colors.accent.withValues(alpha: 0.4))),
                ),
                child: Text(
                  '切换',
                  style: MwTypography.micro.copyWith(fontWeight: FontWeight.w600, color: skin.colors.accent),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 每日目标快捷档位：预设 chip + 自定义（打开原有滚轮选择弹层）。
/// 统一走 [TodayProgressStore.setGoal]，全站即时同步。
class _GoalChips extends StatefulWidget {
  const _GoalChips();

  @override
  State<_GoalChips> createState() => _GoalChipsState();
}

class _GoalChipsState extends State<_GoalChips> {
  static const _presets = [10, 20, 50, 100];

  Future<void> _select(int value) async {
    await context.read<TodayProgressStore>().setGoal(value);
    if (mounted) setState(() {});
  }

  Future<void> _openCustomPicker() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(sheetCtx).viewInsets.bottom + 24),
          child: const DailyGoalPicker(),
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final current = context.watch<TodayProgressStore>().goal;
    return Row(
      children: [
        Text(
          '每日目标',
          style: MwTypography.caption.copyWith(fontWeight: FontWeight.w500, color: skin.colors.text3),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Row(
            children: [
              for (final value in _presets) ...[_goalChip(value, current == value, skin), const SizedBox(width: 8)],
              // 当前值不在预设档位时，展示当前值 chip（选中态）
              if (!_presets.contains(current)) ...[_goalChip(current, true, skin), const SizedBox(width: 8)],
              _customChip(skin),
            ],
          ),
        ),
      ],
    );
  }

  Widget _goalChip(int value, bool selected, SkinSystem skin) {
    return ScaleDownOnPress(
      onTap: () => _select(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: ShapeDecoration(
          color: selected ? skin.colors.accent : skin.colors.cardBg,
          shape: StadiumBorder(side: BorderSide(color: selected ? skin.colors.accent : skin.colors.divider)),
        ),
        child: Text(
          '$value',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? AppColors.white100 : skin.colors.text2,
          ),
        ),
      ),
    );
  }

  Widget _customChip(SkinSystem skin) {
    return ScaleDownOnPress(
      onTap: _openCustomPicker,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: ShapeDecoration(
          color: Colors.transparent,
          shape: StadiumBorder(side: BorderSide(color: skin.colors.divider)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.tune, size: 14, color: skin.colors.text2),
            const SizedBox(width: 4),
            Text(
              '自定义',
              style: MwTypography.caption.copyWith(fontWeight: FontWeight.w500, color: skin.colors.text2),
            ),
          ],
        ),
      ),
    );
  }
}
