// 首启引导：三步角色对话 + 一句承诺（只出现一次、可跳过）。
//
// 触发点在 app 壳层（首次打开判定），本组件只负责呈现：不读 SP、不做埋点。
// 视觉沿用皮肤 token（cardBg/accent/text1/text3/divider），不引入第三方素材。
import 'package:flutter/material.dart';

import 'package:word_app/features/learning/application/onboarding_gate_store.dart';
import 'package:word_app/theme/skin_system.dart';
import 'package:word_app/tokens/design_tokens.dart';
import 'package:word_app/tokens/motion_tokens.dart';
import 'package:word_app/widgets/monster_icon.dart';

/// 展示一次首启引导；关闭后 Future 完成。
Future<void> showOnboardingPromiseDialog(BuildContext context) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: false, // 跳过是显式按钮，避免误触空白区
    barrierLabel: '首启引导',
    transitionDuration: MotionDurations.base,
    pageBuilder: (context, animation, secondaryAnimation) => const OnboardingPromiseDialog(),
    transitionBuilder: (context, animation, secondaryAnimation, child) =>
        FadeTransition(opacity: animation, child: child),
  );
}

/// 三步对话 + 一句承诺。
class OnboardingPromiseDialog extends StatefulWidget {
  const OnboardingPromiseDialog({super.key});

  @override
  State<OnboardingPromiseDialog> createState() => _OnboardingPromiseDialogState();
}

class _OnboardingPromiseDialogState extends State<OnboardingPromiseDialog> {
  int _step = 0;

  bool get _isLastStep => _step >= onboardingSteps.length - 1;

  void _next() {
    if (_isLastStep) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _step += 1);
  }

  void _skip() => Navigator.of(context).pop();

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final colors = skin.colors;
    final step = onboardingSteps[_step];
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.xl),
            decoration: BoxDecoration(
              color: colors.cardBg,
              borderRadius: BorderRadius.circular(AppRadius.sheet),
              border: Border.all(color: colors.divider),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: colors.accent.withValues(alpha: AppAlphas.o12),
                        shape: BoxShape.circle,
                      ),
                      child: MonsterIcon(size: 40, showCircle: false),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: _skip,
                      style: TextButton.styleFrom(foregroundColor: colors.text3),
                      child: const Text('跳过', style: TextStyle(fontSize: AppFontSizes.caption)),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  '第 ${_step + 1} / ${onboardingSteps.length} 步',
                  style: MwTypography.micro.copyWith(color: colors.text3),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  step.line,
                  style: MwTypography.displaySm.copyWith(fontWeight: FontWeight.bold, color: colors.text1),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(step.caption, style: MwTypography.bodyMd.copyWith(color: colors.text2)),
                if (_isLastStep) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: colors.accent.withValues(alpha: AppAlphas.o10),
                      borderRadius: BorderRadius.circular(AppRadius.control),
                      border: Border.all(color: colors.accent.withValues(alpha: AppAlphas.o30)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle_rounded, size: 18, color: colors.accent),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            onboardingPromise,
                            style: MwTypography.bodySm.copyWith(fontWeight: FontWeight.w700, color: colors.accent),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.xl),
                _buildDots(colors),
                const SizedBox(height: AppSpacing.lg),
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.accent,
                      foregroundColor: colors.onGlassAccent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                    ),
                    onPressed: _next,
                    child: Text(
                      _isLastStep ? '开始今天的第一个词' : '下一步',
                      style: const TextStyle(fontSize: AppFontSizes.bodyMd, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDots(dynamic colors) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < onboardingSteps.length; i++) ...[
          if (i > 0) const SizedBox(width: AppSpacing.xs),
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: i == _step ? colors.accent : colors.text3.withValues(alpha: AppAlphas.o40),
              shape: BoxShape.circle,
            ),
          ),
        ],
      ],
    );
  }
}
