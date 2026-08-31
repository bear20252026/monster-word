part of 'class_checkin_page.dart';

class _ClassInfoCard extends StatelessWidget {
  final ThemeVars skin;
  final String className;
  final int memberCount;
  final int streakDays;

  const _ClassInfoCard({
    required this.skin,
    required this.className,
    required this.memberCount,
    required this.streakDays,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(context.design.spacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [MistralColors.primary.withValues(alpha: 0.85), MistralColors.primaryDeep.withValues(alpha: 0.75)],
        ),
        borderRadius: BorderRadius.circular(context.design.radius.xl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            className,
            style: MistralTypography.heading4.copyWith(color: AppColors.white100, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: context.design.spacing.xs),
          Text(
            '$memberCount 名成员',
            style: MistralTypography.bodySm.copyWith(color: AppColors.white100.withValues(alpha: 0.8)),
          ),
          SizedBox(height: context.design.spacing.md),
          Row(
            children: [
              _StatItem(label: '连续签到', value: '$streakDays 天'),
              SizedBox(width: context.design.spacing.xl),
              _StatItem(label: '班级排名', value: '第 $memberCount 名'),
            ],
          ),
        ],
      ),
    );
  }
}

/// 统计项
class _StatItem extends StatelessWidget {
  final String label;
  final String value;

  const _StatItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: MistralTypography.heading3.copyWith(color: AppColors.white100, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 2),
        Text(label, style: MistralTypography.bodySm.copyWith(color: AppColors.white100.withValues(alpha: 0.7))),
      ],
    );
  }
}

/// 每日签到按钮
class _CheckInButton extends StatelessWidget {
  final ThemeVars skin;
  final bool checkedIn;
  final VoidCallback? onTap;

  const _CheckInButton({required this.skin, required this.checkedIn, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          color: checkedIn ? skin.cardBg : MistralColors.primary,
          borderRadius: BorderRadius.circular(context.design.radius.xl),
          border: checkedIn ? Border.all(color: skin.divider) : null,
        ),
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                checkedIn ? Icons.check_circle : Icons.touch_app,
                color: checkedIn ? MistralColors.success : AppColors.white100,
                size: 22,
              ),
              SizedBox(width: context.design.spacing.xs),
              Text(
                checkedIn ? '今日已签到' : '立即签到',
                style: MistralTypography.bodyMd.copyWith(
                  color: checkedIn ? MistralColors.success : AppColors.white100,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 签到统计
class _CheckInStats extends StatelessWidget {
  final ThemeVars skin;
  final int totalDays;
  final int rank;

  const _CheckInStats({required this.skin, required this.totalDays, required this.rank});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(context.design.spacing.md),
      decoration: BoxDecoration(
        color: skin.cardBg,
        borderRadius: BorderRadius.circular(context.design.radius.xl),
        border: Border.all(color: skin.divider),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatColumn(label: '累计签到', value: '$totalDays', skin: skin),
          Container(width: 1, height: 32, color: skin.divider),
          _StatColumn(label: '班级排名', value: '第$rank', skin: skin),
          Container(width: 1, height: 32, color: skin.divider),
          _StatColumn(label: '今日状态', value: '已签到', skin: skin),
        ],
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  final String label;
  final String value;
  final ThemeVars skin;

  const _StatColumn({required this.label, required this.value, required this.skin});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: MistralTypography.heading5.copyWith(color: skin.text1, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 4),
        Text(label, style: MistralTypography.bodySm.copyWith(color: skin.text3)),
      ],
    );
  }
}

/// 班级排行榜
class _ClassRankList extends StatelessWidget {
  final ThemeVars skin;
  final List<_ClassMember> members;

  const _ClassRankList({required this.skin, required this.members});

  @override
  Widget build(BuildContext context) {
    if (members.isEmpty) {
      return Container(
        padding: EdgeInsets.all(context.design.spacing.xl),
        decoration: BoxDecoration(
          color: skin.cardBg,
          borderRadius: BorderRadius.circular(context.design.radius.xl),
          border: Border.all(color: skin.divider),
        ),
        child: Center(
          child: Text('暂无排行数据', style: MistralTypography.bodyMd.copyWith(color: skin.text3)),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: skin.cardBg,
        borderRadius: BorderRadius.circular(context.design.radius.xl),
        border: Border.all(color: skin.divider),
      ),
      child: Column(
        children: List.generate(members.length, (i) {
          final m = members[i];
          return _RankTile(rank: i + 1, name: m.name, days: m.streakDays, skin: skin);
        }),
      ),
    );
  }
}

class _RankTile extends StatelessWidget {
  final int rank;
  final String name;
  final int days;
  final ThemeVars skin;

  const _RankTile({required this.rank, required this.name, required this.days, required this.skin});

  @override
  Widget build(BuildContext context) {
    final isTop3 = rank <= 3;
    final rankColors = [StarGold.gold, StarGold.silver, StarGold.bronze];

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: context.design.spacing.md, vertical: context.design.spacing.sm),
      child: Row(
        children: [
          // 排名
          Container(
            width: 28,
            height: 28,
            decoration: isTop3
                ? BoxDecoration(color: rankColors[rank - 1].withValues(alpha: 0.15), shape: BoxShape.circle)
                : null,
            child: Center(
              child: Text(
                '$rank',
                style: MistralTypography.bodySm.copyWith(
                  color: isTop3 ? rankColors[rank - 1] : skin.text3,
                  fontWeight: isTop3 ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          ),
          SizedBox(width: context.design.spacing.sm),
          // 头像
          CircleAvatar(
            radius: 16,
            backgroundColor: skin.pageBg,
            child: Text(name.isNotEmpty ? name[0] : '?', style: MistralTypography.bodySm.copyWith(color: skin.text1)),
          ),
          SizedBox(width: context.design.spacing.sm),
          // 名字
          Expanded(
            child: Text(name, style: MistralTypography.bodyMd.copyWith(color: skin.text1)),
          ),
          // 连续天数
          Text('$days 天', style: MistralTypography.bodySm.copyWith(color: skin.text3)),
        ],
      ),
    );
  }
}

/// 热门班级磁贴
class _HotClassTile extends StatelessWidget {
  final _HotClassData data;
  final ThemeVars skin;
  final VoidCallback? onTap;

  const _HotClassTile({required this.data, required this.skin, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(context.design.spacing.md),
        decoration: BoxDecoration(
          color: skin.cardBg,
          borderRadius: BorderRadius.circular(context.design.radius.xl),
          border: Border.all(color: skin.divider),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: MistralColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(context.design.radius.lg),
              ),
              child: Icon(data.icon, color: MistralColors.primary, size: 24),
            ),
            SizedBox(width: context.design.spacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.name,
                    style: MistralTypography.bodyMd.copyWith(color: skin.text1, fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 2),
                  Text('${data.members} 人已加入', style: MistralTypography.bodySm.copyWith(color: skin.text3)),
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

/// 班级成员数据
class _ClassMember {
  final String name;
  final int streakDays;

  const _ClassMember({required this.name, required this.streakDays});
}

/// 热门班级数据
class _HotClassData {
  final String name;
  final int members;
  final IconData icon;

  const _HotClassData({required this.name, required this.members, required this.icon});
}

/// 活动指引步骤
class _GuideStep extends StatelessWidget {
  final String number;
  final String title;
  final String description;
  final IconData icon;
  final ThemeVars skin;
  final bool isLast;

  const _GuideStep({
    required this.number,
    required this.title,
    required this.description,
    required this.icon,
    required this.skin,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 步骤编号和连接线
        Column(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(color: MistralColors.primary, shape: BoxShape.circle),
              child: Center(
                child: Text(
                  number,
                  style: MistralTypography.bodySm.copyWith(color: AppColors.white100, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            if (!isLast) Container(width: 2, height: 40, color: MistralColors.primary.withValues(alpha: 0.3)),
          ],
        ),
        SizedBox(width: context.design.spacing.md),
        // 内容
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 18, color: MistralColors.primary),
                  SizedBox(width: context.design.spacing.xs),
                  Text(
                    title,
                    style: MistralTypography.bodyMd.copyWith(color: skin.text1, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              SizedBox(height: 4),
              Text(description, style: MistralTypography.bodySm.copyWith(color: skin.text3)),
              if (!isLast) SizedBox(height: context.design.spacing.md),
            ],
          ),
        ),
      ],
    );
  }
}

/// 功能卡片
class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color color;
  final ThemeVars skin;

  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
    required this.skin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(context.design.spacing.md),
      decoration: BoxDecoration(
        color: skin.cardBg,
        borderRadius: BorderRadius.circular(context.design.radius.lg),
        border: Border.all(color: skin.divider),
        boxShadow: [BoxShadow(color: MistralColors.black15, blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(context.design.radius.md),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          SizedBox(height: context.design.spacing.sm),
          Text(
            title,
            style: MistralTypography.bodyMd.copyWith(color: skin.text1, fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 4),
          Text(description, style: MistralTypography.micro.copyWith(color: skin.text3)),
        ],
      ),
    );
  }
}

/// 用户评论数据
class _CommentData {
  final String userName;
  final String avatar;
  final String content;
  final int rating;
  final String time;

  const _CommentData({
    required this.userName,
    required this.avatar,
    required this.content,
    required this.rating,
    required this.time,
  });
}

/// 用户评论卡片
class _CommentCard extends StatelessWidget {
  final _CommentData comment;
  final ThemeVars skin;

  const _CommentCard({required this.comment, required this.skin});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: context.design.spacing.sm),
      padding: EdgeInsets.all(context.design.spacing.md),
      decoration: BoxDecoration(
        color: skin.cardBg,
        borderRadius: BorderRadius.circular(context.design.radius.lg),
        border: Border.all(color: skin.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 用户信息
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: MistralColors.primary.withValues(alpha: 0.12),
                child: Text(
                  comment.avatar,
                  style: MistralTypography.bodySm.copyWith(color: MistralColors.primary, fontWeight: FontWeight.w600),
                ),
              ),
              SizedBox(width: context.design.spacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      comment.userName,
                      style: MistralTypography.bodySm.copyWith(color: skin.text1, fontWeight: FontWeight.w600),
                    ),
                    Text(comment.time, style: MistralTypography.micro.copyWith(color: skin.text3)),
                  ],
                ),
              ),
              // 评分
              Row(
                children: List.generate(5, (index) {
                  return Icon(index < comment.rating ? Icons.star : Icons.star_border, size: 14, color: StarGold.gold);
                }),
              ),
            ],
          ),
          SizedBox(height: context.design.spacing.sm),
          // 评论内容
          Text(comment.content, style: MistralTypography.bodySm.copyWith(color: skin.text2, height: 1.5)),
        ],
      ),
    );
  }
}
