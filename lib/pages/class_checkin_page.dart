// 班级打卡页：加入班级 + 每日打卡 + 班级排行榜 + 学习数据
// 还原原版 v3.2 班级打卡功能入口
// 完善版：Banner+班级活动指引+功能卡片+用户评论
import 'package:flutter/material.dart';

import '../hooks/responsive.dart';
import '../theme/skin_system.dart';
import '../tokens/design_tokens.dart';

/// 班级打卡页面
///
/// 功能：加入班级、每日打卡、班级排行榜、学习数据共享
class ClassCheckInPage extends StatefulWidget {
  const ClassCheckInPage({super.key});

  static const routeName = '/class_checkin';

  @override
  State<ClassCheckInPage> createState() => _ClassCheckInPageState();
}

class _ClassCheckInPageState extends State<ClassCheckInPage> {
  // 模拟数据（后续接入 API）
  bool _hasJoinedClass = false;
  bool _checkedInToday = false;
  final String _className = '四级冲刺班';
  final int _classRank = 0;
  final int _classMemberCount = 0;
  final int _streakDays = 0;
  final List<_ClassMember> _members = [];

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
              child: _hasJoinedClass
                  ? _buildJoinedContent(context, skin)
                  : _buildJoinContent(context, skin),
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
            '班级打卡',
            style: MistralTypography.heading5.copyWith(color: skin.text1),
          ),
          const Spacer(),
          if (_hasJoinedClass)
            IconButton(
              icon: const Icon(Icons.settings, size: 20),
              color: skin.text1,
              onPressed: () {
                // TODO: 班级设置
              },
            ),
        ],
      ),
    );
  }

  // ── 未加入班级：显示加入界面 ──

  Widget _buildJoinContent(BuildContext context, ThemeVars skin) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(context.responsive.pageMargin),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.lg),
          // 1. 班级活动 Banner
          _buildBanner(skin),
          const SizedBox(height: AppSpacing.xxl),
          // 2. 班级活动指引
          _buildActivityGuide(skin),
          const SizedBox(height: AppSpacing.xxl),
          // 3. 功能卡片
          _buildFeatureCards(skin),
          const SizedBox(height: AppSpacing.xxl),
          // 4. 加入/创建班级按钮
          _buildActionButtons(context, skin),
          const SizedBox(height: AppSpacing.xxl),
          // 5. 热门班级
          _buildHotClasses(skin),
          const SizedBox(height: AppSpacing.xxl),
          // 6. 用户评论
          _buildUserComments(skin),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }

  /// 班级活动 Banner
  Widget _buildBanner(ThemeVars skin) {
    return Container(
      width: double.infinity,
      height: 180,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF667EEA), // 装饰渐变 - 保留
            Color(0xFF764BA2), // 装饰渐变 - 保留
          ],
        ),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF667EEA).withValues(alpha: 0.3), // 装饰阴影 - 保留
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          // 装饰图案
          Positioned(
            right: -20,
            top: -20,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ),
          ),
          Positioned(
            right: 30,
            bottom: -30,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
          ),
          // 内容
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    '限时活动',
                    style: MistralTypography.micro.copyWith(color: Colors.white),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '班级打卡挑战赛',
                  style: MistralTypography.heading3.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '连续打卡7天，赢取学习徽章',
                  style: MistralTypography.bodySm.copyWith(
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    '立即参与',
                    style: MistralTypography.bodySm.copyWith(
                      color: const Color(0xFF667EEA),
                      fontWeight: FontWeight.w600,
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

  /// 班级活动指引
  Widget _buildActivityGuide(ThemeVars skin) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '如何参与班级活动',
          style: MistralTypography.heading5.copyWith(color: skin.text1),
        ),
        const SizedBox(height: AppSpacing.md),
        _GuideStep(
          number: '1',
          title: '加入班级',
          description: '输入班级口令或扫描二维码加入班级',
          icon: Icons.group_add,
          skin: skin,
        ),
        _GuideStep(
          number: '2',
          title: '每日打卡',
          description: '每天学习单词后点击打卡，记录学习进度',
          icon: Icons.touch_app,
          skin: skin,
        ),
        _GuideStep(
          number: '3',
          title: '查看排行',
          description: '与班级同学比拼学习进度，互相激励',
          icon: Icons.leaderboard,
          skin: skin,
        ),
        _GuideStep(
          number: '4',
          title: '赢取奖励',
          description: '完成挑战任务，获得专属徽章和奖励',
          icon: Icons.emoji_events,
          skin: skin,
          isLast: true,
        ),
      ],
    );
  }

  /// 功能卡片
  Widget _buildFeatureCards(ThemeVars skin) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '班级功能',
          style: MistralTypography.heading5.copyWith(color: skin.text1),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: _FeatureCard(
                icon: Icons.calendar_today,
                title: '每日打卡',
                description: '记录学习天数',
                color: skin.success,
                skin: skin,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _FeatureCard(
                icon: Icons.leaderboard,
                title: '班级排行',
                description: '比拼学习进度',
                color: const Color(0xFF2196F3), // FuncColors.info - 待 token 化
                skin: skin,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: _FeatureCard(
                icon: Icons.bar_chart,
                title: '学习统计',
                description: '查看学习数据',
                color: const Color(0xFFFF9800), // FuncColors.warning - 待 token 化
                skin: skin,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _FeatureCard(
                icon: Icons.emoji_events,
                title: '挑战任务',
                description: '赢取专属徽章',
                color: const Color(0xFF9C27B0), // FuncColors.purple - 待 token 化
                skin: skin,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// 加入/创建班级按钮
  Widget _buildActionButtons(BuildContext context, ThemeVars skin) {
    return Column(
      children: [
        // 加入班级按钮
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: () => _showJoinClassDialog(context, skin),
            style: ElevatedButton.styleFrom(
              backgroundColor: MistralColors.primary,
              foregroundColor: Colors.white,
              elevation: 2,
              shadowColor: MistralColors.primary.withValues(alpha: 0.3),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.xl),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.group_add, size: 20),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  '加入班级',
                  style: MistralTypography.bodyMd.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        // 创建班级按钮
        SizedBox(
          width: double.infinity,
          height: 52,
          child: OutlinedButton(
            onPressed: () {
              // TODO: 创建班级
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: MistralColors.primary,
              side: const BorderSide(color: MistralColors.primary, width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.xl),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.add_circle_outline, size: 20),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  '创建班级',
                  style: MistralTypography.bodyMd.copyWith(
                    color: MistralColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// 用户评论
  Widget _buildUserComments(ThemeVars skin) {
    final comments = [
      _CommentData(
        userName: '小明',
        avatar: '明',
        content: '班级打卡功能让我更有动力学习了，每天和同学一起比拼，进步很快！',
        rating: 5,
        time: '3天前',
      ),
      _CommentData(
        userName: '小红',
        avatar: '红',
        content: '排行榜功能很棒，可以看到自己的学习进度，激励我继续努力。',
        rating: 5,
        time: '1周前',
      ),
      _CommentData(
        userName: '小李',
        avatar: '李',
        content: '和同学们一起学习的感觉真好，互相监督，共同进步！',
        rating: 4,
        time: '2周前',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '用户评价',
              style: MistralTypography.heading5.copyWith(color: skin.text1),
            ),
            Text(
              '查看全部',
              style: MistralTypography.bodySm.copyWith(color: MistralColors.primary),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        ...comments.map((comment) => _CommentCard(comment: comment, skin: skin)),
      ],
    );
  }

  Widget _buildHotClasses(ThemeVars skin) {
    final hotClasses = [
      _HotClassData(name: '四级冲刺班', members: 128, icon: Icons.school),
      _HotClassData(name: '六级备考班', members: 96, icon: Icons.auto_stories),
      _HotClassData(name: '考研英语班', members: 256, icon: Icons.menu_book),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '热门班级',
          style: MistralTypography.heading5.copyWith(color: skin.text1),
        ),
        const SizedBox(height: AppSpacing.sm),
        ...hotClasses.map((c) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _HotClassTile(data: c, skin: skin, onTap: () {
                setState(() {
                  _hasJoinedClass = true;
                  _className;
                });
              }),
            )),
      ],
    );
  }

  // ── 已加入班级：显示打卡界面 ──

  Widget _buildJoinedContent(BuildContext context, ThemeVars skin) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(context.responsive.pageMargin),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 班级信息卡片
          _ClassInfoCard(
            skin: skin,
            className: _className,
            memberCount: _classMemberCount,
            streakDays: _streakDays,
          ),
          const SizedBox(height: AppSpacing.lg),
          // 每日打卡按钮
          _CheckInButton(
            skin: skin,
            checkedIn: _checkedInToday,
            onTap: () {
              if (!_checkedInToday) {
                setState(() => _checkedInToday = true);
                _showCheckInSuccess(context, skin);
              }
            },
          ),
          const SizedBox(height: AppSpacing.lg),
          // 打卡统计
          _CheckInStats(
            skin: skin,
            totalDays: _streakDays,
            rank: _classRank,
          ),
          const SizedBox(height: AppSpacing.lg),
          // 班级排行榜
          Text(
            '班级排行榜',
            style: MistralTypography.heading5.copyWith(color: skin.text1),
          ),
          const SizedBox(height: AppSpacing.sm),
          _ClassRankList(skin: skin, members: _members),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }

  // ── 弹窗 ──

  void _showJoinClassDialog(BuildContext context, ThemeVars skin) {
    final codeController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: skin.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.lg,
          right: AppSpacing.lg,
          top: AppSpacing.lg,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '加入班级',
              style: MistralTypography.heading4.copyWith(color: skin.text1),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: codeController,
              decoration: InputDecoration(
                hintText: '请输入班级口令',
                hintStyle: TextStyle(color: skin.text3),
                filled: true,
                fillColor: skin.pageBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  setState(() => _hasJoinedClass = true);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: MistralColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                  ),
                ),
                child: Text(
                  '加入',
                  style: MistralTypography.bodyMd.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCheckInSuccess(BuildContext context, ThemeVars skin) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text('打卡成功！连续 $_streakDays 天'),
          ],
        ),
        backgroundColor: MistralColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

// ── 子组件 ──

/// 班级信息卡片
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
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            MistralColors.primary.withValues(alpha: 0.85),
            MistralColors.primaryDeep.withValues(alpha: 0.75),
          ],
        ),
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            className,
            style: MistralTypography.heading4.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '$memberCount 名成员',
            style: MistralTypography.bodySm.copyWith(
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              _StatItem(label: '连续打卡', value: '$streakDays 天'),
              const SizedBox(width: AppSpacing.xl),
              _StatItem(label: '班级排名', value: '第 $_classRank 名'),
            ],
          ),
        ],
      ),
    );
  }

  int get _classRank => 0; // placeholder
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
          style: MistralTypography.heading3.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: MistralTypography.bodySm.copyWith(
            color: Colors.white.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }
}

/// 每日打卡按钮
class _CheckInButton extends StatelessWidget {
  final ThemeVars skin;
  final bool checkedIn;
  final VoidCallback? onTap;

  const _CheckInButton({
    required this.skin,
    required this.checkedIn,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          color: checkedIn ? skin.cardBg : MistralColors.primary,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: checkedIn ? Border.all(color: skin.divider) : null,
        ),
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                checkedIn ? Icons.check_circle : Icons.touch_app,
                color: checkedIn ? MistralColors.success : Colors.white,
                size: 22,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                checkedIn ? '今日已打卡' : '立即打卡',
                style: MistralTypography.bodyMd.copyWith(
                  color: checkedIn ? MistralColors.success : Colors.white,
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

/// 打卡统计
class _CheckInStats extends StatelessWidget {
  final ThemeVars skin;
  final int totalDays;
  final int rank;

  const _CheckInStats({
    required this.skin,
    required this.totalDays,
    required this.rank,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: skin.cardBg,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: skin.divider),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatColumn(label: '累计打卡', value: '$totalDays', skin: skin),
          Container(width: 1, height: 32, color: skin.divider),
          _StatColumn(label: '班级排名', value: '第$rank', skin: skin),
          Container(width: 1, height: 32, color: skin.divider),
          _StatColumn(label: '今日状态', value: '已打卡', skin: skin),
        ],
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  final String label;
  final String value;
  final ThemeVars skin;

  const _StatColumn({
    required this.label,
    required this.value,
    required this.skin,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: MistralTypography.heading5.copyWith(
            color: skin.text1,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: MistralTypography.bodySm.copyWith(color: skin.text3),
        ),
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
        padding: const EdgeInsets.all(AppSpacing.xl),
        decoration: BoxDecoration(
          color: skin.cardBg,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(color: skin.divider),
        ),
        child: Center(
          child: Text(
            '暂无排行数据',
            style: MistralTypography.bodyMd.copyWith(color: skin.text3),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: skin.cardBg,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: skin.divider),
      ),
      child: Column(
        children: List.generate(members.length, (i) {
          final m = members[i];
          return _RankTile(
            rank: i + 1,
            name: m.name,
            days: m.streakDays,
            skin: skin,
          );
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

  const _RankTile({
    required this.rank,
    required this.name,
    required this.days,
    required this.skin,
  });

  @override
  Widget build(BuildContext context) {
    final isTop3 = rank <= 3;
    final rankColors = [
      const Color(0xFFFFD700), // StarGold.gold - 待 token 化
      const Color(0xFFC0C0C0), // StarGold.silver - 待 token 化
      const Color(0xFFCD7F32), // StarGold.bronze - 待 token 化
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          // 排名
          Container(
            width: 28,
            height: 28,
            decoration: isTop3
                ? BoxDecoration(
                    color: rankColors[rank - 1].withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  )
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
          const SizedBox(width: AppSpacing.sm),
          // 头像
          CircleAvatar(
            radius: 16,
            backgroundColor: skin.pageBg,
            child: Text(
              name.isNotEmpty ? name[0] : '?',
              style: MistralTypography.bodySm.copyWith(color: skin.text1),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          // 名字
          Expanded(
            child: Text(
              name,
              style: MistralTypography.bodyMd.copyWith(color: skin.text1),
            ),
          ),
          // 连续天数
          Text(
            '$days 天',
            style: MistralTypography.bodySm.copyWith(color: skin.text3),
          ),
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

  const _HotClassTile({
    required this.data,
    required this.skin,
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
          border: Border.all(color: skin.divider),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: MistralColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              child: Icon(data.icon, color: MistralColors.primary, size: 24),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.name,
                    style: MistralTypography.bodyMd.copyWith(
                      color: skin.text1,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${data.members} 人已加入',
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

  const _HotClassData({
    required this.name,
    required this.members,
    required this.icon,
  });
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
              decoration: BoxDecoration(
                color: MistralColors.primary,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  number,
                  style: MistralTypography.bodySm.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 40,
                color: MistralColors.primary.withValues(alpha: 0.3),
              ),
          ],
        ),
        const SizedBox(width: AppSpacing.md),
        // 内容
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 18, color: MistralColors.primary),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    title,
                    style: MistralTypography.bodyMd.copyWith(
                      color: skin.text1,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: MistralTypography.bodySm.copyWith(color: skin.text3),
              ),
              if (!isLast) const SizedBox(height: AppSpacing.md),
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
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: skin.cardBg,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: skin.divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            title,
            style: MistralTypography.bodyMd.copyWith(
              color: skin.text1,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: MistralTypography.micro.copyWith(color: skin.text3),
          ),
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
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: skin.cardBg,
        borderRadius: BorderRadius.circular(AppRadius.lg),
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
                  style: MistralTypography.bodySm.copyWith(
                    color: MistralColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      comment.userName,
                      style: MistralTypography.bodySm.copyWith(
                        color: skin.text1,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      comment.time,
                      style: MistralTypography.micro.copyWith(color: skin.text3),
                    ),
                  ],
                ),
              ),
              // 评分
              Row(
                children: List.generate(5, (index) {
                  return Icon(
                    index < comment.rating ? Icons.star : Icons.star_border,
                    size: 14,
                    color: const Color(0xFFFFD700), // StarGold.gold - 待 token 化
                  );
                }),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          // 评论内容
          Text(
            comment.content,
            style: MistralTypography.bodySm.copyWith(
              color: skin.text2,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
