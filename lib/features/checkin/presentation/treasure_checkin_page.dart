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
import 'package:word_app/tokens/motion_tokens.dart';

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';

import 'package:word_app/features/scare_coin/application/scare_coin_store.dart';
import 'package:word_app/tokens/design_tokens.dart';
import 'package:word_app/tokens/treasure_palette.dart';
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
  const TreasureCheckInPage({super.key, this.onChecked});

  /// 签到成功回调（供外部刷新余额等）。
  final VoidCallback? onChecked;

  @override
  State<TreasureCheckInPage> createState() => _TreasureCheckInPageState();
}

class _TreasureCheckInPageState extends State<TreasureCheckInPage> with SingleTickerProviderStateMixin {
  // ── 数据 ──
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  bool _todayChecked = false;
  bool _busy = false;
  int _streak = 0;
  int _balance = 0;
  int _reward = 0;

  // ── 模拟 ──
  late final Ticker _ticker = createTicker(_onTick);
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
    super.dispose();
  }

  String _iso(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Set<String> _checkedDates = {};

  Future<void> _reload({bool replay = false}) async {
    final store = context.read<ScareCoinStore>();
    final results = await Future.wait([store.checkinDates(), store.streak(), store.balance()]);
    if (!mounted) return;
    setState(() {
      _checkedDates = results[0] as Set<String>;
      _streak = results[1] as int;
      _balance = results[2] as int;
      _reward = store.checkInReward;
      _todayChecked = _checkedDates.contains(_iso(DateTime.now()));
      _bellyTarget = _pctFor(_streak);
      _bellyPct = _bellyTarget;
    });
    _buildMonth();
    if (replay) _replay();
  }

  /// 连击 → 肚皮充盈度（原型标定：(streak+12)/30）。
  double _pctFor(int streak) => ((streak + 12) / 30).clamp(0.0, 1.0);

  // ── 月份构建 ──
  void _buildMonth() {
    final today = DateTime.now();
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
  Future<void> _doCheckIn() async {
    if (_busy || _todayChecked) return;
    final store = context.read<ScareCoinStore>();
    setState(() => _busy = true);
    final newBalance = await store.checkIn();
    if (!mounted) return;
    if (newBalance == null) {
      // 并发已签过：同步状态收尾。
      await _reload();
      if (!mounted) return;
      setState(() => _busy = false);
      return;
    }
    widget.onChecked?.call();
    final reward = store.checkInReward;
    // 进化仪式检测：checkIn() 返回前今日已写入 checkinDates（写日期先于算余额），
    // 故此刻取的天数已含今天；与本次签到前快照 diff，跨阈值才演出。
    final datesAfter = await store.checkinDates();
    final stageBefore = MonsterIcon.stageFor(datesAfter.length - 1);
    final stageAfter = MonsterIcon.stageFor(datesAfter.length);
    final evolved = stageAfter > stageBefore;

    if (_reduceMotion) {
      setState(() {
        _todayChecked = true;
        _streak += 1;
        _balance = newBalance;
        _bellyTarget = _pctFor(_streak);
        _busy = false;
      });
      if (evolved && mounted) {
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
        _balance = newBalance;
        _gainAt = _now;
        _gainValue = reward;
        _bellyTarget = _pctFor(_streak);
      });
      // 进化演出放在结算之后（肚皮/盖印先落定，仪式作为当日高光收尾）。
      if (evolved) {
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

    if (mounted) setState(() {});
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
            // 重建由主循环 setState 驱动（Ticker 非 Listenable）。
            if (!_reduceMotion)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(painter: _FxPainter(state: this)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
