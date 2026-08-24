// 由 Claude 团队生成 | Monster Word App

// 由账号4生成
// 首页：Mistral AI 设计风格 — 奶油黄背景 + 日落渐变条 + Charter 衬线 HeroWord
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/wallpaper_data.dart';
import '../hooks/responsive.dart';
import '../pages/lib_select_page.dart';
import '../pages/search_page.dart';
import '../pages/word_machine_page.dart';
import '../screens/review_session.dart';
import '../state/learning_state.dart';
import '../state/wallpaper_state.dart';
import '../theme/skin_system.dart';
import '../tokens/design_tokens.dart';
import '../widgets/glass_widgets.dart';
import '../widgets/review_dialog.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  String _formatDate() {
    final now = DateTime.now();
    const weekdays = ['Mon.', 'Tue.', 'Wed.', 'Thu.', 'Fri.', 'Sat.', 'Sun.'];
    return '${now.month.toString().padLeft(2, '0')}/${now.day.toString().padLeft(2, '0')} ${weekdays[now.weekday - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final resp = context.responsive;
    final state = context.watch<LearningState>();
    final wallpaper = context.watch<WallpaperState>().current;

    return _WallpaperBg(
      wallpaper: wallpaper,
      fallbackColor: skin.colors.pageBg,
      child: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                const Spacer(flex: 2),
                // 签到卡片（毛玻璃）
                Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                      child: Container(
                        width: 160,
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.55),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withOpacity(0.3), width: 0.5),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.calendar_today_outlined, size: 30, color: skin.colors.text1),
                            const SizedBox(height: 10),
                            Text('签到',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: skin.colors.text1)),
                            const SizedBox(height: 4),
                            Text(_formatDate(),
                              style: TextStyle(fontSize: 14, color: skin.colors.text2)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const Spacer(flex: 2),
                // Learn / Review 入口卡
                Padding(
                  padding: EdgeInsets.fromLTRB(resp.pageMargin, 0, resp.pageMargin, 16),
                  // 卡片宽度受实际约束限制：AdaptiveScale 缩放框架下窗口 MediaQuery 与布局宽度不一致，
                  // 固定 glassCardWidth 会导致 Learn/Review 行溢出（见 docs/qa_baseline.md）
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final double cardW = math.min(
                        resp.glassCardWidth,
                        (constraints.maxWidth - 12) / 2,
                      );
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          GlassEntryCard(
                            title: 'Learn',
                            count: state.total > 0 ? state.total : 0,
                            width: cardW,
                            onTap: () => Navigator.pushNamed(context, LibSelectPage.routeName),
                          ),
                          const SizedBox(width: 12),
                          GlassEntryCard(
                            title: 'Review',
                            count: state.dueCount,
                            width: cardW,
                            onTap: () => showReviewDialog(context),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          // 右上角：不背单词机入口
          Positioned(
            top: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(right: 12, top: 12),
                child: GestureDetector(
                  onTap: () => Navigator.pushNamed(context, WordMachinePage.routeName),
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFF9BBC0F),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Text(
                        'BB',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0F380F),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // 左上角浮动按钮
          Positioned(
            top: 0,
            left: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(left: 12, top: 12),
                child: GestureDetector(
                  onTap: () => Navigator.pushNamed(context, SearchPage.routeName),
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFFF3CD),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.menu_book_rounded, color: Color(0xFF8B6914), size: 24),
                  ),
                ),
              ),
            ),
          ),
          // 下滑查词提示覆盖层
          Positioned(
            top: MediaQuery.of(context).size.height * 0.3,
            left: MediaQuery.of(context).size.width * 0.15,
            right: MediaQuery.of(context).size.width * 0.15,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('下滑查词',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
                      const SizedBox(height: 16),
                      // 手机插图
                      Container(
                        width: 120,
                        height: 180,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Stack(
                          children: [
                            // 模拟手机内容
                            Positioned(
                              top: 20, left: 12, right: 12,
                              child: Column(
                                children: [
                                  Container(height: 6, width: double.infinity,
                                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.3), borderRadius: BorderRadius.circular(3))),
                                  const SizedBox(height: 8),
                                  Container(height: 6, width: double.infinity,
                                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.3), borderRadius: BorderRadius.circular(3))),
                                  const SizedBox(height: 8),
                                  Container(height: 6, width: 80,
                                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.3), borderRadius: BorderRadius.circular(3))),
                                ],
                              ),
                            ),
                            // 键盘模拟
                            Positioned(
                              bottom: 10, left: 8, right: 8,
                              child: Container(
                                height: 50,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                            // 手指图标
                            Positioned(
                              bottom: 60, right: 30,
                              child: Icon(Icons.touch_app, color: const Color(0xFFFFCC80), size: 40),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 壁纸背景组件：根据壁纸类型显示对应背景
class _WallpaperBg extends StatelessWidget {
  final WallpaperItem wallpaper;
  final Color fallbackColor;
  final Widget child;

  const _WallpaperBg({
    required this.wallpaper,
    required this.fallbackColor,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (wallpaper.type == WallpaperType.image && wallpaper.assetPath != null) {
      return Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage(wallpaper.assetPath!),
            fit: BoxFit.cover,
            onError: (_, __) {},
          ),
        ),
        child: child,
      );
    }

    if (wallpaper.type == WallpaperType.gradient && wallpaper.colors != null) {
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: wallpaper.colors!,
            begin: wallpaper.begin ?? Alignment.topCenter,
            end: wallpaper.end ?? Alignment.bottomCenter,
          ),
        ),
        child: child,
      );
    }

    // 纯色
    return Container(
      color: wallpaper.colors?.first ?? fallbackColor,
      child: child,
    );
  }
}
