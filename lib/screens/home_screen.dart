// 由账号4生成
// L3 首页：壁纸背景 + HeroWord + Learn/Review 玻璃入口卡 + 透明底 Tab
// 翻译自 Figma 03a-screens-learning.json home
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../hooks/responsive.dart';
import '../pages/lib_select_page.dart';
import '../pages/search_page.dart';
import '../screens/review_session.dart';
import '../state/learning_state.dart';
import '../theme/skin_system.dart';
import '../tokens/design_tokens.dart';
import '../widgets/glass_widgets.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final resp = context.responsive;
    final state = context.watch<LearningState>();

    // HeroWord：优先显示当前词，否则显示示例词
    final heroWord = state.currentWord?.word ?? 'Fragrance';

    return WallpaperBg(
      child: SafeArea(
        child: Stack(
          children: [
            // 左上角：头像 + 查词按钮
            Positioned(
              left: resp.pageMargin,
              top: 12,
              child: Row(
                children: [
                  _Avatar(skin: skin),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () => Navigator.pushNamed(context, SearchPage.routeName),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.25),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
                      ),
                      child: const Icon(Icons.search, color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ),
            // HeroWord（居中，原版 40dp 粗体）
            Center(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 120),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      heroWord,
                      style: AppTypography.heroWord.copyWith(
                        fontSize: resp.heroFontSize,
                        color: skin.colors.onGlassText1,
                      ),
                    ),
                    if (state.currentWord != null) ...[
                      const SizedBox(height: 8),
                      if (state.currentWord!.usPron.isNotEmpty)
                        Text(
                          '/${state.currentWord!.usPron}/',
                          style: AppTypography.caption.copyWith(
                            color: skin.colors.onGlassText2,
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ),
            // Learn/Review 玻璃入口卡（底部上方）
            Positioned(
              left: resp.pageMargin,
              right: resp.pageMargin,
              bottom: resp.tabBarHeight + 32,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GlassCard(
                    title: 'Learn',
                    count: state.total > 0 ? state.total : 0,
                    width: resp.glassCardWidth,
                    onTap: () {
                      Navigator.pushNamed(context, LibSelectPage.routeName);
                    },
                  ),
                  const SizedBox(width: 12),
                  GlassCard(
                    title: 'Review',
                    count: state.dueCount,
                    width: resp.glassCardWidth,
                    onTap: () {
                      Navigator.pushNamed(context, ReviewSession.routeName);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 头像组件（原版品牌 Logo 位置）
class _Avatar extends StatelessWidget {
  final SkinSystem skin;
  const _Avatar({required this.skin});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.35),
        border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
      ),
      child: const Icon(Icons.person, color: Colors.white, size: 22),
    );
  }
}
