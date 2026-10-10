// BondLevelUpOverlay：羁绊升级仪式（W4.5 宠物化补全——关系时刻值得庆祝）。
//
// 从「初识」跨到「熟络」的阈值时刻：柔光升起 + 怪兽开心蹦跳 + 三颗小心
// 上浮 + 等级名牌。非阻塞（IgnorePointer），总时长 1.9s 自动消散，串行
// 防重入与探头演出同口径。设计语言与 evolution_ceremony_overlay 呼应但
// 更轻：进化是全屏盛典（黑幕+彩带），羁绊是暖光小仪式（不遮内容）。
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:word_app/tokens/design_tokens.dart';
import 'package:word_app/widgets/monster_icon.dart';

/// 羁绊升级庆祝浮层。
class BondLevelUpOverlay {
  BondLevelUpOverlay._();

  /// 演出进行中标志（串行防重入；完成与销毁兜底都复位）。
  static bool _playing = false;

  static const Duration _rise = Duration(milliseconds: 450);
  static const Duration _hold = Duration(milliseconds: 1000);
  static const Duration _fade = Duration(milliseconds: 450);

  /// 展示一次羁绊升级仪式。[nextName] 为新等级名；[pointsToNext] 为距
  /// 下一级还差的点数（已满级传 null）。返回是否真的排上了演出。
  static bool show(BuildContext context, {required String levelName, int? pointsToNext}) {
    if (_playing) return false;
    final overlay = Overlay.of(context);
    _playing = true;
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _BondCeremony(
        levelName: levelName,
        pointsToNext: pointsToNext,
        rise: _rise,
        hold: _hold,
        fade: _fade,
        onDone: () {
          if (entry.mounted) entry.remove();
          _playing = false;
        },
        onDetached: () => _playing = false,
      ),
    );
    overlay.insert(entry);
    return true;
  }
}

class _BondCeremony extends StatefulWidget {
  final String levelName;
  final int? pointsToNext;
  final Duration rise;
  final Duration hold;
  final Duration fade;
  final VoidCallback onDone;
  final VoidCallback onDetached;

  const _BondCeremony({
    required this.levelName,
    required this.pointsToNext,
    required this.rise,
    required this.hold,
    required this.fade,
    required this.onDone,
    required this.onDetached,
  });

  @override
  State<_BondCeremony> createState() => _BondCeremonyState();
}

class _BondCeremonyState extends State<_BondCeremony> with TickerProviderStateMixin {
  late final AnimationController _ctrl;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.rise + widget.hold + widget.fade)..forward();
    Future<void>.delayed(widget.rise + widget.hold + widget.fade, () {
      if (mounted) _finish();
    });
  }

  void _finish() {
    if (_finished) return;
    _finished = true;
    widget.onDone();
  }

  @override
  void dispose() {
    if (!_finished) {
      _finished = true;
      widget.onDetached();
    }
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (context, child) {
            // 升起 → 停留 → 消散 的包络；reduce-motion 直接满透明度静现。
            final elapsed = _ctrl.duration! * _ctrl.value;
            double t;
            if (reduceMotion) {
              t = elapsed < widget.rise + widget.hold ? 1.0 : 0.0;
            } else if (elapsed <= widget.rise) {
              t = Curves.easeOutBack.transform((elapsed.inMilliseconds / widget.rise.inMilliseconds).clamp(0.0, 1.0));
            } else if (elapsed >= widget.rise + widget.hold) {
              final f = ((elapsed - widget.rise - widget.hold).inMilliseconds / widget.fade.inMilliseconds).clamp(
                0.0,
                1.0,
              );
              t = 1 - Curves.easeIn.transform(f);
            } else {
              t = 1;
            }
            return Opacity(
              opacity: t.clamp(0.0, 1.0),
              child: Transform.translate(offset: Offset(0, 24 * (1 - t.clamp(0.0, 1.0))), child: child),
            );
          },
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 三颗小心错峰上浮（静态心形，与怪兽家族的有机圆润语言一致）。
                SizedBox(
                  width: 150,
                  height: 36,
                  child: AnimatedBuilder(
                    animation: _ctrl,
                    builder: (context, _) {
                      final phase = _ctrl.value * (widget.rise + widget.hold + widget.fade).inMilliseconds;
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (final i in [0, 1, 2])
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              child: Opacity(
                                opacity: reduceMotion
                                    ? 0.9
                                    : (0.35 + 0.55 * math.sin(phase / 700 + i * 1.1)).abs().clamp(0.2, 0.95),
                                child: Icon(
                                  Icons.favorite_rounded,
                                  size: 18 + 4.0 * (i == 1 ? 1 : 0),
                                  color: MwColors.danger,
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                // 怪兽开心蹦跳：周期缩放过冲（reduce-motion 静态）。
                AnimatedBuilder(
                  animation: _ctrl,
                  builder: (context, child) {
                    if (reduceMotion) return child!;
                    final hop = math.sin(2 * math.pi * ((_ctrl.value * 3) % 1.0)).abs();
                    return Transform.translate(offset: Offset(0, -10 * hop), child: child);
                  },
                  child: const MonsterIcon(size: 108, mouthOpen: 0.55, cheekPuff: 0.35),
                ),
                const SizedBox(height: AppSpacing.md),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
                  decoration: const ShapeDecoration(
                    color: MwColors.sunshine300,
                    shape: StadiumBorder(),
                    shadows: [BoxShadow(color: MwShadows.softShadow, blurRadius: 14, offset: Offset(0, 5))],
                  ),
                  child: Text(
                    '羁绊升级 · ${widget.levelName}',
                    style: MwTypography.heading5.copyWith(fontWeight: FontWeight.w700, color: MwColors.charcoal),
                  ),
                ),
                if (widget.pointsToNext != null)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xs),
                    child: Text(
                      '再相处 ${widget.pointsToNext} 天，关系会更进一步',
                      style: MwTypography.caption.copyWith(color: MwColors.charcoal.withValues(alpha: AppAlphas.o80)),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
