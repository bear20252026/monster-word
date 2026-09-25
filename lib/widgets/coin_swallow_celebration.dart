// CoinSwallowCelebration：签到成功庆祝 — “巨币天降＋满意饱嗝”
//
// 五幕 2400ms：①临（巨币旋转从天而降，边转边缩小）；②吞（缩入兽嘴，
// 咕咚波纹）；③嗝（腮帮鼓起＋“嗝~”气泡＋声波圈＋肚皮抖）；④存（光点沉底、
// 肚皮鼓胀、金库窗弹出并滚动到最新余额）；⑤乐（星芒迸发、欢腾一跃、+N 上浮）。
//
// 人机交互三处（点一下看动画之外）：
//  - 点巨币：转速爆发＋币身 wobble（巨币阶段）；
//  - 拖巨币：60px 弹性牵引，松手弹回轨迹（巨币阶段）；
//  - 戳怪兽：满足阶段戳肚皮→咯咯一缩＋三颗小星（彩蛋）。
// 点空白处跳过仪式；播完经 onDone 自清，不常驻、不持有静态单例。
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:word_app/theme/skin_system.dart';
import 'package:word_app/tokens/design_tokens.dart';
import 'package:word_app/tokens/effect_palette.dart';
import 'package:word_app/tokens/motion_tokens.dart';
import 'package:word_app/tokens/star_gold.dart';
import 'package:word_app/widgets/monster_icon.dart';

// ── 版式常量（widget 与粒子画笔同源，避免嘴／币错位） ──
const double _kBoxH = 220.0;
const double _kMonster = 128.0;
const double _kHalfMonster = _kMonster / 2; // 64
const double _kR = _kHalfMonster * 0.85; // 54.4，与 _MonsterPainter 同源
const double _kMonsterTop = _kBoxH - _kMonster; // 92
const double _kMouthY = _kMonsterTop + _kHalfMonster + _kR * 0.22; // ≈168
const double _kBellyY = _kMonsterTop + _kHalfMonster + _kR * 0.25; // ≈170
const double _kSinkY = _kBellyY + 18.0; // 光点沉底 ≈188
const double _kBurstY = _kMonsterTop + 70.0; // 星芒中心 ≈162
// 巨币：从天而降，300 整币 → 56 入嘴。
const double _kGiantSize = 300.0;
const double _kCoinEndSize = 56.0;
const double _kGiantStartY = 30.0; // 币心起始（盒顶附近，大币溢出如从天来）
const double _kLeashR = 60.0; // 拖拽牵引半径

class CoinSwallowCelebration extends StatefulWidget {
  /// 本次签到增量（== ScareCoinStore.checkInReward）。
  final int reward;

  /// 签到后最新余额（ScareCoinStore.checkIn() 返回值），金库窗滚动终点。
  final int balance;

  /// 续演起点：亲手投喂成功后从 0.36（币已到嘴）续演后四幕；点按自动为 0。
  final double startAt;

  /// 怪兽进化阶段（0 奶泡／1 尖角／2 飞翼／3 金冠），按累计签到换算。
  final int evoStage;

  /// 肚皮生长基线（1.0~1.25），与仪式鼓胀相乘，越养越大。
  final double growthBase;

  final VoidCallback? onDone;

  const CoinSwallowCelebration({
    super.key,
    required this.reward,
    required this.balance,
    this.onDone,
    this.startAt = 0.0,
    this.evoStage = 0,
    this.growthBase = 1.0,
  });

  @override
  State<CoinSwallowCelebration> createState() => _CoinSwallowCelebrationState();
}

class _CoinSwallowCelebrationState extends State<CoinSwallowCelebration> with TickerProviderStateMixin {
  static const _total = Duration(milliseconds: 2400);
  late final AnimationController _ctrl;

  /// 松手牵引回弹（300ms elasticOut，自驱 setState，播完即停）。
  late final AnimationController _leash;
  Tween<Offset>? _leashTween;

  /// 拖拽偏移（盒坐标像素，巨币阶段有效，随阶段收尾自动淡出影响）。
  Offset _drag = Offset.zero;

  /// 点币加速时刻表（_ctrl.value 采样，多点累加，保留最近 6 次）。
  final List<double> _boosts = [];
  double _lastTap = -1;

  /// 戳肚皮时刻表（满足阶段彩蛋）。
  final List<double> _pokes = [];

  /// 触觉已触发标记（时间线单调递增，跳过时和弦齐震亦可接受）。
  bool _buzzGulp = false;
  bool _buzzBurp = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: _total)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) widget.onDone?.call();
      })
      // 亲手投喂续演：从币到嘴处开始，forward() 从当前值播到终点。
      ..value = widget.startAt.clamp(0.0, 0.9)
      ..forward();
    _leash = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _leash.addListener(() {
      final tw = _leashTween;
      if (tw == null || !mounted) return;
      setState(() => _drag = tw.transform(Curves.elasticOut.transform(_leash.value)));
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _leash.dispose();
    super.dispose();
  }

  static double _seg(double t, double from, double to) => ((t - from) / (to - from)).clamp(0.0, 1.0);
  static double _easeOutCubic(double x) => 1 - math.pow(1 - x, 3).toDouble();
  static double _easeInOutCubic(double x) => x < 0.5 ? 4 * x * x * x : 1 - math.pow(-2 * x + 2, 3).toDouble() / 2;
  // 徽标出现一律走公司标准弹性曲线 MotionCurves.springPop（星巴克复选框弹性同族）。

  static String _fmt(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  /// 点币：转速爆发（巨币阶段）；戳兽：咯咯一缩（满足阶段）。
  void _boostCoin(double t) {
    HapticFeedback.lightImpact();
    setState(() {
      _boosts.add(t);
      if (_boosts.length > 6) _boosts.removeRange(0, _boosts.length - 6);
      _lastTap = t;
    });
  }

  void _pokeMonster(double t) {
    HapticFeedback.lightImpact();
    setState(() {
      _pokes.add(t);
      if (_pokes.length > 3) _pokes.removeRange(0, _pokes.length - 3);
    });
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin.colors;
    final accent = skin.accent;
    final oldBalance = math.max(0, widget.balance - widget.reward);
    return SizedBox(
      height: _kBoxH,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          final t = _ctrl.value;
          final giantT = _seg(t, 0.0, 0.35);
          final swallowT = _seg(t, 0.35, 0.47);
          final burpT = _seg(t, 0.47, 0.68);
          final storeT = _seg(t, 0.60, 0.80);
          // 金库窗／+N 出场均用标准 springPop（选中/确认家族），上限钳制防过冲穿帮。
          final vaultScale = MotionCurves.springPop.transform(_seg(t, 0.62, 0.80)).clamp(0.0, 1.15);
          final countP = _easeOutCubic(_seg(t, 0.64, 0.90));
          final burstT = _seg(t, 0.78, 1.0);
          final plusT = _seg(t, 0.80, 1.0);

          final approachEase = _easeInOutCubic(giantT);
          // 嘴：迎币渐张 → 闭嘴吞 → 嗝成 O 形 → 复位。
          final mouthOpen = giantT < 1
              ? giantT * giantT
              : swallowT < 1
              ? 1 - swallowT
              : math.sin(math.min(burpT, 1.0) * math.pi) * 0.55;
          final cheekPuff = math.sin(math.min(burpT, 1.0) * math.pi);
          final crouch = math.sin(giantT * math.pi); // 巨币压境：微微下蹲蓄势
          final gulpPulse = math.sin(swallowT * math.pi);
          // 肚皮：鼓胀即存款，叠加饱嗝三连抖。
          final bellyScale = 1 + 0.38 * _easeOutCubic(storeT) + 0.05 * math.sin(burpT * math.pi * 3) * (1 - burpT);
          final hopY = -9 * math.sin(_seg(t, 0.78, 0.97) * math.pi); // 欢腾一跃
          // 饱嗝身摇：±0.045 弧度四连晃，随嗝收尾。
          final wiggle = 0.045 * math.sin(burpT * math.pi * 4) * (1 - burpT);

          var sx = (1 + 0.03 * crouch) * (1 + 0.07 * gulpPulse);
          var sy = (1 - 0.04 * crouch) * (1 - 0.07 * gulpPulse);
          // 戳肚皮咯咯缩（满足阶段彩蛋）。
          double pokeP = -1;
          if (_pokes.isNotEmpty) {
            final p = (t - _pokes.last) / 0.35;
            if (p >= 0 && p <= 1) pokeP = p;
          }
          if (pokeP >= 0) {
            final gig = math.sin(pokeP * math.pi);
            sx *= 1 + 0.08 * gig;
            sy *= 1 - 0.08 * gig;
          }

          // ── 巨币：尺寸／落点／旋转／点按加速／拖拽牵引 ──
          final coinSize = t < 0.35
              ? _kGiantSize + (_kCoinEndSize - _kGiantSize) * approachEase
              : _kCoinEndSize * (1 - swallowT);
          final coinCy = t < 0.35 ? _kGiantStartY + (_kMouthY - _kGiantStartY) * approachEase : _kMouthY;
          var spinA = giantT * 4 * math.pi;
          for (final b in _boosts) {
            if (t > b) spinA += 4 * math.pi * (1 - math.exp(-(t - b) * 4));
          }
          final wob = t > _lastTap ? math.sin((t - _lastTap) * 20) * math.exp(-(t - _lastTap) * 6) * 0.18 : 0.0;
          final coinOpacity = t < 0.44 ? 1.0 : (1 - (t - 0.44) / 0.03).clamp(0.0, 1.0);
          final coinVisible = coinSize > 1.5 && coinOpacity > 0;
          // 拖拽影响随巨币阶段收尾淡出，吞咽时币必在嘴心。
          final dragFade = _drag * (1 - giantT);
          final inGiant = giantT < 1;
          final canPoke = t > 0.78 && t < 1;

          final shown = (oldBalance + (widget.balance - oldBalance) * countP).round();
          final rise = plusT * plusT * (3 - 2 * plusT); // smoothstep 上升
          final plusScale = (0.6 + 0.5 * MotionCurves.springPop.transform(plusT)).clamp(0.7, 1.15);
          // 嗝气泡：springPop 弹出＋上浮＋淡出。
          final bubT = _seg(burpT, 0.05, 1.0);
          final bubScale = MotionCurves.springPop.transform(_seg(burpT, 0.05, 0.35)).clamp(0.0, 1.12);
          // 触觉：吞咽落定轻震，嗝气泡弹出中震（构建内单调触发一次）。
          if (swallowT >= 1 && !_buzzGulp) {
            _buzzGulp = true;
            HapticFeedback.lightImpact();
          }
          if (bubScale > 0.5 && !_buzzBurp) {
            _buzzBurp = true;
            HapticFeedback.mediumImpact();
          }

          return GestureDetector(
            // 点空白跳过：2400ms 仪式过长时用户可一触收尾（动效时长合规缓释）。
            // 币／兽上的手势优先竞争，同点冲突时子级胜出。
            behavior: HitTestBehavior.opaque,
            onTap: () {
              if (_ctrl.status == AnimationStatus.forward) _ctrl.value = 1.0;
            },
            child: Stack(
              // 巨币自盒顶溢出，需溢出绘制。
              clipBehavior: Clip.none,
              alignment: Alignment.topCenter,
              children: [
                // 舞台柔光：签到时刻的追光
                Positioned(
                  top: _kMonsterTop - 46,
                  child: Container(
                    width: 216,
                    height: 216,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(colors: [accent.withValues(alpha: 0.14), accent.withValues(alpha: 0.0)]),
                    ),
                  ),
                ),
                // 粒子层（纯装饰，语义树排除）
                Positioned.fill(
                  child: ExcludeSemantics(
                    child: CustomPaint(
                      painter: _VaultFxPainter(
                        approachEase: approachEase,
                        approachT: giantT,
                        swallowT: swallowT,
                        sinkT: _seg(t, 0.44, 0.58),
                        burpT: burpT,
                        burstT: burstT,
                        storeGlow:
                            _easeOutCubic(storeT) *
                            (1 - burstT * 0.4) *
                            // 心跳：辉光在存款段起伏一次
                            (0.8 + 0.2 * math.sin(_seg(t, 0.60, 0.80) * math.pi * 2).abs()),
                        coinSize: coinSize,
                        coinCy: coinCy,
                        spinA: spinA,
                        pokeP: pokeP,
                        gold: MwColors.sunshine300,
                        accent: accent,
                        white: AppColors.white100,
                      ),
                    ),
                  ),
                ),
                // 怪兽（置底居中，欢腾上跃＋饱嗝身摇；戳肚皮咯咯缩）
                Positioned(
                  bottom: hopY,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: canPoke ? (_) => _pokeMonster(t) : null,
                    child: Transform.rotate(
                      angle: wiggle,
                      child: Transform.scale(
                        scaleX: sx,
                        scaleY: sy,
                        child: MonsterIcon(
                          size: _kMonster,
                          mouthOpen: mouthOpen,
                          bellyScale: (bellyScale * widget.growthBase).clamp(0.6, 1.8),
                          evoStage: widget.evoStage,
                          cheekPuff: cheekPuff,
                        ),
                      ),
                    ),
                  ),
                ),
                // 巨币（可点加速＋可拖晃动，仅巨币阶段响应）
                if (coinVisible)
                  Positioned.fill(
                    child: Align(
                      alignment: Alignment(0, (coinCy - _kBoxH / 2) / (_kBoxH / 2)),
                      child: Transform.translate(
                        offset: dragFade,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTapDown: inGiant ? (_) => _boostCoin(t) : null,
                          onPanStart: inGiant
                              ? (_) {
                                  _leash.stop();
                                }
                              : null,
                          onPanUpdate: inGiant
                              ? (d) {
                                  final next = _drag + d.delta;
                                  const max = _kLeashR;
                                  final len = next.distance;
                                  setState(() => _drag = len <= max ? next : next / len * max);
                                }
                              : null,
                          onPanEnd: inGiant
                              ? (_) {
                                  _leashTween = Tween(begin: _drag, end: Offset.zero);
                                  _leash.forward(from: 0);
                                }
                              : null,
                          child: Transform.scale(
                            scaleX: 1 + wob,
                            scaleY: 1 - wob,
                            child: Transform(
                              transform: Matrix4.rotationY(spinA)..rotateZ(0.12 * math.sin(giantT * math.pi * 2)),
                              alignment: Alignment.center,
                              child: CoinBadge(size: coinSize.clamp(8.0, _kGiantSize)),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                // 点币小抄：巨币阶段 fading 提示玩法
                if (inGiant)
                  Positioned(
                    top: 2,
                    child: Opacity(
                      opacity: (1 - giantT).clamp(0.0, 1.0),
                      child: Text('点一点转更快 · 拖一拖晃一晃', style: MwTypography.micro.copyWith(color: skin.text3)),
                    ),
                  ),
                // 嗝气泡
                if (bubT > 0 && bubT < 1)
                  Positioned.fill(
                    child: Align(
                      alignment: Alignment(0.62, 0.055 - bubT * 0.3),
                      child: Opacity(
                        opacity: (1 - _seg(burpT, 0.6, 1.0)).clamp(0.0, 1.0),
                        child: Transform.scale(
                          scale: bubScale,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: AppColors.white100,
                              borderRadius: BorderRadius.circular(AppRadius.pill),
                              border: Border.all(color: MwColors.sunshine300, width: 1.5),
                              boxShadow: [
                                BoxShadow(
                                  color: MwColors.sunshine300.withValues(alpha: 0.4),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Text(
                              '嗝~',
                              style: MwTypography.bodySm.copyWith(fontWeight: FontWeight.w800, color: skin.text1),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                // 肚皮金库窗：余额滚动到最新（弹出同时上浮 10px，防贴肚）
                if (vaultScale > 0.01)
                  Positioned(
                    bottom: 12 + 10 * (1 - vaultScale.clamp(0.0, 1.0)),
                    child: Transform.scale(
                      scale: vaultScale.clamp(0.0, 1.15),
                      child: _VaultBadge(amountText: _fmt(shown)),
                    ),
                  ),
                // +N 上浮（兽头顶，避免与金库窗重叠）
                if (plusT > 0 && plusT < 1)
                  Positioned(
                    bottom: 128 - 40 * rise,
                    child: Opacity(
                      opacity: 1 - plusT,
                      child: Transform.scale(
                        scale: plusScale,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '+${widget.reward}',
                              style: MwTypography.heading4.copyWith(fontWeight: FontWeight.w900, color: skin.success),
                            ),
                            const SizedBox(width: 4),
                            MonsterIcon(size: 24, bodyColor: skin.success),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// 金币徽章：品牌金圆＋星形矢量标（emoji 守卫禁 ★ 字符，一律用 Icons）。
/// 公开给签到按钮复用同一视觉物（idle 态即此币，发射后币“离家”飞入兽嘴）。
class CoinBadge extends StatelessWidget {
  final double size;

  const CoinBadge({super.key, this.size = 36});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [MwColors.sunshine300, MwColors.mutedGold],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: MwColors.mutedGold, width: size >= 28 ? 2 : 1.5),
        boxShadow: [
          BoxShadow(
            color: MwColors.sunshine300.withValues(alpha: 0.55),
            blurRadius: 12 * size / 36,
            offset: Offset(0, 3 * size / 36),
          ),
        ],
      ),
      child: Icon(Icons.star_rounded, size: size * 0.56, color: AppColors.white100),
    );
  }
}

/// 肚皮金库窗：奶油底＋金边＋辉光＋顶部投币口（存钱罐铭牌），余额等宽滚动。
/// 投币口＋余额窗的组合是本仪式的外观专利设计点，勿拆散改版。
/// 小字用 StarGold.bronzeDark（白底 WCAG AA），星标/边框用品牌金。
class _VaultBadge extends StatelessWidget {
  final String amountText;

  const _VaultBadge({required this.amountText});

  @override
  Widget build(BuildContext context) {
    final skin = context.skin.colors;
    return Stack(
      alignment: Alignment.topCenter,
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 122,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.white100.withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(context.design.radius.lg),
            border: Border.all(color: MwColors.sunshine300, width: 2),
            boxShadow: [
              BoxShadow(color: MwColors.sunshine300.withValues(alpha: 0.5), blurRadius: 14, offset: const Offset(0, 4)),
            ],
          ),
          child: Stack(
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star_rounded, size: 12, color: MwColors.mutedGold),
                      const SizedBox(width: 3),
                      Text(
                        '肚皮金库',
                        style: MwTypography.micro.copyWith(fontWeight: FontWeight.w700, color: StarGold.bronzeDark),
                      ),
                    ],
                  ),
                  const SizedBox(height: 1),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      amountText,
                      style: MwTypography.heading4.copyWith(
                        fontWeight: FontWeight.w800,
                        color: skin.text1,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ],
              ),
              // 静态对角 sheen：奶油窗上的贵价反光，零动画成本（禁裸色值，走 token）。
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(context.design.radius.control),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.center,
                        colors: [AppColors.white100.withValues(alpha: 0.35), AppColors.white100.withValues(alpha: 0.0)],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        // 投币口：压住金边上沿的存钱罐窄缝。
        Positioned(
          top: -5,
          child: Container(
            width: 30,
            height: 9,
            decoration: BoxDecoration(
              color: MonsterPalette.mouthInner,
              borderRadius: BorderRadius.circular(4.5),
              border: Border.all(color: MwColors.sunshine300, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}

/// 金库粒子画笔：尾迹／币光／咕咚波纹／沉底光点／嗝声波／星芒／肚皮辉光／戳星。
class _VaultFxPainter extends CustomPainter {
  final double approachEase;
  final double approachT;
  final double swallowT;
  final double sinkT;
  final double burpT;
  final double burstT;
  final double storeGlow;
  final double coinSize;
  final double coinCy;
  final double spinA;
  final double pokeP;
  final Color gold;
  final Color accent;
  final Color white;

  _VaultFxPainter({
    required this.approachEase,
    required this.approachT,
    required this.swallowT,
    required this.sinkT,
    required this.burpT,
    required this.burstT,
    required this.storeGlow,
    required this.coinSize,
    required this.coinCy,
    required this.spinA,
    required this.pokeP,
    required this.gold,
    required this.accent,
    required this.white,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    // 巨币尾迹：沿天降轨迹 4 点渐隐。
    if (approachT > 0 && approachT < 1) {
      for (var i = 0; i < 4; i++) {
        final p = approachEase - (i + 1) * 0.05;
        if (p <= 0 || p >= 1) continue;
        final y = _kGiantStartY + (_kMouthY - _kGiantStartY) * p;
        canvas.drawCircle(
          Offset(cx + (i.isEven ? 2.5 : -2.5) * i, y),
          3.4 - i * 0.6,
          Paint()..color = gold.withValues(alpha: (1 - p) * 0.45),
        );
      }
      // 币面流光：随自转环绕的高光点，金属贵价感。
      canvas.drawCircle(
        Offset(cx + math.cos(spinA) * coinSize * 0.22, coinCy + math.sin(spinA) * coinSize * 0.16),
        (coinSize * 0.055).clamp(2.0, 9.0),
        Paint()..color = white.withValues(alpha: 0.7),
      );
    }
    // 肚皮辉光：存款时的金色暖意
    if (storeGlow > 0.01) {
      const r = 64.0;
      final rect = Rect.fromCircle(center: Offset(cx, _kBellyY), radius: r);
      canvas.drawCircle(
        Offset(cx, _kBellyY),
        r,
        Paint()
          ..shader = RadialGradient(
            colors: [
              gold.withValues(alpha: 0.30 * storeGlow),
              gold.withValues(alpha: 0.0),
            ],
          ).createShader(rect),
      );
    }
    // 咕咚波纹：从嘴心扩散
    if (swallowT > 0 && swallowT < 1) {
      canvas.drawCircle(
        Offset(cx, _kMouthY),
        12 + 36 * swallowT,
        Paint()
          ..color = gold.withValues(alpha: 0.55 * (1 - swallowT))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1 + 3 * (1 - swallowT),
      );
    }
    // 沉底光点：金币化作暖光沉入肚底
    if (sinkT > 0 && sinkT < 1) {
      final y = _kMouthY + (_kSinkY - _kMouthY) * sinkT * sinkT;
      final a = 1 - sinkT;
      canvas.drawCircle(Offset(cx, y), 10 * a + 3, Paint()..color = gold.withValues(alpha: 0.35 * a));
      canvas.drawCircle(Offset(cx, y), 5 * a + 1.5, Paint()..color = white.withValues(alpha: 0.9 * a));
    }
    // 嗝声波：两圈错峰扩散。
    if (burpT > 0 && burpT < 1) {
      for (var k = 0; k < 2; k++) {
        final seg = ((burpT - (k == 0 ? 0.08 : 0.22)) / (k == 0 ? 0.47 : 0.48)).clamp(0.0, 1.0);
        if (seg <= 0 || seg >= 1) continue;
        canvas.drawCircle(
          Offset(cx, _kMouthY),
          12 + 34 * seg,
          Paint()
            ..color = gold.withValues(alpha: 0.5 * (1 - seg))
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1 + 2.5 * (1 - seg),
        );
      }
    }
    // 星芒迸发：10 枚四角星，椭圆轨道向外
    if (burstT > 0 && burstT < 1) {
      final ease = 1 - math.pow(1 - burstT, 2).toDouble();
      for (var i = 0; i < 10; i++) {
        final ang = i * math.pi / 5 + 0.3;
        final dist = 66 + 52 * ease;
        final pos = Offset(cx + math.cos(ang) * dist, _kBurstY + math.sin(ang) * dist * 0.82);
        final s = (i.isEven ? 7.0 : 5.0) * (1 - burstT * 0.4);
        _sparkle(canvas, pos, s, (i.isEven ? gold : white).withValues(alpha: (1 - burstT) * 0.95));
      }
    }
    // 戳肚皮小星：头顶三枚，咯咯缩同步明灭。
    if (pokeP >= 0 && pokeP <= 1) {
      const angs = [-0.6, 0.25, 1.05];
      for (var i = 0; i < angs.length; i++) {
        final pos = Offset(cx + math.cos(angs[i]) * 78, _kBurstY - 14 + math.sin(angs[i]) * 40);
        _sparkle(canvas, pos, 8 * (1 - pokeP * 0.4), (i.isEven ? gold : white).withValues(alpha: (1 - pokeP) * 0.95));
      }
    }
  }

  void _sparkle(Canvas canvas, Offset c, double s, Color color) {
    final path = Path()
      ..moveTo(c.dx, c.dy - s)
      ..quadraticBezierTo(c.dx, c.dy, c.dx + s, c.dy)
      ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy + s)
      ..quadraticBezierTo(c.dx, c.dy, c.dx - s, c.dy)
      ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy - s)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _VaultFxPainter old) =>
      old.approachEase != approachEase ||
      old.approachT != approachT ||
      old.swallowT != swallowT ||
      old.sinkT != sinkT ||
      old.burpT != burpT ||
      old.burstT != burstT ||
      old.storeGlow != storeGlow ||
      old.coinSize != coinSize ||
      old.coinCy != coinCy ||
      old.spinA != spinA ||
      old.pokeP != pokeP ||
      old.gold != gold ||
      old.accent != accent;
}
