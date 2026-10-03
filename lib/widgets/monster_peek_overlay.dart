// MonsterPeekOverlay：怪兽从屏幕底缘探头欢呼
//
// 短暂全屏非阻塞庆祝（学习页连击里程碑等场景）：怪兽（MonsterIcon）从屏幕
// 底缘滑入 → 停留 0.8s（弹跳＋phrase 气泡）→ 滑出并自动移除，总时长 1.5s
// （≤1.6s 预算）。整层 IgnorePointer，答题手势直达下方页面，不碰答题节奏。
// 串行防重入：演出中的新 show 请求直接忽略（静态开关，完成/销毁兜底都复位）。
// 怪兽形态与怪兽小屋同源：累计签到天数（ScareCoinStore.checkinDates().length）
// 经 MonsterIcon.stageFor 换算进化阶段（0/7/30/100 天）；无账本语境（如单测
// 最小装配）或读取失败时退回默认形态（0 奶泡）。
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import 'package:word_app/core/utils/swallowed_error_report.dart';
import 'package:word_app/features/scare_coin/application/scare_coin_store.dart';
import 'package:word_app/tokens/design_tokens.dart';
import 'package:word_app/tokens/motion_tokens.dart';
import 'package:word_app/widgets/monster_icon.dart';

/// 怪兽探头庆祝浮层。
class MonsterPeekOverlay {
  MonsterPeekOverlay._();

  /// 演出进行中标志（串行防重入；完成回调与销毁兜底都会复位）。
  static bool _playing = false;

  // 各段时长：350 + 800 + 350 = 1500ms（≤1.6s 预算）。仪式性短演出不落在
  // MotionDurations 档位上（150/200/300/450/700/2800），避免动效卫生棘轮误锁。
  static const Duration _slideIn = Duration(milliseconds: 350);
  static const Duration _hold = Duration(milliseconds: 800);
  static const Duration _slideOut = Duration(milliseconds: 350);

  /// 怪兽边长。
  static const double _monsterSize = 96;

  /// 位移预留：怪兽＋气泡总高的余量，保证全藏位完全在屏幕外（底缘裁剪探出）。
  static const double _travelReserve = 80;

  /// 就位后距屏幕底缘的间隙（露出身体大部分，探头感）。
  static const double _bottomGap = 8;

  /// 展示一次怪兽探头（滑入 → 停留＋弹跳＋气泡 → 演完自动移除）。
  /// 演出中的重复调用会被忽略（串行防重入）。
  static void show(BuildContext context, {required String phrase}) {
    if (_playing) return;
    final overlay = Overlay.of(context);
    _playing = true;
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _MonsterPeek(
        phrase: phrase,
        slideIn: _slideIn,
        hold: _hold,
        slideOut: _slideOut,
        monsterSize: _monsterSize,
        travelReserve: _travelReserve,
        bottomGap: _bottomGap,
        onDone: () {
          if (entry.mounted) entry.remove();
          _playing = false;
        },
        onDetached: () => _playing = false,
      ),
    );
    overlay.insert(entry);
  }
}

/// 探头演出层：三段编排由三个控制器接力（滑入 / 停留弹跳＋气泡 / 滑出）。
class _MonsterPeek extends StatefulWidget {
  final String phrase;
  final Duration slideIn;
  final Duration hold;
  final Duration slideOut;
  final double monsterSize;
  final double travelReserve;
  final double bottomGap;

  /// 演出完成：移除 overlay entry 并复位串行开关。
  final VoidCallback onDone;

  /// entry 被外部回收（宿主提前销毁）兜底：仅复位串行开关。
  final VoidCallback onDetached;

  const _MonsterPeek({
    required this.phrase,
    required this.slideIn,
    required this.hold,
    required this.slideOut,
    required this.monsterSize,
    required this.travelReserve,
    required this.bottomGap,
    required this.onDone,
    required this.onDetached,
  });

  @override
  State<_MonsterPeek> createState() => _MonsterPeekState();
}

class _MonsterPeekState extends State<_MonsterPeek> with TickerProviderStateMixin {
  late final AnimationController _inCtrl;
  late final AnimationController _holdCtrl;
  late final AnimationController _outCtrl;
  late final Animation<double> _inAnim;
  late final Animation<double> _outAnim;
  late final Animation<double> _bounceAnim;
  late final Animation<double> _bubbleAnim;

  /// 进化阶段（异步补齐；默认 0 奶泡）。
  int _evoStage = 0;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _inCtrl = AnimationController(vsync: this, duration: widget.slideIn);
    _holdCtrl = AnimationController(vsync: this, duration: widget.hold);
    _outCtrl = AnimationController(vsync: this, duration: widget.slideOut);
    _inAnim = CurvedAnimation(parent: _inCtrl, curve: MotionCurves.accordion);
    _outAnim = CurvedAnimation(parent: _outCtrl, curve: MotionCurves.exit);
    _bounceAnim = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _holdCtrl, curve: Curves.elasticOut));
    _bubbleAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _holdCtrl,
        curve: const Interval(0, 0.45, curve: Curves.easeOutBack),
      ),
    );
    _inCtrl.forward().whenComplete(() {
      if (mounted) {
        _holdCtrl.forward().whenComplete(() {
          if (mounted) _outCtrl.forward().whenComplete(_finish);
        });
      }
    });
    // 形态异步补齐：先以默认形态入演（show 立即生效），签到数据读到后无缝换装。
    final store = context.read<ScareCoinStore?>();
    if (store != null) unawaited(_loadStage(store));
  }

  /// 累计签到天数 → 进化阶段（与怪兽小屋同口径）。失败降级默认形态，不上抛。
  Future<void> _loadStage(ScareCoinStore store) async {
    try {
      final totalDays = (await store.checkinDates()).length;
      if (!mounted) return;
      setState(() => _evoStage = MonsterIcon.stageFor(totalDays));
    } catch (e, s) {
      // 探头是纯庆祝动效，形态降级为默认奶泡即可继续演出；上报不静默。
      reportSwallowedError('怪兽探头形态读取失败', e, s);
    }
  }

  void _finish() {
    if (_finished) return;
    _finished = true;
    widget.onDone();
  }

  @override
  void dispose() {
    // 宿主提前销毁（页面退出/测试拆树）兜底：复位串行开关，防 _playing 卡死。
    if (!_finished) {
      _finished = true;
      widget.onDetached();
    }
    _inCtrl.dispose();
    _holdCtrl.dispose();
    _outCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: EdgeInsets.only(bottom: widget.bottomGap),
            child: AnimatedBuilder(
              animation: Listenable.merge([_inCtrl, _holdCtrl, _outCtrl]),
              builder: (context, child) {
                // 滑入段 1→0、滑出段 0→1，取大者作为离场位移比例。
                final hide = math.max(1.0 - _inAnim.value, _outAnim.value);
                final travel = hide * (widget.monsterSize + widget.travelReserve + widget.bottomGap);
                return Transform.translate(offset: Offset(0, travel), child: child);
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // phrase 气泡：停留段弹出（缩放＋淡入），滑入/滑出段隐藏。
                  AnimatedBuilder(
                    animation: _bubbleAnim,
                    builder: (context, child) {
                      final t = _bubbleAnim.value.clamp(0.0, 1.0);
                      if (t <= 0) return const SizedBox.shrink();
                      return Opacity(
                        opacity: t,
                        child: Transform.scale(scale: 0.6 + 0.4 * t, child: child),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xxs),
                      decoration: const ShapeDecoration(
                        color: MwColors.sunshine300,
                        shape: StadiumBorder(),
                        shadows: [BoxShadow(color: MwShadows.softShadow, blurRadius: 12, offset: Offset(0, 4))],
                      ),
                      child: Text(
                        widget.phrase,
                        style: MwTypography.bodyBold.copyWith(
                          fontSize: AppFontSizes.bodyMd,
                          fontWeight: FontWeight.w700,
                          color: MwColors.charcoal,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  // 弹跳：停留段 elasticOut 驱动小幅缩放过冲（底缘对齐，向上蹦）。
                  AnimatedBuilder(
                    animation: _bounceAnim,
                    builder: (context, child) => Transform.scale(
                      scale: 1 + 0.06 * _bounceAnim.value,
                      alignment: Alignment.bottomCenter,
                      child: child,
                    ),
                    child: MonsterIcon(size: widget.monsterSize, evoStage: _evoStage),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
