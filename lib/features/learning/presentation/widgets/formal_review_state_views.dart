import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:word_app/core/presentation/responsive.dart';
import 'package:word_app/core/utils/boss_siege.dart';
import 'package:word_app/core/utils/haptics_gate.dart';
import 'package:word_app/core/utils/monster_voice.dart';
import 'package:word_app/core/utils/sfx.dart';
import 'package:word_app/core/utils/swallowed_error_report.dart';
// M3：XP / 等级（跨 feature 只 import application 层，架构守卫 R4 允许）。
import 'package:word_app/features/progress/application/xp_store.dart';
import 'package:word_app/theme/skin_system.dart';
import 'package:word_app/tokens/design_tokens.dart';
import 'package:word_app/widgets/mw_button.dart';

/// 正式复习加载中的统一页面：品牌话术 + 主题化加载环。
class FormalReviewLoadingView extends StatelessWidget {
  const FormalReviewLoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    final skin = context.skin.colors;
    return Scaffold(
      backgroundColor: skin.pageBg,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(width: 30, height: 30, child: CircularProgressIndicator(strokeWidth: 3, color: skin.accent)),
            const SizedBox(height: 20),
            Text('正在准备今天的复习…', style: MwTypography.bodySm.copyWith(color: skin.text3)),
          ],
        ),
      ),
    );
  }
}

/// 正式复习加载失败页面：品牌化错误 + 胶囊重试。
class FormalReviewLoadErrorView extends StatelessWidget {
  const FormalReviewLoadErrorView({super.key, required this.error, required this.onRetry});

  final Object? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin.colors;
    return Scaffold(
      backgroundColor: skin.pageBg,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: skin.danger.withValues(alpha: AppAlphas.o10),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.refresh_rounded, color: skin.danger, size: 30),
              ),
              const SizedBox(height: 20),
              Text('复习数据加载失败', style: MwTypography.heading4.copyWith(color: skin.text1)),
              const SizedBox(height: 8),
              Text(
                '别担心，稍后重试即可。',
                textAlign: TextAlign.center,
                style: MwTypography.bodySm.copyWith(color: skin.text3),
              ),
              const SizedBox(height: 24),
              MwButton(label: '重试', onTap: onRetry, minWidth: 160),
            ],
          ),
        ),
      ),
    );
  }
}

/// 经验结算胶囊（M3/D4）：只在复习完成页出现。
class _XpResultPill extends StatelessWidget {
  const _XpResultPill({
    required this.awarded,
    required this.toNextLevel,
    required this.levelUpLevel,
    required this.colors,
  });

  final int awarded;
  final int? toNextLevel;
  final int? levelUpLevel;
  final ThemeVars colors;

  @override
  Widget build(BuildContext context) {
    final levelUp = levelUpLevel;
    final text = levelUp != null ? '升级到 Lv.$levelUp！' : '经验 +$awarded · 升级还需 $toNextLevel';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: colors.accent.withValues(alpha: AppAlphas.o12),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: colors.accent.withValues(alpha: AppAlphas.o40)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            levelUp != null ? Icons.arrow_upward_rounded : Icons.auto_awesome_rounded,
            size: 15,
            color: colors.accent,
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: MwTypography.caption.copyWith(fontWeight: FontWeight.w700, color: colors.accent),
          ),
        ],
      ),
    );
  }
}

/// 正式复习完成页面：情绪收尾瞬间——绿色完成环 + 衬线大数字 + 胶囊返回。
///
/// 「Boss 战围城」的守城庆典挂在这里：真的击退过（done>0）才放里程碑音、才让怪兽开口。
class FormalReviewCompleteView extends StatefulWidget {
  const FormalReviewCompleteView({
    super.key,
    required this.done,
    required this.onReturnHome,
    this.correct,
    this.xpEventKey,
    this.bossBattle = false,
    this.celebrationOverride,
  });

  final int done;

  /// 本局答对数（M3 复习同计 XP）；未传时按全对处理。
  final int? correct;

  /// 本局 XP 的幂等事件键（M3）；为空时不结算经验，避免重复发放。
  final String? xpEventKey;
  final VoidCallback onReturnHome;

  /// 本局是否以头目战收尾：为 true 且真的答过题时，完成页说头目退场台词。
  final bool bossBattle;

  /// 测试注入缝：非空时替代真实庆典副作用（音效/触觉/语音），用于验证
  /// 「一局只播一次」。生产传 null，走既有 [SfxPlayer]/[HapticsGate]/[MonsterVoice]。
  final VoidCallback? celebrationOverride;

  @override
  State<FormalReviewCompleteView> createState() => _FormalReviewCompleteViewState();
}

class _FormalReviewCompleteViewState extends State<FormalReviewCompleteView> {
  bool _celebrated = false;

  /// M3/D4：本局 XP 展示（复习同计；不进商店）。
  int? _xpAwarded;
  int? _xpToNextLevel;
  int? _levelUpLevel;

  @override
  void initState() {
    super.initState();
    if (widget.done > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _celebrate());
      WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_grantXp()));
    }
  }

  /// 复习一局同样结算 XP：答对 ×2 + 完成 10；升级只庆祝一次（无额外音效，避免与守城庆典重叠）。
  ///
  /// [FormalReviewCompleteView.xpEventKey] 是本局幂等键：重建/重挂载不会重复加经验。
  Future<void> _grantXp() async {
    if (!mounted) return;
    final store = context.read<XpStore?>();
    if (store == null) return;
    final eventKey = widget.xpEventKey;
    // 没有本局标识就不结算：宁可这次不显示经验，也不能重复发。
    if (eventKey == null || eventKey.isEmpty) return;
    try {
      final correct = (widget.correct ?? widget.done).clamp(0, widget.done);
      final result = await store.grantSession(
        eventKey: eventKey,
        answered: widget.done,
        correct: correct,
        completed: true,
      );
      if (!mounted || result.awarded <= 0) return;
      setState(() {
        _xpAwarded = result.awarded;
        _xpToNextLevel = result.snapshot.xpToNextLevel;
      });
      final newLevel = result.newLevel;
      if (newLevel == null) return;
      if (!await store.claimLevelUpCelebration(newLevel)) return;
      if (!mounted) return;
      setState(() => _levelUpLevel = newLevel);
    } catch (e, s) {
      reportSwallowedError('复习会话 XP 结算失败', e, s);
    }
  }

  /// 守城成功收尾：里程碑音 + heavy 触觉 + 怪兽说出那句「这一城是你守住的」。
  ///
  /// 一题都没答（今天本来没有到期词）时不进来——没打过仗不能说守住了；
  /// post-frame 而非 build 内触发，避免在构建期发副作用（同族仪式浮层口径）。
  /// [_celebrated] 是唯一开关：重建/父级重绘都不会让庆典播第二次。
  void _celebrate() {
    if (_celebrated || !mounted) return;
    _celebrated = true;
    final override = widget.celebrationOverride;
    if (override != null) {
      override();
      return;
    }
    SfxPlayer.fire(Sfx.milestone);
    HapticsGate.play(HapticCue.heavy);
    unawaited(MonsterVoice.system.say(_victoryLine));
  }

  /// 头目战用退场台词；普通复习局沿用 v1 的守城台词。
  String get _victoryLine => widget.bossBattle ? bossVictoryLine : siegeVictoryLine;

  /// 副标题：头目战（且真的答过题）说头目退场；其余保持既有两分支。
  String get _subtitle {
    if (widget.bossBattle && widget.done > 0) return bossVictoryLine;
    return widget.done > 0 ? '已把今天到期的单词又牢牢记住了一遍' : siegeQuietLine;
  }

  @override
  Widget build(BuildContext context) {
    final done = widget.done;
    final skin = context.skin.colors;
    final resp = context.responsive;
    return Scaffold(
      backgroundColor: skin.pageBg,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 完成环 + 衬线完成数
            SizedBox(
              width: 128,
              height: 128,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 116,
                    height: 116,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: skin.success.withValues(alpha: AppAlphas.o08),
                      border: Border.all(color: skin.success.withValues(alpha: AppAlphas.o35), width: 1),
                    ),
                  ),
                  Icon(Icons.check_rounded, color: skin.success, size: 40),
                  Positioned(
                    bottom: 18,
                    child: Text(
                      '$done',
                      style: TextStyle(
                        fontFamily: 'Charter',
                        fontSize: AppFontSizes.displaySm,
                        fontStyle: FontStyle.italic,
                        color: skin.success,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              '今日复习完成！',
              style: TextStyle(
                fontFamily: 'Charter',
                fontSize: AppFontSizes.statSm * resp.fontScale,
                fontWeight: FontWeight.w400,
                letterSpacing: -0.5,
                color: skin.text1,
              ),
            ),
            const SizedBox(height: 8),
            // done==0 时不能说「已把今天到期的单词记住了」——今天根本没有到期词。
            Text(_subtitle, style: MwTypography.bodySm.copyWith(color: skin.text3)),
            if (_xpAwarded != null) ...[
              const SizedBox(height: 12),
              _XpResultPill(
                awarded: _xpAwarded!,
                toNextLevel: _xpToNextLevel,
                levelUpLevel: _levelUpLevel,
                colors: skin,
              ),
            ],
            const SizedBox(height: 28),
            MwButton(label: '返回首页', onTap: widget.onReturnHome, minWidth: 180),
          ],
        ),
      ),
    );
  }
}
