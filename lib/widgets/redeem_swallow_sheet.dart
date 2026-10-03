// RedeemSwallowSheet：兑换成交「收入囊中」吞币仪式弹层（G5b）。
// showRedeemSwallowSheet 弹出底部弹层：标题「收入囊中！」；怪兽嘴部 240ms 循环
// 开合，min(coinCost, 12) 枚 CoinBadge 以 120ms 错峰飞入嘴部，每落一枚腮帮
// cheekPuff 渐涨，超出 12 枚显示「+N」徽标；itemName 以 springPop 放大登场；
// 彩带小档（30 粒）飘落；按钮「收下！」关闭弹层。
// 时间轴常量与 monster_feed_celebration（签到吞币同族仪式）保持一致：
// 错峰 120ms / 单枚飞行 420ms / 吞咽淡出 120ms / 收尾 600ms / 嘴部循环 240ms。
// 纯展示层：不读写 ScareCoinStore 账本，扣币在调用兑换 API 处已完成。
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:word_app/theme/skin_system.dart';
import 'package:word_app/tokens/design_tokens.dart';
import 'package:word_app/tokens/effect_palette.dart';
import 'package:word_app/tokens/motion_tokens.dart';
import 'package:word_app/widgets/coin_swallow_celebration.dart' show CoinBadge;
import 'package:word_app/widgets/confetti.dart';
import 'package:word_app/widgets/monster_icon.dart';

/// 每枚金币的起飞间隔（错峰；与 monster_feed_celebration 同款）。
const int _kStaggerMs = 120;

/// 单枚金币飞行时长（起飞 → 嘴部）。
const int _kFlightMs = 420;

/// 单枚金币落嘴后的吞咽淡出时长。
const int _kSwallowMs = 120;

/// 末枚金币落嘴后的收尾时长（吞咽 + 打嗝回弹）。
const int _kTailMs = 600;

/// 嘴部开合循环周期（吃相；喂食窗口内循环）。
const int _kMouthCycleMs = 240;

/// 最多实飞的金币数；超出部分折算成「+N」徽标。
const int _kMaxVisibleCoins = 12;

/// 怪兽画布边长（金币尺寸随其等比缩放）。
const double _kMonsterSize = 96;

/// 单枚金币直径（与 monster_feed_celebration 的 size*0.24 同比例）。
const double _kCoinSize = _kMonsterSize * 0.24;

/// 兑换成交仪式弹层：纯展示，无账务调用（扣币已在调用兑换 API 处完成）。
///
/// [itemName] 商品名（放大 pop 展示）；[coinCost] 本次花费（驱动飞币枚数与
/// 「+N」截断徽标）；[monsterStage] 怪兽进化阶段 0~3（取不到传 0 奶泡形态）。
Future<void> showRedeemSwallowSheet(
  BuildContext context, {
  required String itemName,
  required int coinCost,
  required int monsterStage,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    // 内容含怪兽区（104px）+ 文案 + 按钮，超出默认 9/16 屏高（测试环境
    // 600px 高度下溢出 4.5px），放开高度限制由内容自撑。
    isScrollControlled: true,
    builder: (_) => _RedeemSwallowSheet(itemName: itemName, coinCost: coinCost, monsterStage: monsterStage),
  );
}

class _RedeemSwallowSheet extends StatefulWidget {
  const _RedeemSwallowSheet({required this.itemName, required this.coinCost, required this.monsterStage});

  final String itemName;
  final int coinCost;

  /// 进化阶段 0~3（MonsterIcon 内部 clamp）。
  final int monsterStage;

  @override
  State<_RedeemSwallowSheet> createState() => _RedeemSwallowSheetState();
}

class _RedeemSwallowSheetState extends State<_RedeemSwallowSheet> with TickerProviderStateMixin {
  // 弹层随成交一次性创建（成功才挂载），入参视为生命周期内不变。
  late final int _visibleCoins;
  late final int _totalMs;
  late final AnimationController _feed;
  late final List<Animation<Offset>> _flights;
  late final List<Animation<double>> _fadeIns;
  late final List<Animation<double>> _swallows;
  late final AnimationController _pop;
  late final Animation<double> _popScale;

  @override
  void initState() {
    super.initState();
    final requested = widget.coinCost < 0 ? 0 : widget.coinCost;
    _visibleCoins = math.min(requested, _kMaxVisibleCoins);
    _totalMs = _visibleCoins > 0 ? _visibleCoins * _kStaggerMs + _kTailMs : 0;
    _feed = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: _totalMs),
    );

    // 金币「嘴部」目标点取画布中心偏下（MonsterIcon 嘴位的视觉近似，monster_feed_celebration
    // 同款）；起点在画布上方，Stack clipBehavior: Clip.none 允许入画前越界绘制。
    const mouth = Offset(0, _kMonsterSize * 0.10);
    _flights = [
      for (int i = 0; i < _visibleCoins; i++)
        Tween<Offset>(begin: Offset(((i % 3) - 1) * _kMonsterSize * 0.12, -_kMonsterSize * 0.38), end: mouth).animate(
          CurvedAnimation(
            parent: _feed,
            curve: Interval(_frac(i * _kStaggerMs), _frac(i * _kStaggerMs + _kFlightMs), curve: Curves.easeIn),
          ),
        ),
    ];
    _fadeIns = [
      for (int i = 0; i < _visibleCoins; i++)
        CurvedAnimation(parent: _feed, curve: Interval(_frac(i * _kStaggerMs), _frac(i * _kStaggerMs + _kSwallowMs))),
    ];
    _swallows = [
      for (int i = 0; i < _visibleCoins; i++)
        CurvedAnimation(
          parent: _feed,
          curve: Interval(_frac(i * _kStaggerMs + _kFlightMs), _frac(i * _kStaggerMs + _kFlightMs + _kSwallowMs)),
        ),
    ];
    if (_visibleCoins > 0) _feed.forward();

    // itemName 放大 pop：springPop 过冲（与对勾/徽标出现同族曲线）。
    _pop = AnimationController(vsync: this, duration: MotionDurations.slow);
    _popScale = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _pop, curve: MotionCurves.springPop));
    _pop.forward();
  }

  @override
  void dispose() {
    _feed.dispose();
    _pop.dispose();
    super.dispose();
  }

  /// 毫秒 → 归一化时间轴占比。
  double _frac(int ms) => _totalMs > 0 ? ms / _totalMs : 0.0;

  /// 喂食窗口（首枚起飞 → 末枚落嘴）。
  int get _feedEndMs => (_visibleCoins - 1) * _kStaggerMs + _kFlightMs;

  /// 嘴部开合：喂食窗口内按 240ms 周期循环开合（吃相），窗口后收拢回微笑。
  double _mouthOpen(double t) {
    if (_visibleCoins == 0) return 0;
    final elapsed = t * _totalMs;
    final cycle = 0.5 - 0.5 * math.cos(2 * math.pi * elapsed / _kMouthCycleMs);
    final closeOut = ((elapsed - _feedEndMs) / _kSwallowMs).clamp(0.0, 1.0);
    return (cycle * (1 - closeOut)).clamp(0.0, 1.0);
  }

  /// 腮帮：每落一枚金币渐涨 1/n（easeOut），全部吃完时涨满到 1。
  double _cheekPuff(double t) {
    if (_visibleCoins == 0) return 0;
    final elapsed = t * _totalMs;
    var puff = 0.0;
    for (int i = 0; i < _visibleCoins; i++) {
      final p = ((elapsed - (i * _kStaggerMs + _kFlightMs)) / _kSwallowMs).clamp(0.0, 1.0);
      puff += 1 - (1 - p) * (1 - p);
    }
    return (puff / _visibleCoins).clamp(0.0, 1.0);
  }

  /// 打嗝回弹：末枚落嘴后 1 → 1.06 → 1（半正弦拱，落在总时长收尾窗内）。
  double _burpScale(double t) {
    if (_visibleCoins == 0) return 1;
    final elapsed = t * _totalMs;
    final p = ((elapsed - _feedEndMs) / (_totalMs - _feedEndMs)).clamp(0.0, 1.0);
    return 1 + 0.06 * math.sin(math.pi * p);
  }

  /// 「+N」徽标：N = 被截断的金币数（coinCost > 12 才会出现）。
  Widget _buildOverflowBadge(BuildContext context, int overflow) {
    final accent = SkinProvider.of(context).colors.accent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(AppRadius.pill)),
      child: Text(
        '+$overflow',
        style: MwTypography.micro.copyWith(fontWeight: FontWeight.w700, color: AppColors.white100),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.skin.colors;
    final overflow = widget.coinCost - _visibleCoins;
    return ConfettiOverlay(
      // 彩带小档：30 粒（与答题庆祝同档，formal_review_question 惯例）。
      particleCount: 30,
      direction: ConfettiDirection.down,
      duration: const Duration(seconds: 2),
      colors: GradientEffects.celebration,
      autoPlay: true,
      child: Container(
        decoration: BoxDecoration(
          color: colors.cardBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '收入囊中！',
              style: MwTypography.heading4.copyWith(fontWeight: FontWeight.w600, color: colors.text1),
            ),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: _kMonsterSize,
              height: _kMonsterSize,
              child: AnimatedBuilder(
                animation: _feed,
                builder: (context, _) {
                  final t = _feed.value;
                  return Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      Transform.scale(
                        scale: _burpScale(t),
                        child: MonsterIcon(
                          size: _kMonsterSize,
                          mouthOpen: _mouthOpen(t),
                          cheekPuff: _cheekPuff(t),
                          evoStage: widget.monsterStage,
                        ),
                      ),
                      // 金币全程挂载（透明度控制显隐，不移除节点），错峰飞入嘴部。
                      for (int i = 0; i < _visibleCoins; i++)
                        Opacity(
                          opacity: (_fadeIns[i].value * (1 - _swallows[i].value)).clamp(0.0, 1.0),
                          child: Transform.translate(
                            offset: _flights[i].value,
                            child: const CoinBadge(size: _kCoinSize),
                          ),
                        ),
                      if (overflow > 0)
                        Positioned(
                          right: _kMonsterSize * 0.02,
                          bottom: _kMonsterSize * 0.02,
                          child: _buildOverflowBadge(context, overflow),
                        ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            AnimatedBuilder(
              animation: _popScale,
              builder: (context, _) => Transform.scale(
                scale: _popScale.value,
                child: Text(
                  widget.itemName,
                  style: MwTypography.heading3.copyWith(fontWeight: FontWeight.w600, color: colors.text1),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text('兑换成功 · ${widget.coinCost} 币', style: MwTypography.caption.copyWith(color: colors.text2)),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.accent,
                  foregroundColor: colors.onGlassAccent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(context.design.radius.pill)),
                  elevation: 0,
                ),
                onPressed: () => Navigator.pop(context),
                child: Text('收下！', style: MwTypography.bodyBold.copyWith(color: colors.onGlassAccent)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
