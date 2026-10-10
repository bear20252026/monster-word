// EvolutionCeremonyOverlay：进化全屏仪式（签到累计天数跨越 7/30/100 阈值时触发）。
//
// 演出编排：黑场淡入 → 旧形态淡出与新形态淡入交叉（放大 springPop，抽帧定格感）
// → 庆祝彩带（100 粒上限守卫内）→ 文案 → 2.2s 自动关或点击关。
// 串行防重入：演出中的新 show 请求直接忽略（静态开关，完成/销毁双兜底复位）。
// 范式与时长字面量惯例同 monster_peek_overlay.dart（仪式性长演出不落
// MotionDurations 档位，避免动效卫生棘轮误锁）。
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:word_app/core/utils/swallowed_error_report.dart';
import 'package:word_app/features/checkin/application/checkin_status_reader.dart';
import 'package:word_app/features/scare_coin/application/scare_coin_store.dart';

import 'package:word_app/core/utils/monster_speech.dart';
import 'package:word_app/core/utils/monster_voice.dart';
import 'package:word_app/tokens/design_tokens.dart';
import 'package:word_app/tokens/effect_palette.dart';
import 'package:word_app/tokens/motion_tokens.dart';
import 'package:word_app/widgets/confetti.dart';
import 'package:word_app/widgets/monster_icon.dart';

/// 进化仪式全屏浮层。
class EvolutionCeremonyOverlay {
  EvolutionCeremonyOverlay._();

  /// 演出进行中标志（串行防重入）。
  static bool _showing = false;

  // 各段时长：淡入 300ms + 形态交叉 1200ms + 文案随交叉段弹出；总驻留 2.2s。
  static const Duration _fadeIn = Duration(milliseconds: 300);
  static const Duration _cross = Duration(milliseconds: 1200);
  static const Duration _totalHold = Duration(milliseconds: 2200);

  /// 展示一次进化仪式（from → to 形态交叉）。演出中的重复调用被忽略。
  static void show(BuildContext context, {required int fromStage, required int toStage}) {
    if (_showing || fromStage == toStage) return;
    final overlay = Overlay.of(context);
    _showing = true;
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _EvolutionCeremony(
        fromStage: fromStage,
        toStage: toStage,
        fadeIn: _fadeIn,
        cross: _cross,
        totalHold: _totalHold,
        onDone: () {
          if (entry.mounted) entry.remove();
          _showing = false;
        },
        onDetached: () => _showing = false,
      ),
    );
    overlay.insert(entry);
  }
}

/// 仪式演出层：黑场 + 形态交叉 + 彩带 + 文案。
class _EvolutionCeremony extends StatefulWidget {
  final int fromStage;
  final int toStage;
  final Duration fadeIn;
  final Duration cross;
  final Duration totalHold;

  /// 演出完成：移除 entry 并复位防重入开关。
  final VoidCallback onDone;

  /// entry 被外部回收（宿主提前销毁）兜底：仅复位开关。
  final VoidCallback onDetached;

  const _EvolutionCeremony({
    required this.fromStage,
    required this.toStage,
    required this.fadeIn,
    required this.cross,
    required this.totalHold,
    required this.onDone,
    required this.onDetached,
  });

  @override
  State<_EvolutionCeremony> createState() => _EvolutionCeremonyState();
}

class _EvolutionCeremonyState extends State<_EvolutionCeremony> with TickerProviderStateMixin {
  late final AnimationController _fadeCtrl;
  late final AnimationController _crossCtrl;
  late final ConfettiController _confettiCtrl;
  late final Animation<double> _fadeAnim;
  late final Animation<double> _outAnim;
  late final Animation<double> _inAnim;
  late final Animation<double> _scaleAnim;
  bool _finished = false;

  /// 进化台词（带真实变量的 milestone 槽；TTS 之外也上屏——静音/缺语音包
  /// 用户此前完全感知不到这句「它说了什么」）。
  String _milestoneLine = '';

  @override
  void initState() {
    super.initState();
    unawaited(_loadMilestoneLine());
    _fadeCtrl = AnimationController(vsync: this, duration: widget.fadeIn);
    _crossCtrl = AnimationController(vsync: this, duration: widget.cross);
    _confettiCtrl = ConfettiController();
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _outAnim = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(
        parent: _crossCtrl,
        curve: const Interval(0, 0.5, curve: Curves.easeIn),
      ),
    );
    _inAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _crossCtrl,
        curve: const Interval(0.35, 1, curve: Curves.easeOut),
      ),
    );
    // 抽帧定格感：旧形态淡出完成后新形态 springPop 破光站立。
    _scaleAnim = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(
        parent: _crossCtrl,
        curve: const Interval(0.35, 1, curve: MotionCurves.springPop),
      ),
    );
    _fadeCtrl.forward().whenComplete(() {
      if (!mounted) return;
      _crossCtrl.forward();
      _confettiCtrl.play();
      // 「怪兽开口」第三刻：新形态现身那一刻说出进化台词——这也是 MonsterSpeech 的
      // milestone 槽首次接进生产（此前只有测试消费）。闸门拦下则只有画面，无声音。
      unawaited(MonsterVoice.system.say(_milestoneLine.isEmpty ? '你的怪兽长出了新形态！' : _milestoneLine));
    });
    // 总驻留后自动关（点击关共用 _finish，幂等）。
    Future<void>.delayed(widget.totalHold, () {
      if (mounted) _finish();
    });
  }

  /// 载入带真实数据的 milestone 台词：days/streak/balance 全注入（此前只注入
  /// stage，6 条模板中 4 条含其它占位符被永久过滤——「第 N 天！」「连击 xN！」
  /// 之类庆祝文案不可达）。读不到的槽位保持 null，引擎自动跳过含槽模板。
  Future<void> _loadMilestoneLine() async {
    var vars = <String, Object?>{'stage': MonsterIcon.stageName(widget.toStage)};
    try {
      final reader = context.read<CheckinStatusReader?>();
      final store = context.read<ScareCoinStore?>();
      int? days;
      int? streak;
      if (reader != null) {
        final results = await Future.wait([reader.getCheckinDates(), reader.getStreakDays()]);
        days = (results[0] as Set<String>).length;
        streak = results[1] as int;
      }
      int? balance;
      if (store != null) balance = await store.balance();
      vars = {'days': days, 'streak': streak, 'balance': balance, 'stage': MonsterIcon.stageName(widget.toStage)};
    } catch (e, s) {
      reportSwallowedError('进化仪式台词变量读取失败', e, s);
    }
    if (!mounted) return;
    setState(() => _milestoneLine = MonsterSpeech().pick(SpeechSlot.milestone, vars: vars));
  }

  void _finish() {
    if (_finished) return;
    _finished = true;
    widget.onDone();
  }

  @override
  void dispose() {
    // 宿主提前销毁（页面退出/测试拆树）兜底：复位防重入开关。
    if (!_finished) {
      _finished = true;
      widget.onDetached();
    }
    _fadeCtrl.dispose();
    _crossCtrl.dispose();
    _confettiCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: AnimatedBuilder(
        animation: Listenable.merge([_fadeCtrl, _crossCtrl]),
        builder: (context, child) {
          final bg = _fadeAnim.value;
          return ColoredBox(
            color: Colors.black.withValues(alpha: AppAlphas.o90 * bg),
            child: bg < 1
                ? const SizedBox.shrink()
                : GestureDetector(
                    onTap: _finish,
                    behavior: HitTestBehavior.opaque,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        ConfettiOverlay(
                          controller: _confettiCtrl,
                          particleCount: 100,
                          colors: GradientEffects.celebration,
                          duration: const Duration(milliseconds: 2200),
                          child: const SizedBox.shrink(),
                        ),
                        // 旧形态淡出层。
                        Opacity(
                          opacity: _outAnim.value,
                          child: MonsterIcon(size: 160, evoStage: widget.fromStage),
                        ),
                        // 新形态破光层：淡入 + springPop 放大。
                        Opacity(
                          opacity: _inAnim.value,
                          child: Transform.scale(
                            scale: _scaleAnim.value,
                            child: MonsterIcon(size: 160, evoStage: widget.toStage),
                          ),
                        ),
                        // 文案：交叉段后半程浮现。
                        Positioned(
                          bottom: 96,
                          child: Opacity(
                            opacity: _inAnim.value,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
                              decoration: const ShapeDecoration(
                                color: MwColors.sunshine300,
                                shape: StadiumBorder(),
                                shadows: [BoxShadow(color: MwShadows.softShadow, blurRadius: 16, offset: Offset(0, 6))],
                              ),
                              child: Text(
                                '你的怪兽长出了新形态！',
                                style: MwTypography.titleLg.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: MwColors.charcoal,
                                ),
                              ),
                            ),
                          ),
                        ),
                        // 它说的那句话也上屏（TTS 之外的第二通道）。
                        if (_milestoneLine.isNotEmpty)
                          Positioned(
                            bottom: 58,
                            child: Opacity(
                              opacity: _inAnim.value,
                              child: Text(
                                _milestoneLine,
                                style: MwTypography.bodyMd.copyWith(color: MwColors.charcoal.withValues(alpha: AppAlphas.o85)),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
          );
        },
        child: const SizedBox.shrink(),
      ),
    );
  }
}
