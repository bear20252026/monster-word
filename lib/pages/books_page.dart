// 由 Claude 团队生成 | Monster Word App

// 由账号4生成
// 主界面：1:1 复刻原版 activity_main.xml
// 结构：全屏背景 + 顶部头像 + 签到组件 + Learn/Review 双按钮 + 底部 4 图标栏
import 'package:flutter/material.dart';

import '../hooks/responsive.dart';
import '../theme/app_theme.dart';
import '../theme/skin_system.dart';
import '../tokens/design_tokens.dart';
import 'dashboard_page.dart';
import 'lib_select_page.dart';
import 'my_space_page.dart';
import 'review_page.dart';

class BooksPage extends StatefulWidget {
  const BooksPage({super.key});

  @override
  State<BooksPage> createState() => _BooksPageState();
}

class _BooksPageState extends State<BooksPage> {
  @override
  Widget build(BuildContext context) {
    final colors = context.skin.colors;
    final resp = context.responsive;
    return Scaffold(
      body: Stack(
        children: [
          // ===== 全屏背景（原版 iv_background 渐变绿）=====
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [colors.pageBg, colors.cardBg],
                ),
              ),
            ),
          ),
          // ===== 顶层内容（原版 first_content_view）=====
          SafeArea(
            child: Column(
              children: [
                // 顶部头像栏（原版 myInfo_head，44dp）
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: resp.pageMargin),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.white100.withValues(alpha: 0.35),
                          border: Border.all(
                            color: AppColors.white100.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Icon(Icons.person, color: AppColors.white100, size: 26),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        '数据同步中',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.white100.withValues(alpha: 0.8),
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: Icon(Icons.more_horiz, color: AppColors.white100),
                        tooltip: '更多',
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('更多操作开发中...'), duration: Duration(seconds: 1)),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                // 签到组件（原版 BBCheckIn，139×135dp，顶部 22%）
                _CheckInBadge(),
                const Spacer(),
                // Learn/Review 双按钮（原版 ll_btn_view，70dp）
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: resp.pageMargin),
                  child: Row(
                    children: [
                      Expanded(
                        child: _LearnReviewBand(
                          title: 'Learn',
                          subtitle: '学习新词',
                          icon: Icons.school,
                          onTap: _openLearn,
                        ),
                      ),
                      SizedBox(width: resp.pageMargin),
                      Expanded(
                        child: _LearnReviewBand(
                          title: 'Review',
                          subtitle: '复习单词',
                          icon: Icons.autorenew,
                          onTap: _openReview,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
          // ===== 底部 4 图标栏（原版 bottom_button_container，48dp）=====
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              child: Container(
                height: AppDimens.bottomBarHeight,
                margin: const EdgeInsets.only(bottom: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _HomeIcon(Icons.video_library_outlined, '课堂',
                        onTap: () => _openLearn()),
                    _HomeIcon(Icons.favorite_border, '收藏',
                        onTap: () =>
                            Navigator.pushNamed(context, MySpacePage.routeName)),
                    _HomeIcon(Icons.headphones, '听力',
                        onTap: () =>
                            Navigator.pushNamed(context, ReviewPage.routeName)),
                    _HomeIcon(Icons.dashboard_outlined, '统计',
                        onTap: () =>
                            Navigator.pushNamed(context, DashboardPage.routeName)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 打开学习（词书选择）
  Future<void> _openLearn() async {
    await Navigator.pushNamed(context, LibSelectPage.routeName);
  }

  /// 打开复习（词书选择，同入口）
  Future<void> _openReview() async {
    await Navigator.pushNamed(context, LibSelectPage.routeName);
  }
}

/// 签到组件（复刻原版 BBCheckIn：圆形徽章 + 打卡提示）
class _CheckInBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 139,
      height: 135,
      decoration: BoxDecoration(
        color: AppColors.checkInBg,
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.white100.withValues(alpha: 0.5),
          width: 1.5,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_available, color: AppColors.white100, size: 36),
          SizedBox(height: 6),
          Text(
            '今日打卡',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.white100.withValues(alpha: 0.9),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Learn/Review 双按钮（复刻原版 LearnReviewBand）
class _LearnReviewBand extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _LearnReviewBand({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 70,
        decoration: BoxDecoration(
          color: AppColors.white100.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(AppDimens.radiusNormal),
          border: Border.all(color: AppColors.white100.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppColors.white100, size: 30),
            SizedBox(width: 10),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: AppColors.white100,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.white100.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 底部图标按钮
class _HomeIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _HomeIcon(this.icon, this.label, {required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: AppColors.white100, size: 26),
          SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(fontSize: 10, color: AppColors.white100.withValues(alpha: 0.85)),
          ),
        ],
      ),
    );
  }
}
