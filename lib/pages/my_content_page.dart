// 我的内容页：还原原版"我的内容"页面
// 横向卡片（随身听/听写）+ 列表项（在学词书/近日已学/全部已学/单词本/句库/笔记）
import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import '../state/learning_state.dart';
import '../theme/skin_system.dart';
import '../tokens/design_tokens.dart';
import 'my_fav_page.dart';

class MyContentPage extends StatelessWidget {
  const MyContentPage({super.key});
  static const routeName = '/my_content';

  @override
  Widget build(BuildContext context) {
    final skin = context.skin.colors;

    return Scaffold(
      backgroundColor: skin.pageBg,
      body: SafeArea(
        child: Column(
          children: [
            // 顶部导航栏：返回箭头 + "我的内容" + 灯泡图标
            _NavBar(skin: skin),
            // 内容区
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    // 横向卡片区域（随身听 + 听写）
                    _HorizontalCards(skin: skin),
                    const SizedBox(height: 20),
                    // 列表组 1：在学词书 / 近日已学 / 全部已学
                    _ListGroup(
                      children: [
                        _ListItem(
                          icon: Icons.menu_book,
                          iconColor: const Color(0xFF4CAF50),
                          title: '在学词书',
                          value: '6135 词',
                          skin: skin,
                        ),
                        _ListItem(
                          icon: Icons.check_circle_outline,
                          iconColor: const Color(0xFFFF9800),
                          title: '近日已学',
                          value: '今天 4 词',
                          skin: skin,
                        ),
                        _ListItem(
                          icon: Icons.check_circle,
                          iconColor: const Color(0xFFFF9800),
                          title: '全部已学',
                          value: '250 词',
                          skin: skin,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // 列表组 2：单词本 / 句库 / 笔记
                    _ListGroup(
                      children: [
                        _ListItem(
                          icon: Icons.book_outlined,
                          iconColor: const Color(0xFF2196F3),
                          title: '单词本',
                          value: '${context.watch<LearningState>().favoriteCount} 词',
                          skin: skin,
                          onTap: () => Navigator.pushNamed(context, MyFavPage.routeName),
                        ),
                        _ListItem(
                          icon: Icons.format_quote,
                          iconColor: const Color(0xFF2196F3),
                          title: '句库',
                          value: '0 句',
                          skin: skin,
                        ),
                        _ListItem(
                          icon: Icons.edit_outlined,
                          iconColor: const Color(0xFF2196F3),
                          title: '笔记',
                          value: '19 条',
                          skin: skin,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 顶部导航栏
class _NavBar extends StatelessWidget {
  final ThemeVars skin;
  const _NavBar({required this.skin});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
            color: skin.text1,
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Center(
              child: Text('我的内容',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: skin.text1)),
            ),
          ),
          IconButton(
            icon: Icon(Icons.lightbulb_outline, size: 22, color: skin.text1),
            onPressed: () {},
          ),
        ],
      ),
    );
  }
}

/// 横向卡片区域：随身听 + 听写
class _HorizontalCards extends StatelessWidget {
  final ThemeVars skin;
  const _HorizontalCards({required this.skin});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 160,
      child: Row(
        children: [
          // 随身听卡片（橙色渐变）
          Expanded(
            child: _FeatureCard(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFFE0CC), Color(0xFFFFD0B0)],
              ),
              icon: Icons.headphones,
              iconBg: const Color(0xFFFF6800),
              title: '随身听',
              children: [
                _MiniCard(title: '回顾', count: '4 词', accent: const Color(0xFFFF6800)),
                const SizedBox(width: 8),
                _MiniCard(title: '预习', count: '20 词', accent: const Color(0xFFFF6800)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // 听写卡片（蓝色渐变）
          Expanded(
            child: _FeatureCard(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFCCF0FF), Color(0xFFB0E0F0)],
              ),
              icon: Icons.edit,
              iconBg: const Color(0xFF2196F3),
              title: '听写',
              children: [
                _MiniCard(title: '单元测', count: '', accent: const Color(0xFF2196F3)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 功能卡片（随身听/听写）
class _FeatureCard extends StatelessWidget {
  final Gradient gradient;
  final IconData icon;
  final Color iconBg;
  final String title;
  final List<Widget> children;

  const _FeatureCard({
    required this.gradient,
    required this.icon,
    required this.iconBg,
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: iconBg.withValues(alpha: 0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题行：图标 + 标题
            Row(
              children: [
                Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    color: iconBg,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: Colors.white, size: 15),
                ),
                const SizedBox(width: 8),
                Text(title,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF1F1F1F))),
              ],
            ),
            const SizedBox(height: 12),
            // 子卡片行
            Expanded(
              child: Row(children: children),
            ),
          ],
        ),
      ),
    );
  }
}

/// 子卡片（回顾/预习/单元测）带播放按钮
class _MiniCard extends StatelessWidget {
  final String title;
  final String count;
  final Color accent;

  const _MiniCard({required this.title, required this.count, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1F1F1F))),
            if (count.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(count,
                style: const TextStyle(fontSize: 12, color: Color(0xFF999999))),
            ],
            const Spacer(),
            Align(
              alignment: Alignment.centerRight,
              child: Container(
                width: 28, height: 28,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.play_arrow, color: accent, size: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 列表组（带圆角背景 + 内部分割线）
class _ListGroup extends StatelessWidget {
  final List<Widget> children;
  const _ListGroup({required this.children});

  @override
  Widget build(BuildContext context) {
    final skin = context.skin.colors;
    return Container(
      decoration: BoxDecoration(
        color: skin.cardBg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          for (int i = 0; i < children.length; i++) ...[
            children[i],
            if (i < children.length - 1)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Divider(height: 0.5, color: skin.divider),
              ),
          ],
        ],
      ),
    );
  }
}

/// 列表项（图标 + 标题 + 值 + 箭头）
class _ListItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String value;
  final ThemeVars skin;
  final VoidCallback? onTap;

  const _ListItem({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.value,
    required this.skin,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(title,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: skin.text1)),
            ),
            Text(value,
              style: TextStyle(fontSize: 14, color: skin.text3)),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, size: 20, color: skin.text3),
          ],
        ),
      ),
    );
  }
}
