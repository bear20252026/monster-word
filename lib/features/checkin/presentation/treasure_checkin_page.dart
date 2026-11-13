// 聚宝日历 — 签到页（「聚宝日历」GUI 外观设计的产品落地版）
//
// 设计来源：
// - 设计文档 design/聚宝日历签到页-外观专利设计说明.md（设计要点 / 动效时序表）
// - 交互原型 deliverables/calendar-checkin-prototype.html（几何与节奏参数同源搬运）
// - 色板 lib/tokens/treasure_palette.dart（暖纸固定底，色彩卫生守卫 M5 定义处）
//
// 专利设计要点对应：
// ① 12 瓣花齿「日期印章」徽章：r = R − amp·(0.5 − 0.5·cos(12θ))，amp ≈ 0.125R；
//    聚合落位后花齿 ⇄ 圆角方章交叉渐隐。
// ② 散落 ⇄ 聚合双构图：进入时徽章漂浮散落，随后对角波错峰弹簧聚合为 7 列月历；
//    签到后散开 → 停顿 → 重组（可反复体验）。
// ③ 签到碎化-吸入：22 枚金币自今日徽章迸出，贝塞尔弧线吸入储蓄罐投币口；
//    首枚到达罐体 bump 回弹（节流 160ms），肚皮金位上涨。
// ④ 小怪兽储蓄罐联动：青绿圆身 + 橙角橙脚 + 胸前奶白 W，肚皮视窗充盈度与连击绑定。
//
// 无障碍：系统「减少动态效果」时跳过散落与粒子，控件立即可用。
// 位置说明：审计 I11 归位 features/checkin/presentation——业务页面不再
// 借住 widgets 层（跨 feature 经 scare_coin application 端口，现行规则放行）。
import 'package:word_app/widgets/monster_peek_overlay.dart';
import 'package:word_app/core/utils/swallowed_error_report.dart';
import 'package:word_app/core/utils/celebration_math.dart';
import 'package:word_app/core/utils/haptics_gate.dart';
import 'package:word_app/core/utils/milestone_celebration.dart';
import 'package:word_app/core/utils/milestone_guard.dart';
import 'package:word_app/core/utils/sfx.dart';
import 'package:word_app/tokens/motion_tokens.dart';

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';

import 'package:word_app/core/utils/calendar_days.dart';
import 'package:word_app/core/utils/monster_event.dart';
import 'package:word_app/features/checkin/application/belly_interest_store.dart';
import 'package:word_app/features/checkin/application/streak_milestones.dart';
import 'package:word_app/features/checkin/domain/belly_interest.dart';
import 'package:word_app/features/companion/application/monster_companion_port.dart';
import 'package:word_app/features/learning/application/review_schedule_reader.dart';
import 'package:word_app/features/scare_coin/application/scare_coin_store.dart';
// 埋点端口（跨 feature 只 import 对方的 application 层，架构守卫 R4 允许）。
import 'package:word_app/features/telemetry/application/usage_stats_ports.dart';
import 'package:word_app/tokens/design_tokens.dart';
import 'package:word_app/tokens/treasure_palette.dart';
import 'package:word_app/widgets/common/mw_feedback.dart';
import 'package:word_app/widgets/evolution_ceremony_overlay.dart';
import 'package:word_app/widgets/monster_icon.dart';

part 'treasure_checkin_painters.dart';
part 'treasure_checkin_widgets.dart';

/// 聚宝日历签到页（整页路由）。
///
/// 用法：
/// ```dart
/// Navigator.push(context, MaterialPageRoute<void>(builder: (_) => TreasureCheckInPage()));
/// ```
class TreasureCheckInPage extends StatefulWidget {
  const TreasureCheckInPage({super.key, this.onChecked, this.clock});

  /// 签到成功回调（供外部刷新余额等）。
  final VoidCallback? onChecked;

  /// 页面时钟（P2-15，架构审计 2026-11-12）：默认 DateTime.now，测试可注入固定时刻，
  /// 让离线计息/日历/补昨天判定不再依赖真实当前时间（跨零点不再翻红）。
  final DateTime Function()? clock;

  @override
  State<TreasureCheckInPage> createState() => _TreasureCheckInPageState();
}

class _TreasureCheckInPageState extends State<TreasureCheckInPage> with SingleTickerProviderStateMixin {
  /// 统一时钟入口（P2-15）：全页时间判定都走这里，测试经 widget.clock 注入固定时刻。
  DateTime get _nowClock => (widget.clock ?? DateTime.now)();

  // ── 数据 ──
  late DateTime _month = DateTime(_nowClock.year, _nowClock.month);
  bool _todayChecked = false;
  bool _busy = false;
  int _streak = 0;
  int _balance = 0;
  int _reward = 0;

  // ── 模拟 ──
  late final Ticker _ticker = createTicker(_onTick);

  /// 粒子层重绘信号（性能审计 P2，2026-10-05）：徽章弹簧收敛后全页 setState
  /// 停止，fx 层经本信号 + RepaintBoundary 自驱重绘——微尘/氛围常驻但只重绘
  /// 自己那一层，徽章/储蓄罐/CTA 不再陪跑 60fps。
  final _TickSignal _fxSignal = _TickSignal();
  double _now = 0;
  String _mode = 'scatter'; // scatter | grid
  List<_DaySim> _days = [];
  final List<_BurstCoin> _burst = [];
  final List<_OrbitDust> _dust = [];
  final List<_AmbientDot> _ambient = [];
  final math.Random _rnd = math.Random();

  // ── 几何（页面坐标缓存） ──
  final GlobalKey _stageKey = GlobalKey();
  final GlobalKey _piggyKey = GlobalKey();
  double _stageW = 0, _stageH = 0;
  Offset _stageOrigin = Offset.zero;
  Offset _bellyPoint = const Offset(195, 430);

  // ── 庆祝状态 ──
  double _bellyPct = 0.5;
  double _bellyTarget = 0.5;
  double _bumpT = 10; // ≥0.55 视为静止
  double _lastBumpAt = -10;
  int _justIndex = -1;
  double _justAt = -10;
  double _pillPopAt = -10;
  double _gainAt = -10;
  int _gainValue = 0;

  bool get _reduceMotion => WidgetsBinding.instance.platformDispatcher.accessibilityFeatures.disableAnimations;

  @override
  void initState() {
    super.initState();
    _reload(replay: true);
    if (!_reduceMotion) _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _fxSignal.dispose();
    super.dispose();
  }

  String _iso(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Set<String> _checkedDates = {};

  /// D5：保护卡库存（补昨天入口用）。
  int _protectionCount = 0;

  // ── 肚皮储蓄罐离线计息（蓝图 T2「离开的回报」） ──
  /// 计息存储（application 门面）：经 Provider 注入（check_in_feature_providers
  /// 注册），不兜底直建——直建绕过装配、时钟不可换（P2-1，架构审计 2026-11-12）。
  late final BellyInterestStore _bellyStore = context.read<BellyInterestStore>();

  /// 当前可结算币数；0 = 空罐（点击只给陪伴台词，不入账）。
  int _bellyPending = 0;

  /// 反向喷币粒子（罐口 → 上方散开，与签到吸入同坐标系）。
  final List<_SprayCoin> _spray = [];

  /// 计息刷新：读在场时刻与昨日学习量，算出待结算额；首次进页只落标。
  ///
  /// 全段容错：计息是锦上添花，任何读取失败都不得影响签到主流程。
  Future<void> _refreshBellyInterest() async {
    try {
      final lastSeen = _bellyStore.lastSeen();
      if (lastSeen == null) {
        await _bellyStore.markSeen();
        return;
      }
      if (_bellyStore.settledToday()) {
        if (mounted && _bellyPending != 0) setState(() => _bellyPending = 0);
        return;
      }
      // 昨日学习量：learning 域 application 端口（R4 允许）；最小装配单测
      // 没有该 scope，可空读取按 0 词（保底费率）处理。
      final schedule = context.read<ReviewScheduleReader?>();
      final yesterday = calendarDayBefore(_nowClock);
      final stats = schedule?.dailyStatsFor(_iso(yesterday)) ?? const {};
      final words = (stats['learn'] ?? 0) + (stats['review'] ?? 0);
      final awayMinutes = _nowClock.difference(lastSeen).inMinutes;
      final interest = bellyInterestFor(awayMinutes: awayMinutes, yesterdayWords: words);
      if (!mounted) return;
      setState(() => _bellyPending = interest.coins);
      // 刷新在场时刻：本次进页起重新计时（同日闸门仍由 settledDay 把守）。
      await _bellyStore.markSeen();
    } catch (e, s) {
      reportSwallowedError('离线计息刷新失败', e, s);
    }
  }

  /// 点罐结算：幂等入账 → 喷币 + 肚皮 bump → 怪兽探头台词 + 全局喂食反应。
  ///
  /// 空罐点击只给陪伴台词（不入账、不落结算标）；入账失败不软锁。
  Future<void> _settleBellyInterest() async {
    if (_busy) return;
    if (_bellyPending <= 0) {
      MonsterPeekOverlay.show(context, phrase: bellyInterestEmptyLine);
      return;
    }
    final store = context.read<ScareCoinStore>();
    final companion = context.read<MonsterCompanionController?>();
    final usageStats = context.read<UsageStatsRecorder?>();
    final coins = _bellyPending;
    setState(() => _busy = true);
    final int? newBalance;
    try {
      newBalance = await store.grantOnce(delta: coins, reason: '肚皮罐离线计息', eventKey: _bellyStore.eventKeyForToday());
    } catch (e, s) {
      reportSwallowedError('离线计息入账失败', e, s);
      if (mounted) {
        setState(() => _busy = false);
        showMwSnackBar(context, const SnackBar(content: Text('收罐失败了，稍后再点一次吧')));
      }
      return;
    }
    if (!mounted) return;
    if (newBalance == null) {
      // 并发已结算：同步状态收尾，不重复演出。
      await _bellyStore.markSettled();
      if (!mounted) return;
      setState(() {
        _bellyPending = 0;
        _busy = false;
      });
      return;
    }
    await _bellyStore.markSettled();
    if (!mounted) return;
    widget.onChecked?.call();
    if (usageStats != null) {
      unawaited(() async {
        try {
          await usageStats.recordCoinsEarned(coins);
        } catch (e, s) {
          reportSwallowedError('离线计息埋点上报失败', e, s);
        }
      }());
    }
    // 全局怪兽反应：只报「被喂食」事实，演出由 companion 场景图决定。
    companion?.dispatch(MonsterEvent.fed);
    setState(() {
      _balance = newBalance!;
      _bellyPending = 0;
      _gainAt = _now;
      _gainValue = coins;
    });
    SfxPlayer.fire(Sfx.coinTick);
    HapticsGate.play(HapticCue.medium);
    if (_reduceMotion) {
      setState(() => _busy = false);
      MonsterPeekOverlay.show(context, phrase: bellyInterestSettledLine);
      return;
    }
    _sprayFromBelly(coins);
    setState(() => _bumpT = 0);
    MonsterPeekOverlay.show(context, phrase: bellyInterestSettledLine);
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _busy = false);
    });
  }

  /// 反向喷币：自罐口向上散开（数量随结算额，封顶 22 枚同签到粒子预算）。
  void _sprayFromBelly(int coins) {
    final count = coins.clamp(6, 22);
    final sx0 = _bellyPoint.dx;
    final sy0 = _bellyPoint.dy - 30;
    for (var i = 0; i < count; i++) {
      final spread = (_rnd.nextDouble() - 0.5) * 180;
      _spray.add(
        _SprayCoin(
          sx: sx0 + (_rnd.nextDouble() - 0.5) * 24,
          sy: sy0 + (_rnd.nextDouble() - 0.5) * 12,
          ex: sx0 + spread,
          ey: sy0 - 60 - _rnd.nextDouble() * 90,
          t0: _now + i * 0.02,
          dur: 0.5 + _rnd.nextDouble() * 0.3,
          size: 2 + _rnd.nextDouble() * 2.6,
          color: _rnd.nextInt(3),
        ),
      );
    }
  }

  /// D5：昨天还没签且已有签到史时，才在日历里露出「补昨天」入口。
  bool get _canMakeupYesterday {
    if (_checkedDates.isEmpty) return false;
    final now = _nowClock;
    return !_checkedDates.contains(_iso(DateTime(now.year, now.month, now.day - 1)));
  }

  Future<void> _reload({bool replay = false}) async {
    final store = context.read<ScareCoinStore>();
    final results = await Future.wait([store.checkinDates(), store.streak(), store.balance(), store.protectionCount()]);
    if (!mounted) return;
    setState(() {
      _checkedDates = results[0] as Set<String>;
      _streak = results[1] as int;
      _balance = results[2] as int;
      _protectionCount = results[3] as int;
      _reward = store.checkInReward;
      _todayChecked = _checkedDates.contains(_iso(_nowClock));
      _bellyTarget = _pctFor(_streak);
      _bellyPct = _bellyTarget;
    });
    _buildMonth();
    if (replay) _replay();
    unawaited(_refreshBellyInterest());
  }

  /// 连击 → 肚皮充盈度（原型标定：(streak+12)/30）。
  double _pctFor(int streak) => ((streak + 12) / 30).clamp(0.0, 1.0);

  // ── 月份构建 ──
  void _buildMonth() {
    final today = _nowClock;
    final todayIso = _iso(today);
    final count = DateTime(_month.year, _month.month + 1, 0).day;
    final rand = math.Random(_month.year * 12 + _month.month);
    final anchorRand = math.Random(777 + _month.month);

    _days = List.generate(count, (i) {
      final date = DateTime(_month.year, _month.month, i + 1);
      final isToday = _iso(date) == todayIso;
      final isFuture = date.isAfter(today) && !isToday;
      return _DaySim(
        dnum: i + 1,
        isToday: isToday,
        isFuture: isFuture,
        checked: !isFuture && !isToday && _checkedDates.contains(_iso(date)),
      );
    });

    // 散落锚点：确定性伪随机 + 倾角（专利特征②）。
    for (final d in _days) {
      d.ax = 0.08 + anchorRand.nextDouble() * 0.84;
      d.ay = 0.10 + anchorRand.nextDouble() * 0.80;
      d.arot = (anchorRand.nextDouble() - 0.5) * 56;
      d.ascale = 0.9 + anchorRand.nextDouble() * 0.5;
      d.wob = anchorRand.nextDouble() * math.pi * 2;
      d.wsp = 0.5 + anchorRand.nextDouble() * 0.7;
      if (_reduceMotion) {
        d.square = 1;
      }
    }

    // 尘粒：每徽章 4 颗（专利特征②氛围层）。
    _dust.clear();
    for (var i = 0; i < _days.length; i++) {
      for (var k = 0; k < 4; k++) {
        _dust.add(
          _OrbitDust(
            part: i,
            ang: (k / 4 + rand.nextDouble() * 0.2) * math.pi * 2,
            rad: 26 + rand.nextDouble() * 30,
            sp: (0.5 + rand.nextDouble() * 0.8) * (rand.nextDouble() > 0.5 ? 1 : -1),
            size: 0.8 + rand.nextDouble() * 1.6,
            color: rand.nextInt(3),
            ph: rand.nextDouble() * math.pi * 2,
          ),
        );
      }
    }
    _ambient.clear();
    for (var i = 0; i < 26; i++) {
      _ambient.add(
        _AmbientDot(
          x: rand.nextDouble() * math.max(1, _stageW),
          y: rand.nextDouble() * math.max(1, _stageH),
          size: 0.6 + rand.nextDouble() * 1.4,
          tw: rand.nextDouble() * math.pi * 2,
          sp: 0.4 + rand.nextDouble() * 0.9,
        ),
      );
    }
    _layoutGrid();
  }

  /// 网格落位目标（同原型：20px 边距、8px 列距、10px 行距、首行 top 32）。
  void _layoutGrid() {
    if (_stageW <= 0) return;
    final cw = (_stageW - 40 - 6 * 8) / 7;
    for (var i = 0; i < _days.length; i++) {
      final col = i % 7, row = i ~/ 7;
      _days[i].tx = 20 + col * (cw + 8) + cw / 2;
      _days[i].ty = 32 + row * (cw + 10) + cw / 2;
    }
  }

  /// 对角波错峰（左上扫向右下，定稿重组顺序）。
  double _diagonalDelay(int i) => (i % 7 + i ~/ 7) * 0.055;

  void _setMode(String mode) {
    if (!mounted) return;
    setState(() {
      _mode = mode;
      if (mode == 'grid') {
        for (var i = 0; i < _days.length; i++) {
          _days[i].assembleAt = _now + (_reduceMotion ? 0 : _diagonalDelay(i));
          if (_reduceMotion) {
            final d = _days[i];
            d.x = d.tx;
            d.y = d.ty;
            d.rot = 0;
            d.scale = 1;
            d.square = 1;
          }
        }
      } else {
        for (final d in _days) {
          d.square = _reduceMotion ? 0 : d.square;
        }
      }
    });
  }

  /// 散开 → 停顿 → 对角波重组（同原型 replay）。
  void _replay() {
    if (_reduceMotion) {
      _setMode('grid');
      return;
    }
    _setMode('scatter');
    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) _setMode('grid');
    });
  }

  void _shiftMonth(int delta) {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta);
    });
    _buildMonth();
    _replay();
  }

  // ── 签到（同原型 doCheckin 时序） ──
  /// 里程碑跨档庆祝：编排收口于 MilestoneCelebration（P2-8），本页只传余额。
  Future<void> _maybeCelebrateMilestone({required int newBalance}) =>
      MilestoneCelebration.celebrateCoin(context: context, newBalance: newBalance, isMounted: () => mounted);

  /// D5/D6：手动补「昨天」——消耗 1 张保护卡，把昨天补进日历并接回连胜。
  ///
  /// 断签不再静默自动补，是否接回由用户在这里决定；补完立刻用补签后的天数
  /// 跑一次 7/14/30/50 里程碑判定（[MilestoneGuard] 只正向、不重复庆祝）。
  Future<void> _doMakeupYesterday() async {
    if (_busy) return;
    final store = context.read<ScareCoinStore>();
    setState(() => _busy = true);
    int? newStreak;
    try {
      newStreak = await store.makeupYesterday();
    } catch (e, s) {
      reportSwallowedError('补签失败', e, s);
    }
    if (!mounted) return;
    setState(() => _busy = false);
    if (newStreak == null) {
      showMwSnackBar(context, const SnackBar(content: Text('没补成：昨天已签到，或保护卡不足')));
      return;
    }
    widget.onChecked?.call();
    await _reload();
    if (!mounted) return;
    unawaited(_maybeCelebrateStreakMilestone(store));
  }

  /// 连胜里程碑（7/14/30/50）：跨档只演一次，存量基线化不补演。
  ///
  /// 只做庆祝：不发币、不做断签惩罚；与金币里程碑共用探头串行防重入，
  /// 被拦下时不落标记，这一档留待下个签到机会补演。
  Future<void> _maybeCelebrateStreakMilestone(ScareCoinStore store) async {
    final streak = await store.streak();
    if (!mounted) return;
    await MilestoneCelebration.celebrateStreak(
      context: context,
      newStreak: streak,
      key: streakMilestonePrefKey,
      thresholds: streakMilestoneDays,
      phraseFor: streakMilestonePhrase,
      isMounted: () => mounted,
    );
  }

  /// 签到成功后的使用统计上报。
  ///
  /// 全部包在 try 里：埋点失败绝不能影响签到本身（账已经落定了）。
  Future<void> _reportCheckInToUsageStats(UsageStatsRecorder recorder, ScareCoinStore store, int reward) async {
    try {
      await recorder.syncStreak(await store.streak());
      await recorder.recordCoinsEarned(reward);
    } catch (e, s) {
      reportSwallowedError('签到埋点上报失败', e, s);
    }
  }

  Future<void> _doCheckIn() async {
    if (_busy || _todayChecked) return;
    final store = context.read<ScareCoinStore>();
    // 埋点端口在 await 前取好：await 之后 context 可能已失效。
    // **可空读取**：本页在最小装配的单测里没有 telemetry scope，不该因此抛
    // ProviderNotFound（与 learn_page 的 ScareCoinStore 同口径）。
    final usageStats = context.read<UsageStatsRecorder?>();
    setState(() => _busy = true);
    // 进化仪式基线：签到前的累计天数快照。不能用「签到后 length-1」近似——
    // 手动补签会补进 1 天历史，-1 不等于签到前的天数，跨档仪式会被误吞。
    var stageBefore = 0;
    try {
      stageBefore = MonsterIcon.stageFor((await store.checkinDates()).length);
    } catch (e, s) {
      reportSwallowedError('签到进化仪式基线读取失败', e, s);
    }
    if (!mounted) return;
    final int? newBalance;
    try {
      newBalance = await store.checkIn();
    } catch (e, s) {
      // 入账失败（database_closed/磁盘错）不得把 _busy 永久卡死——按钮软锁
      // 到重进页面，且用户看不到任何提示。
      reportSwallowedError('签到入账失败', e, s);
      if (mounted) {
        setState(() => _busy = false);
        showMwSnackBar(context, const SnackBar(content: Text('签到失败了，稍后再试一次吧')));
      }
      return;
    }
    if (!mounted) return;
    if (newBalance == null) {
      // 并发已签过：同步状态收尾。
      await _reload();
      if (!mounted) return;
      setState(() => _busy = false);
      return;
    }
    final int awarded = newBalance;
    widget.onChecked?.call();
    final reward = store.checkInReward;
    // 使用统计：签到连击 + 本次获得的尖叫币。
    // 连击用 store.streak() 而不是页面本地的 _streak + 1——权威口径在账本侧，
    // 手动补签接回的连胜等边界下两者并不相等。
    if (usageStats != null) unawaited(_reportCheckInToUsageStats(usageStats, store, reward));
    unawaited(_maybeCelebrateMilestone(newBalance: awarded));
    // 连胜里程碑（7/14/30/50）：只正向庆祝，不发币（奖励额度待产品拍板）。
    unawaited(_maybeCelebrateStreakMilestone(store));
    // 进化仪式检测：checkIn() 返回前今日已写入 checkinDates（写日期先于算余额），
    // 故此刻取的天数已含今天；与基线快照 diff，跨阈值才演出。
    // 读失败只降级为「不演跨档仪式」——账已在上一步落定，绝不因此卡死结算 UI。
    var evolved = false;
    var stageAfter = 0;
    try {
      final datesAfter = await store.checkinDates();
      stageAfter = MonsterIcon.stageFor(datesAfter.length);
      evolved = stageAfter > stageBefore;
    } catch (e, s) {
      reportSwallowedError('签到进化仪式形态读取失败', e, s);
    }
    if (!mounted) return;

    if (_reduceMotion) {
      setState(() {
        _todayChecked = true;
        _streak += 1;
        _balance = awarded;
        _bellyTarget = _pctFor(_streak);
        _busy = false;
      });
      if (evolved && mounted) {
        SfxPlayer.fire(Sfx.evolve);
        EvolutionCeremonyOverlay.show(context, fromStage: stageBefore, toStage: stageAfter);
      }
      return;
    }

    // ① 盖章瞬间：金币迸出 + 光晕 + 胶囊弹跳。
    final todayIdx = _days.indexWhere((d) => d.isToday);
    _burstFrom(todayIdx);
    setState(() {
      _justIndex = todayIdx;
      _justAt = _now;
      _pillPopAt = _now;
    });

    // ② 850ms 后结算（金色盖印 / 计数 / 肚皮上涨 / +N 浮字）。
    Future.delayed(const Duration(milliseconds: 850), () {
      if (!mounted) return;
      setState(() {
        _todayChecked = true;
        _streak += 1;
        _balance = awarded;
        _gainAt = _now;
        _gainValue = reward;
        _bellyTarget = _pctFor(_streak);
      });
      // 进化演出放在结算之后（肚皮/盖印先落定，仪式作为当日高光收尾）。
      if (evolved) {
        SfxPlayer.fire(Sfx.evolve);
        EvolutionCeremonyOverlay.show(context, fromStage: stageBefore, toStage: stageAfter);
      }
    });

    // ③ 散开 → 停顿 → 对角波重组（可反复体验）。
    Future.delayed(const Duration(milliseconds: 600), () => _setMode('scatter'));
    Future.delayed(const Duration(milliseconds: 1900), () => _setMode('grid'));
    Future.delayed(const Duration(milliseconds: 2800), () {
      if (mounted) setState(() => _busy = false);
    });
  }

  /// 22 枚金币自今日徽章迸出（专利特征③）。
  void _burstFrom(int idx) {
    if (idx < 0) return;
    final d = _days[idx];
    final sx0 = _stageOrigin.dx + d.x;
    final sy0 = _stageOrigin.dy + d.y;
    for (var i = 0; i < 22; i++) {
      _burst.add(
        _BurstCoin(
          sx: sx0 + (_rnd.nextDouble() - 0.5) * 30,
          sy: sy0 + (_rnd.nextDouble() - 0.5) * 30,
          cx: sx0 + (_rnd.nextDouble() - 0.5) * 160,
          cy: math.min(sy0, _bellyPoint.dy) - 20 - _rnd.nextDouble() * 80,
          t0: _now + i * 0.024,
          dur: 0.56 + _rnd.nextDouble() * 0.26,
          size: 2 + _rnd.nextDouble() * 2.6,
          color: _rnd.nextInt(3),
        ),
      );
    }
  }

  // ── 主循环（弹簧 + 粒子推进，同原型 loop） ──
  void _onTick(Duration elapsed) {
    final now = elapsed.inMicroseconds / 1e6;
    final dt = (now - _now).clamp(0.0, 0.034);
    _now = now;
    final t = now;
    final assembled = _mode == 'grid';

    // 徽章弹簧是否仍在收敛（性能审计 P2：收敛后可停全页 setState）。
    var springActive = !assembled;
    for (var i = 0; i < _days.length; i++) {
      final d = _days[i];
      final ready = assembled && now >= d.assembleAt;
      double tx, ty, trot, tscale, k, dampC;
      if (ready) {
        tx = d.tx;
        ty = d.ty;
        trot = 0;
        tscale = 1;
        k = 110;
        dampC = 11;
      } else {
        tx = d.ax * _stageW + math.sin(t * d.wsp + d.wob) * 9;
        ty = d.ay * _stageH + math.cos(t * d.wsp * 0.8 + d.wob) * 8;
        trot = d.arot + math.sin(t * d.wsp + d.wob) * 5;
        tscale = d.ascale;
        k = 16;
        dampC = 4.5;
      }
      final damp = math.exp(-dampC * dt);
      d.vx = (d.vx + (tx - d.x) * k * dt) * damp;
      d.vy = (d.vy + (ty - d.y) * k * dt) * damp;
      d.vrot = (d.vrot + (trot - d.rot) * 90 * dt) * math.exp(-9 * dt);
      d.vscale = (d.vscale + (tscale - d.scale) * 110 * dt) * math.exp(-10 * dt);
      d.x += d.vx * dt;
      d.y += d.vy * dt;
      d.rot += d.vrot * dt;
      d.scale += d.vscale * dt;
      d.square = ready ? ((now - d.assembleAt - 0.15) / 0.45).clamp(0.0, 1.0) : 0.0;
      // 收敛判据（阈值按舞台像素量级取，远小于可视差）。
      if (springActive ||
          d.vx.abs() > 0.5 ||
          d.vy.abs() > 0.5 ||
          d.vrot.abs() > 0.1 ||
          (tx - d.x).abs() > 0.25 ||
          (ty - d.y).abs() > 0.25) {
        springActive = true;
      }
    }

    // 肚皮充盈度平滑趋近目标。
    _bellyPct += (_bellyTarget - _bellyPct) * math.min(1, 3 * dt);

    // 尘粒：散落环绕 / 聚合螺旋吸入。
    for (final p in _dust) {
      if (assembled) {
        p.rad *= 1 - 1.6 * dt;
        p.ang += (2.6 + (60 - p.rad) * 0.06) * dt;
        final target = 0.4 * (p.rad / 30).clamp(0.0, 1.0);
        p.alpha += (target - p.alpha) * 3 * dt;
        if (p.rad < 3) {
          p.rad = 34 + _rnd.nextDouble() * 26;
          p.alpha = 0;
        }
      } else {
        p.ang += p.sp * dt;
        p.rad = 26 + math.sin(t * 0.9 + p.ph) * 6;
        p.alpha += (0.8 - p.alpha) * 3 * dt;
      }
    }
    for (final a in _ambient) {
      a.tw += a.sp * dt;
    }

    // 金币弹道推进 + 到达 bump（节流 160ms）。
    for (var i = _burst.length - 1; i >= 0; i--) {
      final c = _burst[i];
      if (now >= c.t0 + c.dur) {
        _burst.removeAt(i);
        if (now - _lastBumpAt >= 0.16) {
          _lastBumpAt = now;
          _bumpT = 0;
        }
      }
    }
    _bumpT += dt;

    // 反向喷币推进（离线计息结算）：到点即移除，bump 由结算时一次性触发。
    for (var i = _spray.length - 1; i >= 0; i--) {
      if (now >= _spray[i].t0 + _spray[i].dur) _spray.removeAt(i);
    }

    // 全页重建只在「有 UI 在动」时发生：busy（签到结算）/散落模式/金币弹道/
    // 肚皮趋近/+N 浮字/罐体 bump/徽章弹簧。全部收敛后仅重绘粒子层
    // （_fxSignal + RepaintBoundary），页面停留期间不再 60fps 整页 setState。
    final uiActive =
        _busy ||
        _mode != 'grid' ||
        _burst.isNotEmpty ||
        _spray.isNotEmpty ||
        (_bellyTarget - _bellyPct).abs() > 0.001 ||
        (_now - _gainAt) < 1.0 ||
        _bumpT < 0.7 ||
        springActive;
    if (!mounted) return;
    _fxSignal.fire();
    if (uiActive) setState(() {});
  }

  // ── 几何缓存（舞台原点 / 罐口） ──
  void _computeGeometry() {
    final stageBox = _stageKey.currentContext?.findRenderObject() as RenderBox?;
    final piggyBox = _piggyKey.currentContext?.findRenderObject() as RenderBox?;
    final root = context.findRenderObject() as RenderBox?;
    if (stageBox != null && root != null) {
      _stageOrigin = stageBox.localToGlobal(Offset.zero, ancestor: root);
      if (stageBox.hasSize && (stageBox.size.width != _stageW || stageBox.size.height != _stageH)) {
        _stageW = stageBox.size.width;
        _stageH = stageBox.size.height;
        _layoutGrid();
        // 重建氛围微尘的分布范围。
        if (_ambient.isNotEmpty) {
          final rand = math.Random(_month.year * 12 + _month.month);
          for (final a in _ambient) {
            a
              ..x = rand.nextDouble() * _stageW
              ..y = rand.nextDouble() * _stageH;
          }
        }
        // 减弱动效模式下无 Ticker 驱动，需显式触发重建刷新落位。
        if (_reduceMotion && mounted) setState(() {});
      }
    }
    if (piggyBox != null && root != null) {
      final origin = piggyBox.localToGlobal(Offset.zero, ancestor: root);
      _bellyPoint = Offset(origin.dx + piggyBox.size.width / 2, origin.dy + 88);
    }
  }

  _BadgeKind _kindOf(_DaySim d) {
    if (d.checked || (d.isToday && _todayChecked)) return _BadgeKind.checked;
    if (d.isToday) return _BadgeKind.today;
    if (d.isFuture) return _BadgeKind.future;
    return _BadgeKind.plain;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        // 暖纸色固定底（专利要点：不随明暗主题切换）。
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [TreasurePalette.paperTop, TreasurePalette.paper, TreasurePalette.paperBottom],
            stops: [0, 0.55, 1],
          ),
        ),
        child: Stack(
          children: [
            SafeArea(
              bottom: false,
              child: Column(
                children: [
                  _buildTopBar(),
                  _buildMonthBar(),
                  Expanded(child: _buildStage()),
                  _buildBottom(),
                ],
              ),
            ),
            // 粒子层（尘粒 + 金币弹道），覆盖全页：徽章散落区与罐口同坐标系。
            // 重绘由 _fxSignal 经 RepaintBoundary 直驱——只重绘本层，
            // 不再牵动徽章/储蓄罐/CTA 整页重建（性能审计 P2）。
            if (!_reduceMotion)
              Positioned.fill(
                child: IgnorePointer(
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: _FxPainter(state: this, repaint: _fxSignal),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Ticker 每帧通知一次的自定义 Listenable（不用 ChangeNotifier：notifyListeners
/// 是 @protected 成员，State 外调用属违规；此处是受控的帧信号语义）。
class _TickSignal extends ChangeNotifier {
  void fire() => notifyListeners();
}
