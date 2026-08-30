// 由 Claude 团队生成 | Monster Word App

// 课程页面：展示课程列表，支持课程签到和活动
import 'package:flutter/material.dart';

import 'package:word_app/widgets/common/mw_skeleton.dart';
import 'package:word_app/core/router/nav_utils.dart';
import 'package:word_app/core/router/route_names.dart';
import 'package:word_app/core/presentation/responsive.dart';
import 'package:word_app/theme/skin_system.dart';
import 'package:word_app/tokens/design_tokens.dart';

class CoursesPage extends StatefulWidget {
  const CoursesPage({super.key});

  static const routeName = '/courses';

  @override
  State<CoursesPage> createState() => _CoursesPageState();
}

class _CoursesPageState extends State<CoursesPage> {
  bool _loading = true;
  List<_CourseItem> _courses = [];

  @override
  void initState() {
    super.initState();
    _loadCourses();
  }

  Future<void> _loadCourses() async {
    // TODO: 从 API 加载课程列表
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    setState(() {
      _courses = [
        _CourseItem(
          id: '1',
          title: '雅思核心词汇',
          subtitle: '每日 30 分钟 · 已学 12 天',
          progress: 0.4,
          coverColor: MistralColors.primary,
        ),
        _CourseItem(
          id: '2',
          title: '托福听力训练',
          subtitle: '每日 20 分钟 · 已学 5 天',
          progress: 0.2,
          coverColor: MistralColors.success,
        ),
        _CourseItem(
          id: '3',
          title: '商务英语写作',
          subtitle: '每日 25 分钟 · 已学 8 天',
          progress: 0.6,
          coverColor: MistralColors.sunshine300,
        ),
      ];
      _loading = false;
    });
  }

  void _onCourseTap(_CourseItem course) {
    Navigator.pushNamed(context, RouteNames.classCheckin, arguments: {
      'courseId': course.id,
      'courseName': course.title,
    });
  }

  void _onActivityTap(_CourseItem course) {
    Navigator.pushNamed(context, RouteNames.classActivity, arguments: {
      'courseId': course.id,
      'courseName': course.title,
    });
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final resp = context.responsive;

    if (_loading) {
      return Scaffold(
        backgroundColor: skin.colors.pageBg,
        body: SafeArea(child: const MwSkeletonPage(rows: 3)),
      );
    }

    return Scaffold(
      backgroundColor: skin.colors.pageBg,
      body: SafeArea(
        child: Column(
          children: [
            _buildNavBar(skin),
            Container(height: 1, color: skin.colors.divider),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: resp.contentMaxWidth),
                  child: ListView(
                    padding: EdgeInsets.symmetric(horizontal: resp.horizontalPadding, vertical: 16),
                    children: [
                      Text('我的课程', style: MistralTypography.heading3.copyWith(color: skin.colors.text1)),
                      const SizedBox(height: 16),
                      for (final course in _courses) ...[
                        _CourseCard(
                          course: course,
                          onTap: () => _onCourseTap(course),
                          onActivityTap: () => _onActivityTap(course),
                          skin: skin,
                        ),
                        const SizedBox(height: 12),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavBar(SkinSystem skin) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
            color: skin.colors.text1,
            onPressed: () => NavUtils.safePop(context),
          ),
          const SizedBox(width: 4),
          Text('课程', style: MistralTypography.heading5.copyWith(color: skin.colors.text1)),
        ],
      ),
    );
  }
}

class _CourseCard extends StatelessWidget {
  final _CourseItem course;
  final VoidCallback onTap;
  final VoidCallback onActivityTap;
  final SkinSystem skin;

  const _CourseCard({
    required this.course,
    required this.onTap,
    required this.onActivityTap,
    required this.skin,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: skin.colors.cardBg,
          borderRadius: BorderRadius.circular(context.design.radius.lg),
          border: Border.all(color: skin.colors.divider),
        ),
        child: Row(
          children: [
            // 封面
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: course.coverColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(context.design.radius.md),
              ),
              child: Center(
                child: Icon(Icons.school, color: course.coverColor, size: 32),
              ),
            ),
            const SizedBox(width: 16),
            // 信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(course.title, style: MistralTypography.heading5.copyWith(color: skin.colors.text1)),
                  const SizedBox(height: 4),
                  Text(course.subtitle, style: MistralTypography.bodySm.copyWith(color: skin.colors.text3)),
                  const SizedBox(height: 8),
                  // 进度条
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 6,
                          decoration: BoxDecoration(
                            color: skin.colors.divider,
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: course.progress,
                            child: Container(
                              decoration: BoxDecoration(
                                color: course.coverColor,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${(course.progress * 100).toInt()}%',
                        style: MistralTypography.caption.copyWith(color: skin.colors.text3),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // 活动按钮
            IconButton(
              icon: Icon(Icons.emoji_events_outlined, color: MistralColors.sunshine300),
              onPressed: onActivityTap,
            ),
          ],
        ),
      ),
    );
  }
}

class _CourseItem {
  final String id;
  final String title;
  final String subtitle;
  final double progress;
  final Color coverColor;

  const _CourseItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.progress,
    required this.coverColor,
  });
}
