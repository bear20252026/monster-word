// 不背学堂页：课程 Banner + 课程卡片列表 + 备考速刷 + 班级打卡
// 还原原版 v3.2 不背学堂页面
import 'package:flutter/material.dart';

import '../hooks/responsive.dart';
import '../theme/skin_system.dart';
import '../tokens/design_tokens.dart';
import 'class_checkin_page.dart';
import 'class_activity_page.dart';

/// 不背学堂页面（原版底部导航"课程"入口）
class CoursesPage extends StatelessWidget {
  const CoursesPage({super.key});

  static const routeName = '/courses';

  @override
  Widget build(BuildContext context) {
    final skin = context.skin.colors;

    return Scaffold(
      backgroundColor: skin.pageBg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: context.responsive.contentWidth),
            child: Column(
              children: [
                // 顶部导航栏
                _buildTopBar(context, skin),
                Container(height: 1, color: skin.divider),
                // 内容区
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(context.responsive.pageMargin),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 课程 Banner
                        _CourseBanner(skin: skin),
                        const SizedBox(height: AppSpacing.lg),
                        // 课程卡片网格
                        Text(
                          '精品课程',
                          style: MistralTypography.heading4.copyWith(color: skin.text1),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        _CourseCardGrid(skin: skin),
                        const SizedBox(height: AppSpacing.lg),
                        // 备考速刷入口
                        _QuickReviewEntry(skin: skin),
                        const SizedBox(height: AppSpacing.sm),
                        // 班级打卡入口
                        _ClassCheckInEntry(skin: skin),
                        const SizedBox(height: AppSpacing.sm),
                        // 班级活动入口
                        _ClassActivityEntry(skin: skin),
                        const SizedBox(height: AppSpacing.xl),
                      ],
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

  Widget _buildTopBar(BuildContext context, ThemeVars skin) {
    return Container(
      height: AppSpacing.navH,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
            color: skin.text1,
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 4),
          Text(
            '不背学堂',
            style: MistralTypography.heading5.copyWith(
              color: skin.text1,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Banner
// ─────────────────────────────────────────────────────────────────────────────

class _CourseBanner extends StatelessWidget {
  final ThemeVars skin;
  const _CourseBanner({required this.skin});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 160,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            MistralColors.primary.withOpacity(0.85),
            const Color(0xFF9EC5E8).withOpacity(0.8),
            const Color(0xFFE8C5B8).withOpacity(0.7),
          ],
        ),
      ),
      child: Stack(
        children: [
          // 装饰圆形
          Positioned(
            right: -20,
            top: 20,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.15),
              ),
            ),
          ),
          Positioned(
            right: 60,
            bottom: -30,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.1),
              ),
            ),
          ),
          // 文字内容
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: MistralColors.primary,
                    borderRadius: BorderRadius.circular(AppRadius.xs),
                  ),
                  child: Text(
                    '全新上线',
                    style: MistralTypography.micro.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'CET-6',
                  style: MistralTypography.bodySm.copyWith(
                    color: Colors.white70,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '六级听力 阶梯训练',
                  style: MistralTypography.heading3.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    '轻松练真题 →',
                    style: MistralTypography.bodySm.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 课程卡片网格
// ─────────────────────────────────────────────────────────────────────────────

class _CourseCardGrid extends StatelessWidget {
  final ThemeVars skin;
  const _CourseCardGrid({required this.skin});

  @override
  Widget build(BuildContext context) {
    final courses = [
      _CourseData(
        title: '备考速刷',
        subtitle: '考前快速n刷必备',
        tag: '热门',
        color: const Color(0xFF90CAF9),
        icon: Icons.rocket_launch,
      ),
      _CourseData(
        title: '班级打卡',
        subtitle: '全班一起学，刷词不掉队',
        tag: '推荐',
        color: const Color(0xFFF8BBD0),
        icon: Icons.groups,
      ),
      _CourseData(
        title: '六级听力 阶梯训练',
        subtitle: '轻松练真题',
        tag: '',
        color: const Color(0xFFCE93D8),
        icon: Icons.headphones,
      ),
      _CourseData(
        title: '四级听力 阶梯训练',
        subtitle: '轻松练真题',
        tag: '',
        color: const Color(0xFFA5D6A7),
        icon: Icons.headphones,
      ),
      _CourseData(
        title: '考研写作炼句',
        subtitle: '快速炼制高分金句',
        tag: '',
        color: const Color(0xFFFFCC80),
        icon: Icons.edit,
      ),
      _CourseData(
        title: '小野解词',
        subtitle: '词根词缀，图记单词',
        tag: '',
        color: const Color(0xFF80CBC4),
        icon: Icons.person,
      ),
      _CourseData(
        title: '口语达人',
        subtitle: '地道口语特训课',
        tag: '新课',
        color: const Color(0xFFFFAB91),
        icon: Icons.mic,
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: AppSpacing.sm,
        crossAxisSpacing: AppSpacing.sm,
        childAspectRatio: 1.2,
      ),
      itemCount: courses.length,
      itemBuilder: (context, i) => _CourseCard(data: courses[i], skin: skin),
    );
  }
}

class _CourseCard extends StatelessWidget {
  final _CourseData data;
  final ThemeVars skin;

  const _CourseCard({required this.data, required this.skin});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: skin.cardBg,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: skin.divider, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  data.title,
                  style: MistralTypography.bodyMd.copyWith(
                    color: skin.text1,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (data.tag.isNotEmpty) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: data.color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(AppRadius.xs),
                  ),
                  child: Text(
                    data.tag,
                    style: MistralTypography.micro.copyWith(
                      color: data.color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(
            data.subtitle,
            style: MistralTypography.bodySm.copyWith(color: skin.text3),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const Spacer(),
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: data.color.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(data.icon, color: data.color, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 入口磁贴
// ─────────────────────────────────────────────────────────────────────────────

class _QuickReviewEntry extends StatelessWidget {
  final ThemeVars skin;
  const _QuickReviewEntry({required this.skin});

  @override
  Widget build(BuildContext context) {
    return _EntryTile(
      skin: skin,
      icon: Icons.speed,
      iconColor: const Color(0xFFE53935),
      title: '备考速刷',
      subtitle: '考前突击，快速过词',
      onTap: () {
        // TODO: 导航到备考速刷页
      },
    );
  }
}

class _ClassCheckInEntry extends StatelessWidget {
  final ThemeVars skin;
  const _ClassCheckInEntry({required this.skin});

  @override
  Widget build(BuildContext context) {
    return _EntryTile(
      skin: skin,
      icon: Icons.groups,
      iconColor: const Color(0xFF43A047),
      title: '班级打卡',
      subtitle: '加入班级，一起学习',
      onTap: () {
        Navigator.pushNamed(context, ClassCheckInPage.routeName);
      },
    );
  }
}

class _ClassActivityEntry extends StatelessWidget {
  final ThemeVars skin;
  const _ClassActivityEntry({required this.skin});

  @override
  Widget build(BuildContext context) {
    return _EntryTile(
      skin: skin,
      icon: Icons.event,
      iconColor: const Color(0xFFFF9800),
      title: '班级活动',
      subtitle: '全班一起学，刷词不掉队',
      onTap: () {
        Navigator.pushNamed(context, ClassActivityPage.routeName);
      },
    );
  }
}

class _EntryTile extends StatelessWidget {
  final ThemeVars skin;
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _EntryTile({
    required this.skin,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: skin.cardBg,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(color: skin.divider, width: 0.5),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: MistralTypography.bodyMd.copyWith(
                      color: skin.text1,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: MistralTypography.bodySm.copyWith(color: skin.text3),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: skin.text3, size: 20),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 数据模型
// ─────────────────────────────────────────────────────────────────────────────

class _CourseData {
  final String title;
  final String subtitle;
  final String tag;
  final Color color;
  final IconData icon;

  const _CourseData({
    required this.title,
    required this.subtitle,
    required this.tag,
    required this.color,
    required this.icon,
  });
}
