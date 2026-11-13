part of '../home_screen.dart';

/// 签到条：火焰图标 + 连签天数/召唤，点击打开弹性签到日历。
class _CheckInStrip extends StatefulWidget {
  const _CheckInStrip();

  @override
  State<_CheckInStrip> createState() => _CheckInStripState();
}

class _CheckInStripState extends State<_CheckInStrip> with SingleTickerProviderStateMixin {
  bool? _checkedToday;
  int _streakDays = 0;

  // 未签到火苗的 2s alpha 呼吸循环（o40↔o90，easeInOut 反复；时长字面量与库内循环动画惯例一致）
  late final AnimationController _flameCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2000),
  );
  late final Animation<double> _flameBreath = Tween<double>(
    begin: 0,
    end: 1,
  ).animate(CurvedAnimation(parent: _flameCtrl, curve: Curves.easeInOut));

  bool get _reduceMotion => WidgetsBinding.instance.platformDispatcher.accessibilityFeatures.disableAnimations;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  /// REG-FLAME-001 守护观测口：火苗 ticker 是否仍在转
  /// （签到后必须 stop，否则全天 60fps 空转）。
  bool get flameAnimatingForTest => _flameCtrl.isAnimating;

  @override
  void dispose() {
    _flameCtrl.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    final reader = context.read<CheckinStatusReader>();
    final results = await Future.wait([reader.hasCheckedInToday(), reader.getStreakDays()]);
    if (!mounted) return;
    setState(() {
      _checkedToday = results[0] as bool;
      _streakDays = results[1] as int;
    });
    // 未签到才呼吸；reduce-motion 时保持静态
    if (_checkedToday == false && !_reduceMotion) {
      if (!_flameCtrl.isAnimating) _flameCtrl.repeat(reverse: true);
    } else if (_flameCtrl.isAnimating) {
      // 签到后火苗不再上树，但 ticker 不会自己停——不停就是剩下全天 60fps 空转。
      _flameCtrl.stop();
    }
  }

  /// 已签到的连签文案：加一句「距下一档还差几天」，封顶后只鼓励保持。
  String _checkedStreakLabel() {
    final daysToNext = daysToNextStreakMilestone(_streakDays);
    if (daysToNext == null) return '已连续签到 $_streakDays 天，保持住';
    return '已连续签到 $_streakDays 天，再坚持 $daysToNext 天解锁下一档';
  }

  /// 火苗图标：未签到时 alpha 呼吸（o40↔o90 lerp，easeInOut 反复）；已签或 reduce-motion 时静态。
  Widget _flameIcon(ThemeVars colors) {
    if (_checkedToday != false || _reduceMotion) {
      return Icon(
        Icons.local_fire_department_rounded,
        size: 18,
        color: _checkedToday == true ? colors.accent : colors.text3,
      );
    }
    return AnimatedBuilder(
      animation: _flameBreath,
      builder: (context, _) => Icon(
        Icons.local_fire_department_rounded,
        size: 18,
        color: Color.lerp(
          colors.text3.withValues(alpha: AppAlphas.o40),
          colors.text3.withValues(alpha: AppAlphas.o90),
          _flameBreath.value,
        ),
      ),
    );
  }

  /// 打开「聚宝日历」签到页（GUI 外观设计落地版；旧弹性日历见 widgets/spring_check_in_calendar.dart）。
  Future<void> _openSheet() async {
    await Navigator.of(context).pushNamed(RouteNames.treasureCheckIn);
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
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: skin.colors.accent.withValues(alpha: AppAlphas.o10),
                shape: BoxShape.circle,
              ),
              child: _flameIcon(skin.colors),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                checked ? _checkedStreakLabel() : '今天还没签到，别断啦',
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

/// 每日任务条（M2 / D1+D2）：一行摘要，点击展开三条任务的详情与宝箱。
///
/// 发币在 [DailyMissionRewardService] 里幂等结算（`event_key=mission:<day>:<taskId>`），
/// 这里只负责进度展示与「开箱演出」——宝箱不产出随机奖励，三条任务全部完成
/// 固定 +15（每条 5），与决策单一致。
class _MissionStrip extends StatefulWidget {
  const _MissionStrip();

  @override
  State<_MissionStrip> createState() => _MissionStripState();
}

class _MissionStripState extends State<_MissionStrip> {
  final ConfettiController _chest = ConfettiController();

  late final DailyMissionStore _store;
  bool _settling = false;
  int? _lastDue;

  @override
  void initState() {
    super.initState();
    _store = context.read<DailyMissionStore>();
    _store.addListener(_onStoreChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_refresh());
    });
  }

  @override
  void dispose() {
    _store.removeListener(_onStoreChanged);
    _chest.dispose();
    super.dispose();
  }

  void _onStoreChanged() {
    if (!mounted) return;
    unawaited(_settle());
  }

  Future<void> _refresh({int? dueNow}) async {
    await _store.ensureLoaded(dueNow: dueNow ?? context.read<TodayProgressStore>().due);
    await _settle();
  }

  Future<void> _settle() async {
    if (_settling || !mounted) return;
    // 没有待结算任务时完全不碰币账本（测试里可以没有 ScareCoinStore）。
    if (_store.completedUnclaimed.isEmpty) return;
    _settling = true;
    try {
      await DailyMissionRewardService(store: _store, coins: context.read<ScareCoinStore>()).settle();
    } finally {
      _settling = false;
    }
  }

  Future<void> _openSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _MissionSheet(chest: _chest),
    );
    if (mounted) unawaited(_refresh());
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    // 到期数变化 → 复习任务目标变化；build 内只登记，postFrame 再写 Store，
    // 避免在 build 期间触发 notifyListeners。
    final due = context.select<TodayProgressStore, int>((s) => s.due);
    if (_lastDue != due) {
      _lastDue = due;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _lastDue == due) unawaited(_store.refreshDue(dueNow: due));
      });
    }

    return ListenableBuilder(
      listenable: _store,
      builder: (context, _) {
        final done = _store.completedCount;
        final total = DailyMissionId.values.length;
        return ScaleDownOnPress(
          onTap: _openSheet,
          child: MwCard(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: skin.colors.accent.withValues(alpha: AppAlphas.o10),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.checklist_rounded, size: 18, color: skin.colors.accent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '今日任务 $done/$total',
                    style: MwTypography.bodySm.copyWith(fontWeight: FontWeight.w600, color: skin.colors.text1),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: ShapeDecoration(
                    color: skin.colors.cardBg,
                    shape: StadiumBorder(side: BorderSide(color: skin.colors.divider)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.card_giftcard_rounded, size: 16, color: skin.colors.accent),
                      const SizedBox(width: 4),
                      Text(
                        _store.claimedCount >= total ? '已开' : '+$dailyMissionDailyCoinCap',
                        style: MwTypography.micro.copyWith(fontWeight: FontWeight.w700, color: skin.colors.text2),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Icon(Icons.chevron_right, size: 20, color: skin.colors.text3),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// 任务详情 + 宝箱演出（宝箱不随机，纯视觉；发币已由条带结算）。
class _MissionSheet extends StatelessWidget {
  const _MissionSheet({required this.chest});

  final ConfettiController chest;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final store = context.watch<DailyMissionStore>();
    final missions = store.missions;
    final allDone = store.allCompleted;
    return ConfettiOverlay(
      controller: chest,
      direction: ConfettiDirection.up,
      particleCount: 40,
      duration: const Duration(seconds: 2),
      child: Container(
        decoration: BoxDecoration(
          color: skin.colors.cardBg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(context.design.radius.xl)),
        ),
        padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).viewInsets.bottom + 20),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: skin.colors.divider,
                    borderRadius: BorderRadius.circular(context.design.radius.xs),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text(
                    '今日任务',
                    style: MwTypography.titleLg.copyWith(fontWeight: FontWeight.w700, color: skin.colors.text1),
                  ),
                  const Spacer(),
                  Text(
                    '每条 +$dailyMissionCoinReward · 每日上限 $dailyMissionDailyCoinCap',
                    style: MwTypography.micro.copyWith(color: skin.colors.text3),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              for (final mission in missions) _MissionRow(mission: mission),
              const SizedBox(height: 8),
              ScaleDownOnPress(
                onTap: allDone ? chest.play : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: ShapeDecoration(
                    color: allDone ? skin.colors.accent.withValues(alpha: AppAlphas.o10) : skin.colors.cardBg,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(context.design.radius.control),
                      side: BorderSide(color: allDone ? skin.colors.accent : skin.colors.divider),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        allDone ? Icons.lock_open_rounded : Icons.lock_outline_rounded,
                        size: 22,
                        color: allDone ? skin.colors.accent : skin.colors.text3,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          allDone
                              ? (store.claimedCount == missions.length
                                    ? '宝箱已开启，明天再来'
                                    : '宝箱已开启 +$dailyMissionDailyCoinCap')
                              : '宝箱还差 ${missions.length - store.completedCount} 条任务',
                          style: MwTypography.bodySm.copyWith(
                            fontWeight: FontWeight.w600,
                            color: allDone ? skin.colors.text1 : skin.colors.text3,
                          ),
                        ),
                      ),
                      if (allDone) Icon(Icons.celebration_rounded, size: 20, color: skin.colors.accent),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MissionRow extends StatelessWidget {
  const _MissionRow({required this.mission});

  final DailyMissionView mission;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Icon(
            mission.completed ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
            size: 20,
            color: mission.completed ? skin.colors.accent : skin.colors.text3,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              mission.definition.title,
              style: MwTypography.bodySm.copyWith(
                color: mission.completed ? skin.colors.text1 : skin.colors.text2,
                decoration: mission.completed ? TextDecoration.lineThrough : null,
                decorationColor: skin.colors.text3,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            mission.progressLabel,
            style: MwTypography.micro.copyWith(
              fontWeight: FontWeight.w600,
              color: mission.completed ? skin.colors.accent : skin.colors.text3,
            ),
          ),
        ],
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
    return Selector<LearningSessionReader, String?>(
      selector: (_, s) => s.currentBook?.name,
      builder: (context, bookName, _) => ScaleDownOnPress(
        onTap: () => Navigator.pushNamed(context, RouteNames.libSelect),
        child: MwCard(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: skin.colors.accent.withValues(alpha: AppAlphas.o10),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.collections_bookmark_outlined, size: 18, color: skin.colors.accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '当前词书',
                      style: TextStyle(fontSize: AppFontSizes.micro, color: skin.colors.text3),
                    ),
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
                  shape: StadiumBorder(
                    side: BorderSide(color: skin.colors.accent.withValues(alpha: AppAlphas.o40)),
                  ),
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
            fontSize: AppFontSizes.caption,
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
