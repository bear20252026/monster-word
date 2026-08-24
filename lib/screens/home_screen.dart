// Monster Word — 首页（星巴克改造 batch4a）
// 方案C：画布归品牌，移除壁纸系统，奶油画布 + ContentCard 白卡
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../hooks/responsive.dart';
import '../pages/lib_select_page.dart';
import '../pages/search_page.dart';
import '../pages/word_machine_page.dart';
import '../state/learning_state.dart';
import '../theme/skin_system.dart';
import '../tokens/design_tokens.dart';
import '../widgets/sb_card.dart';
import '../widgets/review_dialog.dart';
import '../widgets/scale_down_on_press.dart';

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

    // 方案C：奶油画布，移除壁纸系统
    // 下滑查词：在首页任意位置向下滑动打开查词页（提示卡也可直接点击）
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragEnd: (details) {
        final v = details.primaryVelocity ?? 0;
        if (v > 160) Navigator.pushNamed(context, SearchPage.routeName);
      },
      child: Container(
      color: skin.colors.pageBg,
      child: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                const Spacer(flex: 2),
                _buildCheckInCard(skin),
                const Spacer(flex: 2),
                Padding(
                  padding: EdgeInsets.fromLTRB(resp.pageMargin, 0, resp.pageMargin, 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: _EntryCard(
                          title: 'Learn',
                          count: state.total > 0 ? state.total : 0,
                          onTap: () => Navigator.pushNamed(context, LibSelectPage.routeName),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _EntryCard(
                          title: 'Review',
                          count: state.dueCount,
                          onTap: () => showReviewDialog(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // 右上角：单词机入口（GameBoy 风格保留，word_machine 豁免）
          Positioned(top: 0, right: 0, child: _buildWordMachineButton(context, skin)),
          // 左上角：查词入口（SbCard 风格圆形按钮）
          Positioned(top: 0, left: 0, child: _buildSearchButton(context, skin)),
          // 下滑查词提示覆盖层（SbCard 风格，移除毛玻璃）
          Positioned(
            top: MediaQuery.of(context).size.height * 0.3,
            left: MediaQuery.of(context).size.width * 0.15,
            right: MediaQuery.of(context).size.width * 0.15,
            child: _buildSwipeHintOverlay(context, skin),
          ),
        ],
      ),
      ),
    );
  }

  /// 签到卡片（SbCard 白卡，替代毛玻璃）
  Widget _buildCheckInCard(SkinSystem skin) {
    return Center(
      child: SbCard(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 24),
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
    );
  }

  /// 右上角单词机入口按钮
  Widget _buildWordMachineButton(BuildContext context, SkinSystem skin) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(right: 12, top: 12),
        child: ScaleDownOnPress(
          onTap: () => Navigator.pushNamed(context, WordMachinePage.routeName),
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFF9BBC0F), // GameBoy 绿（豁免）
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: MistralColors.black26,
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
                  color: Color(0xFF0F380F), // GameBoy 深绿（豁免）
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 左上角查词入口按钮
  Widget _buildSearchButton(BuildContext context, dynamic skin) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(left: 12, top: 12),
        child: ScaleDownOnPress(
          onTap: () => Navigator.pushNamed(context, SearchPage.routeName),
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: skin.colors.cardBg,
              shape: BoxShape.circle,
              boxShadow: const [
                BoxShadow(color: Color(0x23000000), blurRadius: 0.5),
                BoxShadow(color: Color(0x3D000000), blurRadius: 1.0, offset: Offset(0, 1)),
              ],
            ),
            child: Icon(Icons.menu_book_rounded, color: skin.colors.accent, size: 24),
          ),
        ),
      ),
    );
  }

  /// 下滑查词提示覆盖层内容（含手机插图模拟）；点击提示卡直接打开查词
  Widget _buildSwipeHintOverlay(BuildContext context, SkinSystem skin) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, SearchPage.routeName),
      child: SbCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('下滑查词',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: skin.colors.text1)),
          const SizedBox(height: 16),
          // 手机插图
          Container(
            width: 120,
            height: 180,
            decoration: BoxDecoration(
              border: Border.all(color: skin.colors.divider, width: 2),
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
                        decoration: BoxDecoration(color: skin.colors.divider, borderRadius: BorderRadius.circular(3))),
                      const SizedBox(height: 8),
                      Container(height: 6, width: double.infinity,
                        decoration: BoxDecoration(color: skin.colors.divider, borderRadius: BorderRadius.circular(3))),
                      const SizedBox(height: 8),
                      Container(height: 6, width: 80,
                        decoration: BoxDecoration(color: skin.colors.divider, borderRadius: BorderRadius.circular(3))),
                    ],
                  ),
                ),
                // 键盘模拟
                Positioned(
                  bottom: 10, left: 8, right: 8,
                  child: Container(
                    height: 50,
                    decoration: BoxDecoration(
                      color: skin.colors.cardBgAlt,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                // 手指图标
                Positioned(
                  bottom: 60, right: 30,
                  child: Icon(Icons.touch_app, color: skin.colors.accent, size: 40),
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

/// 入口卡片（替代 GlassEntryCard，使用 SbCard 白卡风格）
class _EntryCard extends StatelessWidget {
  final String title;
  final int count;
  final VoidCallback onTap;

  const _EntryCard({
    required this.title,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return SbCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: skin.colors.text1)),
          const SizedBox(height: 8),
          Text('$count',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w300, color: skin.colors.accent)),
          const SizedBox(height: 4),
          Text(title == 'Learn' ? '待学' : '待复习',
            style: TextStyle(fontSize: 12, color: skin.colors.text3)),
        ],
      ),
    );
  }
}
