// 班级活动页：Banner + 活动指引 + 功能卡片 + 公告 + 评论
// 还原原版 v3.2 班级活动页面
import 'package:flutter/material.dart';

import '../theme/skin_system.dart';
import '../tokens/design_tokens.dart';

/// 班级活动页面
class ClassActivityPage extends StatelessWidget {
  const ClassActivityPage({super.key});

  static const routeName = '/class_activity';

  @override
  Widget build(BuildContext context) {
    final skin = context.skin.colors;

    return Scaffold(
      backgroundColor: skin.pageBg,
      body: SafeArea(
        child: Column(
          children: [
            // 顶部导航栏
            _buildTopBar(context, skin),
            Container(height: 1, color: skin.divider),
            // 内容区
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Banner
                    _ActivityBanner(skin: skin),
                    // 班级活动指引
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: _ActivityGuide(skin: skin),
                    ),
                    // 功能卡片（4个）
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                      child: _FunctionCards(skin: skin),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    // 创建班级活动按钮
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                      child: _CreateActivityButton(skin: skin),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    // 功能全新升级
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                      child: _UpgradeSection(skin: skin),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    // 班级公告
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                      child: _AnnouncementSection(skin: skin),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    // 用户评论
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                      child: _CommentSection(skin: skin),
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                  ],
                ),
              ),
            ),
          ],
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
            '班级活动',
            style: MistralTypography.heading5.copyWith(color: skin.text1),
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

class _ActivityBanner extends StatelessWidget {
  final ThemeVars skin;
  const _ActivityBanner({required this.skin});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 180,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            skin.accent,
            skin.accent,
          ],
        ),
      ),
      child: Stack(
        children: [
          // 装饰元素
          Positioned(
            right: -10,
            bottom: -10,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ),
          ),
          Positioned(
            right: 60,
            top: -20,
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
          ),
          // 文字内容
          Positioned(
            left: AppSpacing.lg,
            top: 30,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '全班一起学',
                  style: MistralTypography.heading2.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '刷词不掉队',
                  style: MistralTypography.heading4.copyWith(
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    '立即参与 →',
                    style: MistralTypography.bodySm.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // 卡通人物占位
          Positioned(
            right: 20,
            bottom: 20,
            child: Container(
              width: 80,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppRadius.xl),
              ),
              child: const Center(
                child: Icon(
                  Icons.people,
                  size: 48,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 班级活动指引（3步流程图）
// ─────────────────────────────────────────────────────────────────────────────

class _ActivityGuide extends StatelessWidget {
  final ThemeVars skin;
  const _ActivityGuide({required this.skin});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: skin.cardBg,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: skin.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '班级活动指引',
            style: MistralTypography.heading5.copyWith(color: skin.text1),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              _GuideStep(
                number: '1',
                title: '创建活动',
                desc: '设定学习目标',
                color: skin.accent,
                skin: skin,
              ),
              _GuideArrow(skin: skin),
              _GuideStep(
                number: '2',
                title: '邀请同学',
                desc: '一起加入',
                color: skin.teal,
                skin: skin,
              ),
              _GuideArrow(skin: skin),
              _GuideStep(
                number: '3',
                title: '打卡学习',
                desc: '互相监督',
                color: skin.accent,
                skin: skin,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GuideStep extends StatelessWidget {
  final String number;
  final String title;
  final String desc;
  final Color color;
  final ThemeVars skin;

  const _GuideStep({
    required this.number,
    required this.title,
    required this.desc,
    required this.color,
    required this.skin,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: MistralTypography.bodyMd.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            title,
            style: MistralTypography.bodySm.copyWith(
              color: skin.text1,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            desc,
            style: MistralTypography.micro.copyWith(color: skin.text3),
          ),
        ],
      ),
    );
  }
}

class _GuideArrow extends StatelessWidget {
  final ThemeVars skin;
  const _GuideArrow({required this.skin});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Icon(Icons.arrow_forward_ios, size: 12, color: skin.text3),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 功能卡片（4个）
// ─────────────────────────────────────────────────────────────────────────────

class _FunctionCards extends StatelessWidget {
  final ThemeVars skin;
  const _FunctionCards({required this.skin});

  @override
  Widget build(BuildContext context) {
    final cards = [
      _FunctionCardData(
        icon: Icons.task_alt,
        title: '设定任务',
        desc: '制定学习计划',
        color: skin.accent,
      ),
      _FunctionCardData(
        icon: Icons.leaderboard,
        title: '班级排名',
        desc: '查看学习排名',
        color: skin.teal,
      ),
      _FunctionCardData(
        icon: Icons.notifications_active,
        title: '互相提醒',
        desc: '督促学习',
        color: skin.accent,
      ),
      _FunctionCardData(
        icon: Icons.campaign,
        title: '公告通知',
        desc: '班级动态',
        color: skin.danger,
      ),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: AppSpacing.sm,
      crossAxisSpacing: AppSpacing.sm,
      childAspectRatio: 1.6,
      children: cards.map((c) => _FunctionCardTile(data: c, skin: skin)).toList(),
    );
  }
}

class _FunctionCardTile extends StatelessWidget {
  final _FunctionCardData data;
  final ThemeVars skin;

  const _FunctionCardTile({required this.data, required this.skin});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: skin.cardBg,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: skin.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: data.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(data.icon, color: data.color, size: 20),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            data.title,
            style: MistralTypography.bodySm.copyWith(
              color: skin.text1,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            data.desc,
            style: MistralTypography.micro.copyWith(color: skin.text3),
          ),
        ],
      ),
    );
  }
}

class _FunctionCardData {
  final IconData icon;
  final String title;
  final String desc;
  final Color color;

  const _FunctionCardData({
    required this.icon,
    required this.title,
    required this.desc,
    required this.color,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// 创建班级活动按钮
// ─────────────────────────────────────────────────────────────────────────────

class _CreateActivityButton extends StatelessWidget {
  final ThemeVars skin;
  const _CreateActivityButton({required this.skin});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: () {
          // TODO: 创建班级活动
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: skin.accent,
          foregroundColor: skin.cardBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.xl),
          ),
          elevation: 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add_circle_outline, size: 20),
            const SizedBox(width: AppSpacing.xs),
            Text(
              '创建班级活动',
              style: MistralTypography.bodyMd.copyWith(
                color: skin.cardBg,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 功能全新升级
// ─────────────────────────────────────────────────────────────────────────────

class _UpgradeSection extends StatelessWidget {
  final ThemeVars skin;
  const _UpgradeSection({required this.skin});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: skin.cardBg,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: skin.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: skin.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Text(
                  'NEW',
                  style: MistralTypography.micro.copyWith(
                    color: skin.accent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                '功能全新升级',
                style: MistralTypography.heading5.copyWith(color: skin.text1),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          _UpgradeItem(
            icon: Icons.speed,
            title: '学习效率提升',
            desc: '全新学习算法，刷词更高效',
            skin: skin,
          ),
          _UpgradeItem(
            icon: Icons.group_add,
            title: '班级互动增强',
            desc: '新增实时互动功能',
            skin: skin,
          ),
          _UpgradeItem(
            icon: Icons.bar_chart,
            title: '数据统计升级',
            desc: '更详细的学习数据分析',
            skin: skin,
          ),
        ],
      ),
    );
  }
}

class _UpgradeItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String desc;
  final ThemeVars skin;

  const _UpgradeItem({
    required this.icon,
    required this.title,
    required this.desc,
    required this.skin,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Icon(icon, size: 18, color: skin.accent),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: MistralTypography.bodySm.copyWith(
                    color: skin.text1,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  desc,
                  style: MistralTypography.micro.copyWith(color: skin.text3),
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
// 班级公告
// ─────────────────────────────────────────────────────────────────────────────

class _AnnouncementSection extends StatelessWidget {
  final ThemeVars skin;
  const _AnnouncementSection({required this.skin});

  @override
  Widget build(BuildContext context) {
    final announcements = [
      _AnnouncementData(
        title: '本周学习任务',
        content: '请各位同学完成四级核心词汇 Unit 3-4 的学习',
        time: '2小时前',
        isTop: true,
      ),
      _AnnouncementData(
        title: '活动通知',
        content: '班级打卡活动开始啦！连续打卡7天可获得奖励',
        time: '昨天',
        isTop: false,
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: skin.cardBg,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: skin.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Icon(Icons.campaign, size: 18, color: skin.accent),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  '班级公告',
                  style: MistralTypography.heading5.copyWith(color: skin.text1),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ...announcements.map((a) => _AnnouncementTile(data: a, skin: skin)),
        ],
      ),
    );
  }
}

class _AnnouncementTile extends StatelessWidget {
  final _AnnouncementData data;
  final ThemeVars skin;

  const _AnnouncementTile({required this.data, required this.skin});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (data.isTop) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: skin.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.xs),
                  ),
                  child: Text(
                    '置顶',
                    style: MistralTypography.micro.copyWith(
                      color: skin.accent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
              ],
              Expanded(
                child: Text(
                  data.title,
                  style: MistralTypography.bodyMd.copyWith(
                    color: skin.text1,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                data.time,
                style: MistralTypography.micro.copyWith(color: skin.text3),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            data.content,
            style: MistralTypography.bodySm.copyWith(color: skin.text2),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _AnnouncementData {
  final String title;
  final String content;
  final String time;
  final bool isTop;

  const _AnnouncementData({
    required this.title,
    required this.content,
    required this.time,
    required this.isTop,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// 用户评论列表
// ─────────────────────────────────────────────────────────────────────────────

class _CommentSection extends StatelessWidget {
  final ThemeVars skin;
  const _CommentSection({required this.skin});

  @override
  Widget build(BuildContext context) {
    final comments = [
      _CommentData(
        avatar: '小',
        name: '小明同学',
        content: '班级活动真的很棒，大家一起学习更有动力！',
        likes: 12,
        time: '3小时前',
      ),
      _CommentData(
        avatar: '学',
        name: '学霸小李',
        content: '打卡第7天，坚持就是胜利 💪',
        likes: 8,
        time: '5小时前',
      ),
      _CommentData(
        avatar: '英',
        name: '英语达人',
        content: '推荐大家一起参加，互相监督效果很好',
        likes: 5,
        time: '昨天',
      ),
      _CommentData(
        avatar: '勤',
        name: '勤奋小白',
        content: '刚开始加入，希望能坚持下去！',
        likes: 3,
        time: '2天前',
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: skin.cardBg,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: skin.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Icon(Icons.comment, size: 18, color: skin.accent),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  '用户评论',
                  style: MistralTypography.heading5.copyWith(color: skin.text1),
                ),
                const Spacer(),
                Text(
                  '${comments.length} 条',
                  style: MistralTypography.bodySm.copyWith(color: skin.text3),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ...comments.map((c) => _CommentTile(data: c, skin: skin)),
        ],
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  final _CommentData data;
  final ThemeVars skin;

  const _CommentTile({required this.data, required this.skin});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 头像
          CircleAvatar(
            radius: 18,
            backgroundColor: skin.accent.withValues(alpha: 0.12),
            child: Text(
              data.avatar,
              style: MistralTypography.bodySm.copyWith(
                color: skin.accent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          // 内容
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      data.name,
                      style: MistralTypography.bodySm.copyWith(
                        color: skin.text1,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      data.time,
                      style: MistralTypography.micro.copyWith(color: skin.text3),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  data.content,
                  style: MistralTypography.bodySm.copyWith(color: skin.text2),
                ),
                const SizedBox(height: AppSpacing.xs),
                // 点赞
                Row(
                  children: [
                    Icon(Icons.thumb_up_outlined, size: 14, color: skin.text3),
                    const SizedBox(width: 4),
                    Text(
                      '${data.likes}',
                      style: MistralTypography.micro.copyWith(color: skin.text3),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentData {
  final String avatar;
  final String name;
  final String content;
  final int likes;
  final String time;

  const _CommentData({
    required this.avatar,
    required this.name,
    required this.content,
    required this.likes,
    required this.time,
  });
}
