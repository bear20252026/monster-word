// MonsterFeedCelebration：完成页主视觉 — 怪兽张嘴吃尖叫币庆祝组件。
// 编排：金币从上方错峰飞入嘴部（每枚间隔 120ms，Interval 错峰），每落一枚腮帮
// cheekPuff 渐涨；全部吃完后整体 1 → 1.06 → 1 回弹一次（打嗝）。
// 嘴部在喂食窗口内按 300ms 开 / 300ms 闭循环开合（吃相），窗口后收拢回微笑。
// 总时长 = coinCount*120ms + 600ms；coinCount > 12 时只飞 12 枚并显示 +N。
// 金币「嘴部」目标点取画布中心偏下（MonsterIcon 嘴位 0.22r 的视觉近似），
// 起点在画布上方，Stack clipBehavior: Clip.none 允许入画前越界绘制。
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:word_app/core/utils/sfx.dart';
import 'package:word_app/tokens/design_tokens.dart';
import 'package:word_app/tokens/effect_palette.dart';
import 'package:word_app/widgets/coin_swallow_celebration.dart';
import 'package:word_app/widgets/monster_icon.dart';

/// 每枚金币的起飞间隔（错峰）。
const int _kStaggerMs = 120;

/// 末枚金币落嘴后的收尾时长（吞咽 + 打嗝回弹）。
const int _kTailMs = 600;

/// 单枚金币飞行时长（起飞 → 嘴部）。
const int _kFlightMs = 420;

/// 单枚金币落嘴后的吞咽淡出时长。
const int _kSwallowMs = 120;

/// 嘴部开合周期：300ms 张开 + 300ms 闭合（吃相节奏）。
const int _kMouthCycleMs = 600;

/// 最多实飞的金币数；超出部分折算成「+N」徽标。
const int _kMaxVisibleCoins = 12;

class MonsterFeedCelebration extends StatefulWidget {
  /// 本次要吃的尖叫币数量；>12 时只飞 12 枚并显示 +N。
  final int coinCount;

  /// 怪兽画布边长，金币尺寸与徽标字号随画布等比缩放。
  final double size;

  const MonsterFeedCelebration({super.key, required this.coinCount, this.size = 80});

  @override
  State<MonsterFeedCelebration> createState() => _MonsterFeedCelebrationState();
}

class _MonsterFeedCelebrationState extends State<MonsterFeedCelebration> with SingleTickerProviderStateMixin {
  // 组件随结算一次性创建（父层结算成功才挂载），coinCount 视为生命周期内不变。
  late final int _visibleCoins;
  late final int _totalMs;
  late final AnimationController _controller;
  late final List<Animation<Offset>> _flights;
  late final List<Animation<double>> _fadeIns;
  late final List<Animation<double>> _swallows;

  @override
  void initState() {
    super.initState();
    final requested = widget.coinCount < 0 ? 0 : widget.coinCount;
    _visibleCoins = math.min(requested, _kMaxVisibleCoins);
    _totalMs = _visibleCoins > 0 ? _visibleCoins * _kStaggerMs + _kTailMs : 0;
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: _totalMs),
    );

    final mouth = Offset(0, widget.size * 0.10);
    _flights = [
      for (int i = 0; i < _visibleCoins; i++)
        Tween<Offset>(begin: Offset(((i % 3) - 1) * widget.size * 0.12, -widget.size * 0.38), end: mouth).animate(
          CurvedAnimation(
            parent: _controller,
            curve: Interval(_frac(i * _kStaggerMs), _frac(i * _kStaggerMs + _kFlightMs), curve: Curves.easeIn),
          ),
        ),
    ];
    _fadeIns = [
      for (int i = 0; i < _visibleCoins; i++)
        CurvedAnimation(
          parent: _controller,
          curve: Interval(_frac(i * _kStaggerMs), _frac(i * _kStaggerMs + _kSwallowMs)),
        ),
    ];
    _swallows = [
      for (int i = 0; i < _visibleCoins; i++)
        CurvedAnimation(
          parent: _controller,
          curve: Interval(_frac(i * _kStaggerMs + _kFlightMs), _frac(i * _kStaggerMs + _kFlightMs + _kSwallowMs)),
        ),
    ];
    if (_visibleCoins > 0) {
      _controller.forward();
      // 末枚金币落嘴 = 打嗝回弹起点：同步给一声 burp（SfxPlayer 静音档自会短路）。
      _burpTimer = Timer(Duration(milliseconds: _feedEndMs), () => SfxPlayer.fire(Sfx.burp));
    }
  }

  Timer? _burpTimer;

  @override
  void dispose() {
    _burpTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  /// 毫秒 → 归一化时间轴占比。
  double _frac(int ms) => _totalMs > 0 ? ms / _totalMs : 0.0;

  /// 喂食窗口（首枚起飞 → 末枚落嘴）。
  int get _feedEndMs => (_visibleCoins - 1) * _kStaggerMs + _kFlightMs;

  /// 嘴部开合：喂食窗口内按 300ms 开 / 300ms 闭循环（吃相），窗口后收拢回微笑。
  double _mouthOpen(double t) {
    if (_visibleCoins == 0) return 0;
    final elapsed = t * _totalMs;
    if (elapsed >= _feedEndMs) return 0;
    // 半正弦拱：前半周期 0→1（300ms 张开），后半周期 1→0（300ms 闭合）。
    final cycle = math.sin(math.pi * (elapsed % _kMouthCycleMs) / _kMouthCycleMs);
    return cycle.clamp(0.0, 1.0);
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

  @override
  Widget build(BuildContext context) {
    final coinSize = widget.size * 0.24;
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = _controller.value;
          return Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Transform.scale(
                scale: _burpScale(t),
                child: MonsterIcon(size: widget.size, mouthOpen: _mouthOpen(t), cheekPuff: _cheekPuff(t)),
              ),
              // 金币全程挂载（透明度控制显隐，不移除节点），错峰飞入嘴部。
              for (int i = 0; i < _visibleCoins; i++)
                Opacity(
                  opacity: (_fadeIns[i].value * (1 - _swallows[i].value)).clamp(0.0, 1.0),
                  child: Transform.translate(
                    offset: _flights[i].value,
                    child: CoinBadge(size: coinSize),
                  ),
                ),
              if (widget.coinCount > _kMaxVisibleCoins)
                Positioned(right: widget.size * 0.02, bottom: widget.size * 0.02, child: _buildOverflowBadge()),
            ],
          );
        },
      ),
    );
  }

  /// 「+N」徽标：N = 被截断的金币数（coinCount > 12 才会出现）。
  /// 底色用怪兽金（MonsterPalette.evoGold）：组件不依赖皮肤系统，裸 MaterialApp 测试可直接渲染。
  Widget _buildOverflowBadge() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: widget.size * 0.08, vertical: widget.size * 0.025),
      decoration: BoxDecoration(color: MonsterPalette.evoGold, borderRadius: BorderRadius.circular(AppRadius.pill)),
      child: Text(
        '+${widget.coinCount - _kMaxVisibleCoins}',
        style: TextStyle(color: AppColors.white100, fontSize: widget.size * 0.16, fontWeight: FontWeight.w700),
      ),
    );
  }
}
