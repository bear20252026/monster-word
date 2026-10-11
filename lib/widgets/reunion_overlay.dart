// ReunionOverlay：回家仪式浮层（距上次打开 App ≥3 天后重返时的欢迎演出）。
//
// 复用 MonsterPeekOverlay 范式：根 Overlay 短暂全屏非阻塞演出（整层
// IgnorePointer，落地页手势照常可达）；串行防重入：演出中的新 show 请求直接
// 忽略（静态开关，完成/销毁双兜底复位）。演出编排：左缘「门缝」张开（暗门
// 暖光竖带随滑入段变宽）→ 怪兽从门缝滑出（左缘滑入变体，FractionalTranslation
// 按自身宽度出画，任意内容宽度都能完全藏进屏外）→ 文案气泡「我就知道你会
// 回来！（{absentDays} 天不见）」停留 1.2s → 滑出并自动移除。
// 时长字面量惯例同 monster_peek_overlay.dart（仪式性短演出不落 MotionDurations
// 档位，避免动效卫生棘轮误锁）。
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:word_app/core/utils/swallowed_error_report.dart';
import 'package:word_app/features/scare_coin/application/scare_coin_store.dart';

import 'package:word_app/tokens/design_tokens.dart';
import 'package:word_app/tokens/motion_tokens.dart';
import 'package:word_app/widgets/monster_icon.dart';

/// 回家仪式浮层。
class ReunionOverlay {
  ReunionOverlay._();

  /// 上次打开 App 的日期键（yyyy-MM-dd；由落地页接线写入，回家仪式判定依据）。
  static const String lastVisitPrefKey = 'monster_last_app_visit';

  /// 演出进行中标志（串行防重入；完成回调与销毁兜底都会复位）。
  static bool _playing = false;

  // 各段时长：300 + 1200 + 400 = 1900ms（≤2s 预算）。
  static const Duration _slideIn = Duration(milliseconds: 300);
  static const Duration _hold = Duration(milliseconds: 1200);
  static const Duration _slideOut = Duration(milliseconds: 400);

  /// 怪兽边长。
  static const double _monsterSize = 112;

  /// 门缝最大宽度（滑入段张到的宽度，滑出段同步合拢）。
  static const double _doorWidth = 14;

  /// 展示一次回家仪式（门缝张开 → 怪兽滑出 → 文案停留 → 滑出自移除）。
  /// 演出中的重复调用会被忽略（串行防重入）。
  static void show(BuildContext context, {required int absentDays}) {
    if (_playing) return;
    final overlay = Overlay.of(context);
    _playing = true;
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _ReunionGreeting(
        absentDays: absentDays,
        slideIn: _slideIn,
        hold: _hold,
        slideOut: _slideOut,
        monsterSize: _monsterSize,
        doorWidth: _doorWidth,
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

/// 回家演出层：三段编排接力（左缘门缝滑入 / 停留文案弹跳 / 滑出）。
class _ReunionGreeting extends StatefulWidget {
  final int absentDays;
  final Duration slideIn;
  final Duration hold;
  final Duration slideOut;
  final double monsterSize;
  final double doorWidth;

  /// 演出完成：移除 overlay entry 并复位串行开关。
  final VoidCallback onDone;

  /// entry 被外部回收（宿主提前销毁）兜底：仅复位串行开关。
  final VoidCallback onDetached;

  const _ReunionGreeting({
    required this.absentDays,
    required this.slideIn,
    required this.hold,
    required this.slideOut,
    required this.monsterSize,
    required this.doorWidth,
    required this.onDone,
    required this.onDetached,
  });

  @override
  State<_ReunionGreeting> createState() => _ReunionGreetingState();
}

class _ReunionGreetingState extends State<_ReunionGreeting> with TickerProviderStateMixin {
  late final AnimationController _inCtrl;
  late final AnimationController _holdCtrl;
  late final AnimationController _outCtrl;
  late final Animation<double> _inAnim;
  late final Animation<double> _outAnim;
  late final Animation<double> _bounceAnim;

  /// 进化阶段（异步补齐；默认 0 奶泡）。
  int _evoStage = 0;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    // 形态异步补齐：先以默认形态入演（show 立即生效），签到数据读到后无缝换装（与探头演出同款，
    // 曾硬编码 evoStage: 0——老用户回家看到的仍是奶泡）。
    final store = context.read<ScareCoinStore?>();
    if (store != null) {
      unawaited(
        store
            .checkinDates()
            .then((dates) {
              if (mounted) setState(() => _evoStage = MonsterIcon.stageFor(dates.length));
            })
            .catchError((Object e, StackTrace s) {
              reportSwallowedError('回家仪式形态读取失败', e, s);
            }),
      );
    }
    _inCtrl = AnimationController(vsync: this, duration: widget.slideIn);
    _holdCtrl = AnimationController(vsync: this, duration: widget.hold);
    _outCtrl = AnimationController(vsync: this, duration: widget.slideOut);
    _inAnim = CurvedAnimation(parent: _inCtrl, curve: MotionCurves.accordion);
    _outAnim = CurvedAnimation(parent: _outCtrl, curve: MotionCurves.exit);
    _bounceAnim = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _holdCtrl, curve: Curves.elasticOut));
    _inCtrl.forward().whenComplete(() {
      if (mounted) {
        _holdCtrl.forward().whenComplete(() {
          if (mounted) _outCtrl.forward().whenComplete(_finish);
        });
      }
    });
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
        child: AnimatedBuilder(
          animation: Listenable.merge([_inCtrl, _holdCtrl, _outCtrl]),
          builder: (context, child) {
            // 离场位移比例：滑入段 1→0、滑出段 0→1，取大者作为出画比例。
            final hide = math.max(1.0 - _inAnim.value, _outAnim.value);
            // 门缝开度：滑入段张到全宽，滑出段同步合拢（开合与怪兽进出同拍）。
            final doorOpen = _inAnim.value * (1 - _outAnim.value);
            return Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                // 左缘门缝：一条暗门暖光竖带（门先开，怪兽才出来）。
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: math.max(2.0, widget.doorWidth * doorOpen),
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [MwColors.charcoal, MwColors.sunshine300],
                      ),
                      boxShadow: [BoxShadow(color: MwShadows.softShadow, blurRadius: 16)],
                    ),
                  ),
                ),
                // 怪兽＋文案：贴左缘垂直居中，按自身宽度出画/入场（任意宽度都完全藏进屏外）。
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: FractionalTranslation(
                    translation: Offset(-hide, 0),
                    child: Center(child: child),
                  ),
                ),
              ],
            );
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 文案气泡：与怪兽同行入画，停留段不消失（回家问候在门前说完整）。
              Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xxs),
                decoration: const ShapeDecoration(
                  color: MwColors.sunshine300,
                  shape: StadiumBorder(),
                  shadows: [BoxShadow(color: MwShadows.softShadow, blurRadius: 12, offset: Offset(0, 4))],
                ),
                child: Text(
                  '我就知道你会回来！（${widget.absentDays} 天不见）',
                  style: MwTypography.bodyBold.copyWith(
                    fontSize: AppFontSizes.bodyMd,
                    fontWeight: FontWeight.w700,
                    color: MwColors.charcoal,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              // 停留段 elasticOut 驱动小幅缩放过冲（左缘对齐，向右蹦）。
              AnimatedBuilder(
                animation: _bounceAnim,
                builder: (context, child) =>
                    Transform.scale(scale: 1 + 0.06 * _bounceAnim.value, alignment: Alignment.centerLeft, child: child),
                child: MonsterIcon(size: widget.monsterSize, evoStage: _evoStage),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 展示一次回家仪式（转接 [ReunionOverlay.show]，独立顶层函数便于接线处直呼）。
void showReunionOverlay(BuildContext context, {required int absentDays}) {
  ReunionOverlay.show(context, absentDays: absentDays);
}
