import 'package:flutter/material.dart';

import 'package:word_app/core/presentation/responsive.dart';
import 'package:word_app/features/learning/presentation/learning_session_state.dart';
import 'package:word_app/theme/skin_system.dart';
import 'package:word_app/tokens/design_tokens.dart';

/// M4 中途收工提示：答满 [LearningSessionState.midSessionCheckpointWords] 词后
/// 出现一次，非阻塞（不遮题、不弹窗），「继续」收起、「今天到这儿」直接结算。
class MidSessionBreakBanner extends StatelessWidget {
  const MidSessionBreakBanner({super.key, required this.state});

  final LearningSessionState state;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final resp = context.responsive;
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        if (!state.shouldOfferMidSessionBreak) return const SizedBox.shrink();
        return Padding(
          padding: EdgeInsets.fromLTRB(resp.horizontalPadding, 0, resp.horizontalPadding, AppSpacing.xs),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.md * resp.scale, vertical: AppSpacing.xs * resp.scale),
            decoration: BoxDecoration(
              color: skin.colors.cardBg,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: skin.colors.divider, width: 0.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '已经答完 ${LearningSessionState.midSessionCheckpointWords} 个词，接着来还是今天到这儿？',
                  style: TextStyle(
                    fontSize: AppFontSizes.caption * resp.fontScale,
                    color: skin.colors.text2,
                    height: 1.3,
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(
                        onPressed: state.markMidSessionPromptShown,
                        style: TextButton.styleFrom(
                          foregroundColor: skin.colors.accent,
                          minimumSize: const Size(0, 32),
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          '继续',
                          style: TextStyle(
                            fontSize: AppFontSizes.caption * resp.fontScale,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: state.finishSessionEarly,
                        style: TextButton.styleFrom(
                          foregroundColor: skin.colors.text2,
                          minimumSize: const Size(0, 32),
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text('今天到这儿', style: TextStyle(fontSize: AppFontSizes.caption * resp.fontScale)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
