// CoinFeedStage：亲手投喂台 — 把金币拖进小怪兽嘴里
//
// 长按签到币进入：金币悬浮待命（呼吸浮动），怪兽张嘴期待；拖动跟手（钳制盒内），
// 近嘴吸附张嘴＋金环预告；送达嘴边自动啊呜（onFed），别处松手弹性飞回。
// 成功后父级走账本 checkIn，再用 CoinSwallowCelebration(startAt: 0.36) 续演后四幕。
// 等账时（_fed）怪兽嚼嚼嘴，别处逻辑不动。
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:word_app/theme/skin_system.dart';
import 'package:word_app/tokens/design_tokens.dart';
import 'package:word_app/widgets/coin_swallow_celebration.dart' show CoinBadge;
import 'package:word_app/widgets/monster_icon.dart';

class CoinFeedStage extends StatefulWidget {
  /// 投喂成功（币送达嘴边）：父级走 checkIn＋续演。
  final VoidCallback onFed;

  /// 偷懒入口：直接走自动签到。
  final VoidCallback onAuto;

  /// 怪兽进化阶段／生长基线（与庆祝同源，投喂台也长大）。
  final int evoStage;
  final double growthBase;

  const CoinFeedStage({super.key, required this.onFed, required this.onAuto, this.evoStage = 0, this.growthBase = 1.0});

  @override
  State<CoinFeedStage> createState() => _CoinFeedStageState();
}

class _CoinFeedStageState extends State<CoinFeedStage> with TickerProviderStateMixin {
  static const _boxH = 250.0;
  static const _monster = 110.0;
  static const _coinSize = 36.0;
  static const _touchPad = 14.0; // 手指热区外扩
  static const _magnetR = 90.0; // 吸附预告半径
  static const _gulpR = 30.0; // 送达即吞半径（拖动中）
  static const _dropR = 44.0; // 松手结算半径
  static const _originDy = 52.0; // 金币待命高度（提示条下方）

  late final AnimationController _bob; // 呼吸浮动＋金环脉动＋等账嚼嘴
  AnimationController? _backCtrl; // 松手弹性飞回
  Offset? _coin; // 币左上（盒坐标，36 盒）
  bool _dragging = false;
  bool _fed = false;
  bool _near = false;
  double _mouthOpen = 0.35; // 期待态半张

  @override
  void initState() {
    super.initState();
    _bob = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat();
  }

  @override
  void dispose() {
    _bob.dispose();
    _backCtrl?.dispose();
    super.dispose();
  }

  double _mouthY() => _boxH - _monster + _monster / 2 + (_monster / 2 * 0.85) * 0.22;

  Offset _mouthOf(double w) => Offset(w / 2, _mouthY());

  Offset _originOf(double w) => Offset(w / 2 - _coinSize / 2, _originDy);

  Offset _coinCenter() => Offset(_coin!.dx + _coinSize / 2, _coin!.dy + _coinSize / 2);

  void _fireFed() {
    if (_fed) return;
    _fed = true;
    widget.onFed();
  }

  void _onPanStart(DragStartDetails _) {
    if (_fed) return;
    _backCtrl?.stop();
    setState(() => _dragging = true);
  }

  void _onPanUpdate(DragUpdateDetails d, double w) {
    if (_fed || !_dragging) return;
    var next = _coin! + d.delta;
    next = Offset(next.dx.clamp(0.0, w - _coinSize), next.dy.clamp(0.0, _boxH - _coinSize));
    final coinCenter = Offset(next.dx + _coinSize / 2, next.dy + _coinSize / 2);
    final dist = (coinCenter - _mouthOf(w)).distance;
    setState(() {
      _coin = next;
      _near = dist < _magnetR;
      _mouthOpen = _near ? 0.35 + 0.65 * (1 - (dist / _magnetR).clamp(0.0, 1.0)) : 0.35;
    });
    if (dist < _gulpR) _fireFed(); // 送嘴边即啊呜，不必松手
  }

  void _onPanEnd(DragEndDetails _, double w) {
    if (_fed) return;
    setState(() => _dragging = false);
    if ((_coinCenter() - _mouthOf(w)).distance < _dropR) {
      _fireFed();
      return;
    }
    _springBack(_originOf(w));
  }

  void _springBack(Offset target) {
    _backCtrl?.dispose();
    final from = _coin!;
    final c = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _backCtrl = c;
    c.addListener(() {
      if (!mounted) return;
      setState(() {
        _coin = Offset.lerp(from, target, Curves.elasticOut.transform(c.value))!;
        _near = false;
        _mouthOpen = 0.35;
      });
    });
    c.forward();
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin.colors;
    return SizedBox(
      height: _boxH,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          _coin ??= _originOf(w);
          return AnimatedBuilder(
            animation: _bob,
            builder: (context, _) {
              final bobT = _bob.value;
              final bob = _dragging || _fed ? 0.0 : math.sin(bobT * 2 * math.pi) * 6;
              final mouth = _mouthOf(w);
              // 等账嚼嘴：0.55~0.9 开合
              final mouthShown = _fed ? 0.55 + 0.35 * (0.5 + 0.5 * math.sin(bobT * 6 * math.pi)) : _mouthOpen;
              final ringR = 26 + 4 * math.sin(bobT * 4 * math.pi);
              return Stack(
                alignment: Alignment.topCenter,
                clipBehavior: Clip.none,
                children: [
                  // 提示＋偷懒入口
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(_fed ? '啊呜，正在品尝…' : '拖住金币，喂进小怪兽嘴里', style: MwTypography.micro.copyWith(color: skin.text2)),
                        if (!_fed)
                          TextButton(
                            onPressed: widget.onAuto,
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                              '直接签到',
                              style: MwTypography.micro.copyWith(fontWeight: FontWeight.w700, color: skin.accent),
                            ),
                          ),
                      ],
                    ),
                  ),
                  // 近嘴吸附金环预告
                  if (_near && !_fed)
                    Positioned(
                      left: mouth.dx - ringR,
                      top: mouth.dy - ringR,
                      child: Container(
                        width: ringR * 2,
                        height: ringR * 2,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: MwColors.sunshine300.withValues(alpha: 0.8), width: 2.5),
                        ),
                      ),
                    ),
                  // 怪兽（期待态，进化形态与生长基线同庆祝）
                  Positioned(
                    bottom: 0,
                    child: MonsterIcon(
                      size: _monster,
                      mouthOpen: mouthShown,
                      bellyScale: widget.growthBase,
                      evoStage: widget.evoStage,
                    ),
                  ),
                  // 可拖金币（热区外扩防 fat-finger）
                  if (!_fed)
                    Positioned(
                      left: _coin!.dx - _touchPad,
                      top: _coin!.dy + bob - _touchPad,
                      child: GestureDetector(
                        onPanStart: _onPanStart,
                        onPanUpdate: (d) => _onPanUpdate(d, w),
                        onPanEnd: (d) => _onPanEnd(d, w),
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          color: Colors.transparent,
                          padding: const EdgeInsets.all(_touchPad),
                          child: const CoinBadge(),
                        ),
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
