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
// 位置说明：widgets 层消费 feature application 端口（R-widgets 放行），
// 首页经 widgets 层打开本页，规避 R4 跨功能 import 禁令。
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';

import 'package:word_app/features/scare_coin/application/scare_coin_store.dart';
import 'package:word_app/tokens/design_tokens.dart';
import 'package:word_app/tokens/treasure_palette.dart';

part 'treasure_checkin_painters.dart';

/// 单枚日期徽章的弹簧模拟状态。
class _DaySim {
  _DaySim({required this.dnum, required this.isToday, required this.isFuture, required this.checked});

  final int dnum;
  final bool isToday;
  final bool isFuture;
  bool checked;

  // 散落锚点（舞台相对 0~1 + 漂浮参数）。
  double ax = 0.5, ay = 0.5, arot = 0, ascale = 1, wob = 0, wsp = 1;
  // 网格落位目标（舞台坐标，中心定位）。
  double tx = 0, ty = 0;
  // 当前状态。
  double x = 0, y = 0, rot = 0, scale = 1, vx = 0, vy = 0, vrot = 0, vscale = 0;
  // 聚合开始时刻（秒）；散落态无意义。
  double assembleAt = 0;
  // 花齿 ⇄ 方章交叉渐隐进度 0~1。
  double square = 0;
}

/// 金币弹道（二次贝塞尔 + smoothstep，同原型 burst）。
class _BurstCoin {
  _BurstCoin({
    required this.sx,
    required this.sy,
    required this.cx,
    required this.cy,
    required this.t0,
    required this.dur,
    required this.size,
    required this.color,
  });

  final double sx, sy, cx, cy, t0, dur, size;
  final int color;
}

/// 环绕徽章的尘粒。
class _OrbitDust {
  _OrbitDust({
    required this.part,
    required this.ang,
    required this.rad,
    required this.sp,
    required this.size,
    required this.color,
    required this.ph,
  });

  final int part;
  double ang;
  double rad;
  final double sp, size, ph;
  final int color;
  double alpha = 0;
}

/// 氛围微尘。
class _AmbientDot {
  _AmbientDot({required this.x, required this.y, required this.size, required this.tw, required this.sp});

  double x, y;
  final double size, sp;
  double tw;
}

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

    if (_reduceMotion) {
      setState(() {
        _todayChecked = true;
        _streak += 1;
        _balance = newBalance;
        _bellyTarget = _pctFor(_streak);
        _busy = false;
      });
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

  // ── 顶部胶囊：连击 / 余额 ──
  Widget _buildTopBar() {
    const popDur = 0.5;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      child: Builder(
        builder: (context) {
          final pt = _now - _pillPopAt;
          final pop = pt >= 0 && pt < popDur ? math.sin(math.pi * pt / popDur) : 0.0;
          final flameScale = 1.0 + 0.35 * pop;
          final numScale = 1.0 + 0.45 * pop;
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _pill(
                children: [
                  Transform.rotate(
                    angle: -0.14 * pop,
                    child: Transform.scale(
                      scale: flameScale,
                      child: const Icon(Icons.local_fire_department_rounded, size: 17, color: TreasurePalette.coral),
                    ),
                  ),
                  const SizedBox(width: 7),
                  Text('连续 ', style: _pillStyle()),
                  Transform.scale(
                    scale: numScale,
                    child: Text('$_streak', style: _pillStyle(color: pop > 0.4 ? TreasurePalette.goldDeep : null)),
                  ),
                  Text(' 天', style: _pillStyle()),
                ],
              ),
              _pill(
                children: [
                  const _CoinGlyph(size: 16),
                  const SizedBox(width: 7),
                  Transform.scale(
                    scale: numScale,
                    child: Text('$_balance', style: _pillStyle(color: pop > 0.4 ? TreasurePalette.goldDeep : null)),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  TextStyle _pillStyle({Color? color}) => MwTypography.caption.copyWith(
    fontWeight: FontWeight.w700,
    letterSpacing: 0.02,
    color: color ?? TreasurePalette.ink,
  );

  Widget _pill({required List<Widget> children}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    decoration: BoxDecoration(
      color: TreasurePalette.card,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      border: Border.all(color: TreasurePalette.line),
      boxShadow: [BoxShadow(color: TreasurePalette.pillShadow, blurRadius: 10, offset: const Offset(0, 3))],
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: children),
  );

  // ── 月份栏 ──
  Widget _buildMonthBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _navBtn(Icons.chevron_left, () => _shiftMonth(-1)),
          const SizedBox(width: 18),
          Column(
            children: [
              Text(
                '${_month.year} 年 ${_month.month} 月',
                style: MwTypography.titleLg.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.04,
                  color: TreasurePalette.ink,
                ),
              ),
              Text(
                '聚宝日历',
                style: MwTypography.micro.copyWith(
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.12,
                  color: TreasurePalette.dim,
                ),
              ),
            ],
          ),
          const SizedBox(width: 18),
          _navBtn(Icons.chevron_right, () => _shiftMonth(1)),
        ],
      ),
    );
  }

  Widget _navBtn(IconData icon, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: TreasurePalette.card,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: TreasurePalette.line),
      ),
      child: Icon(icon, size: 16, color: TreasurePalette.ink),
    ),
  );

  // ── 日历舞台 ──
  Widget _buildStage() {
    const weekLabels = ['一', '二', '三', '四', '五', '六', '日'];
    return LayoutBuilder(
      builder: (context, constraints) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _computeGeometry());
        return Stack(
          key: _stageKey,
          children: [
            // 星期行（聚合后淡入）。
            Positioned(
              top: 4,
              left: 20,
              right: 20,
              child: IgnorePointer(
                child: AnimatedOpacity(
                  opacity: _mode == 'grid' ? 1 : 0,
                  duration: const Duration(milliseconds: 500),
                  child: Row(
                    children: [
                      for (var i = 0; i < 7; i++)
                        Expanded(
                          child: Text(
                            weekLabels[i],
                            textAlign: TextAlign.center,
                            style: MwTypography.micro.copyWith(
                              fontWeight: FontWeight.w700,
                              letterSpacing: 2.2,
                              color: i == 6 ? TreasurePalette.coral : TreasurePalette.dim,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            // 日期徽章（绝对定位 + 弹簧变换）。
            for (var i = 0; i < _days.length; i++)
              Builder(
                builder: (context) {
                  final d = _days[i];
                  return Positioned(
                    left: d.x - 22,
                    top: d.y - 22,
                    width: 44,
                    height: 44,
                    child: Transform.rotate(
                      angle: d.rot * math.pi / 180,
                      child: Transform.scale(
                        scale: d.scale,
                        child: GestureDetector(
                          onTap: d.isToday ? _doCheckIn : null,
                          child: _SealBadge(
                            kind: _kindOf(d),
                            num: d.dnum,
                            squareness: d.square,
                            glowAlpha: i == _justIndex ? _glowValue(_now - _justAt) : 0,
                            reduceMotion: _reduceMotion,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
          ],
        );
      },
    );
  }

  /// 盖章光晕强度（同原型 stampIn：0→35% 升到 0.9 → 消散）。
  double _glowValue(double t) {
    if (t < 0 || t > 0.55) return 0;
    return t < 0.2 ? (t / 0.2) * 0.9 : 0.9 * (1 - (t - 0.2) / 0.35);
  }

  // ── 底部：储蓄罐 + CTA ──
  Widget _buildBottom() {
    return SafeArea(
      top: false,
      child: Column(
        children: [
          SizedBox(
            width: 220,
            height: 128,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Builder(
                  builder: (context) {
                    // bump：scale(1)→(1.14,.9)@35% →(.96,1.1)@65% →(1)，节流由金币到达触发。
                    double sx = 1, sy = 1;
                    if (_bumpT < 0.55) {
                      final t = _bumpT / 0.55;
                      if (t < 0.35) {
                        sx = 1 + 0.14 * (t / 0.35);
                        sy = 1 - 0.10 * (t / 0.35);
                      } else if (t < 0.65) {
                        final u = (t - 0.35) / 0.3;
                        sx = 1.14 - 0.18 * u;
                        sy = 0.9 + 0.20 * u;
                      } else {
                        final u = (t - 0.65) / 0.35;
                        sx = 0.96 + 0.04 * u;
                        sy = 1.10 - 0.10 * u;
                      }
                    }
                    return Transform.scale(
                      scale: sx,
                      alignment: const Alignment(0, 0.5), // 原点 (110,96)
                      child: Transform.scale(
                        scale: sy,
                        alignment: const Alignment(0, 0.5),
                        child: CustomPaint(
                          key: _piggyKey,
                          size: const Size(220, 128),
                          painter: _PiggyPainter(bellyPct: _bellyPct),
                        ),
                      ),
                    );
                  },
                ),
                // +N 浮字（0.9s 上浮淡出）。
                Positioned(
                  left: 0,
                  right: 0,
                  top: 6,
                  child: IgnorePointer(
                    child: Builder(
                      builder: (context) {
                        final t = _now - _gainAt;
                        if (t < 0 || t > 0.9) return const SizedBox.shrink();
                        final u = t / 0.9;
                        final opacity = u < 0.25 ? u / 0.25 : 1 - (u - 0.25) / 0.75;
                        final scale = u < 0.25 ? 0.7 + 0.45 * (u / 0.25) : 1.15 - 0.15 * ((u - 0.25) / 0.75);
                        return Opacity(
                          opacity: opacity.clamp(0.0, 1.0),
                          child: Transform.scale(
                            scale: scale,
                            child: Text(
                              '+$_gainValue',
                              textAlign: TextAlign.center,
                              style: MwTypography.bodyMd.copyWith(
                                fontWeight: FontWeight.w900,
                                color: TreasurePalette.gainText,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          _buildCta(),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildCta() {
    final checked = _todayChecked;
    final busy = _busy;
    return GestureDetector(
      onTap: (checked || busy) ? null : _doCheckIn,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 46, vertical: 15),
        decoration: BoxDecoration(
          gradient: checked
              ? const LinearGradient(colors: [TreasurePalette.ctaDisabledTop, TreasurePalette.ctaDisabledBottom])
              : const LinearGradient(
                  colors: [TreasurePalette.greenLight, TreasurePalette.green, TreasurePalette.greenDark],
                  stops: [0, 0.55, 1],
                ),
          borderRadius: BorderRadius.circular(AppRadius.pill),
          boxShadow: checked
              ? null
              : [BoxShadow(color: TreasurePalette.ctaShadow, blurRadius: 22, offset: const Offset(0, 8))],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!checked) ...[const _CoinGlyph(size: 18, creamStyle: true), const SizedBox(width: 10)],
            Text(
              checked ? '今日已签到 · 明天再来' : '立即签到 · +$_reward',
              style: MwTypography.bodyMd.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: 1.3,
                color: TreasurePalette.cream,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
