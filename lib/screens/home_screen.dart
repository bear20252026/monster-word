// 由账号4生成
// 首页：Apple Design Language — 纯色背景 + HeroWord + 入口卡 + 查词按钮
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

    final heroWord = state.currentWord?.word ?? 'Monster Word';

    return AppleBg(
      child: SafeArea(
        child: Column(
          children: [
            // 顶部栏：头像 + 查词按钮
            Padding(
              padding: EdgeInsets.fromLTRB(resp.pageMargin, 12, resp.pageMargin, 0),
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
                        color: skin.colors.cardBgAlt,
                        shape: BoxShape.circle,
                        border: Border.all(color: skin.colors.divider),
                      ),
                      child: Icon(Icons.search, color: skin.colors.text3, size: 20),
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(flex: 2),
            // HeroWord（居中偏上）
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  Text(
                    heroWord,
                    style: AppTypography.heroWord.copyWith(
                      fontSize: resp.heroFontSize,
                      color: skin.colors.text1,
                    ),
                  ),
                  if (state.currentWord != null &&
                      state.currentWord!.usPron.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      '/${state.currentWord!.usPron}/',
                      style: AppTypography.caption.copyWith(
                        color: skin.colors.text3,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Spacer(flex: 1),
            // Learn/Review 入口卡（上移）
            Padding(
              padding: EdgeInsets.fromLTRB(resp.pageMargin, 0, resp.pageMargin, 40),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AppleEntryCard(
                    title: 'Learn',
                    count: state.total > 0 ? state.total : 0,
                    width: resp.glassCardWidth,
                    onTap: () =>
                        Navigator.pushNamed(context, LibSelectPage.routeName),
                  ),
                  const SizedBox(width: 12),
                  AppleEntryCard(
                    title: 'Review',
                    count: state.dueCount,
                    width: resp.glassCardWidth,
                    onTap: () =>
                        Navigator.pushNamed(context, ReviewSession.routeName),
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

/// 头像（Apple 风格：纯色圆形 + 人物图标）
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
        color: skin.colors.cardBgAlt,
        border: Border.all(color: skin.colors.divider),
      ),
      child: Icon(Icons.person, color: skin.colors.text3, size: 22),
    );
  }
}
