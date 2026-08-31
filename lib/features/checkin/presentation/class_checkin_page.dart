// 班级签到页：加入班级 + 每日签到 + 班级排行榜 + 学习数据
// 还原原版 v3.2 班级签到功能入口
// 完善版：Banner+班级活动指引+功能卡片+用户评论
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:word_app/core/router/nav_utils.dart';
import 'package:word_app/core/presentation/responsive.dart';
import 'package:word_app/theme/skin_system.dart';
import 'package:word_app/tokens/design_tokens.dart';
import 'package:word_app/tokens/func_colors.dart';
import 'package:word_app/tokens/star_gold.dart';
import 'package:word_app/widgets/spring_calendar.dart';
import 'package:word_app/features/scare_coin/application/scare_coin_store.dart';

part 'class_checkin_widgets.dart';
part 'class_checkin_calendar.dart';

/// 班级签到页面
///
/// 功能：加入班级、每日签到、班级排行榜、学习数据共享
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
            Expanded(child: _hasJoinedClass ? _buildJoinedContent(context, skin) : _buildJoinContent(context, skin)),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, ThemeVars skin) {
    return Container(
      height: context.design.spacing.navH,
      padding: EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
            color: skin.text1,
            onPressed: () => NavUtils.safePop(context),
          ),
          SizedBox(width: 4),
          Text('班级签到', style: MistralTypography.heading5.copyWith(color: skin.text1)),
          const Spacer(),
          if (_hasJoinedClass)
            IconButton(
              icon: Badge(
                label: const Text('即将', style: TextStyle(fontSize: 8, color: Colors.white)),
                backgroundColor: Colors.orange,
                child: Icon(Icons.settings, size: 20, color: skin.text1),
              ),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('班级设置功能即将上线，敬请期待'), duration: Duration(seconds: 1)),
                );
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
          SizedBox(height: context.design.spacing.lg),
          // 1. 班级活动 Banner
          _buildBanner(skin),
          SizedBox(height: context.design.spacing.xxl),
          // 2. 班级活动指引
          _buildActivityGuide(skin),
          SizedBox(height: context.design.spacing.xxl),
          // 3. 功能卡片
          _buildFeatureCards(skin),
          SizedBox(height: context.design.spacing.xxl),
          // 4. 加入/创建班级按钮
          _buildActionButtons(context, skin),
          SizedBox(height: context.design.spacing.xxl),
          // 5. 热门班级
          _buildHotClasses(skin),
          SizedBox(height: context.design.spacing.xxl),
          // 6. 用户评论
          _buildUserComments(skin),
          SizedBox(height: context.design.spacing.xl),
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
        borderRadius: BorderRadius.circular(context.design.radius.xl),
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
              decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.white100.withValues(alpha: 0.1)),
            ),
          ),
          Positioned(
            right: 30,
            bottom: -30,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.white100.withValues(alpha: 0.08)),
            ),
          ),
          // 内容
          Padding(
            padding: EdgeInsets.all(context.design.spacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.white100.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(context.design.radius.pill),
                  ),
                  child: Text('限时活动', style: MistralTypography.micro.copyWith(color: AppColors.white100)),
                ),
                SizedBox(height: context.design.spacing.sm),
                Text(
                  '班级签到挑战赛',
                  style: MistralTypography.heading3.copyWith(color: AppColors.white100, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: context.design.spacing.xs),
                Text(
                  '连续签到7天，赢取学习徽章',
                  style: MistralTypography.bodySm.copyWith(color: AppColors.white100.withValues(alpha: 0.9)),
                ),
                SizedBox(height: context.design.spacing.md),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.white100,
                    borderRadius: BorderRadius.circular(context.design.radius.pill),
                  ),
                  child: Text(
                    '立即参与',
                    style: MistralTypography.bodySm.copyWith(color: skin.accent, fontWeight: FontWeight.w600),
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
        Text('如何参与班级活动', style: MistralTypography.heading5.copyWith(color: skin.text1)),
        SizedBox(height: context.design.spacing.md),
        _GuideStep(number: '1', title: '加入班级', description: '输入班级口令或扫描二维码加入班级', icon: Icons.group_add, skin: skin),
        _GuideStep(number: '2', title: '每日签到', description: '每天学习单词后点击签到，记录学习进度', icon: Icons.touch_app, skin: skin),
        _GuideStep(number: '3', title: '查看排行', description: '与班级同学比拼学习进度，互相激励', icon: Icons.leaderboard, skin: skin),
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
        Text('班级功能', style: MistralTypography.heading5.copyWith(color: skin.text1)),
        SizedBox(height: context.design.spacing.md),
        Row(
          children: [
            Expanded(
              child: _FeatureCard(
                icon: Icons.calendar_today,
                title: '每日签到',
                description: '记录学习天数',
                color: skin.success,
                skin: skin,
              ),
            ),
            SizedBox(width: context.design.spacing.sm),
            Expanded(
              child: _FeatureCard(
                icon: Icons.leaderboard,
                title: '班级排行',
                description: '比拼学习进度',
                color: FuncColors.info,
                skin: skin,
              ),
            ),
          ],
        ),
        SizedBox(height: context.design.spacing.sm),
        Row(
          children: [
            Expanded(
              child: _FeatureCard(
                icon: Icons.bar_chart,
                title: '学习统计',
                description: '查看学习数据',
                color: FuncColors.warning,
                skin: skin,
              ),
            ),
            SizedBox(width: context.design.spacing.sm),
            Expanded(
              child: _FeatureCard(
                icon: Icons.emoji_events,
                title: '挑战任务',
                description: '赢取专属徽章',
                color: FuncColors.purple,
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
              foregroundColor: AppColors.white100,
              elevation: 2,
              shadowColor: MistralColors.primary.withValues(alpha: 0.3),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(context.design.radius.xl)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.group_add, size: 20),
                SizedBox(width: context.design.spacing.xs),
                Text(
                  '加入班级',
                  style: MistralTypography.bodyMd.copyWith(color: AppColors.white100, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: context.design.spacing.sm),
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(context.design.radius.xl)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.add_circle_outline, size: 20),
                SizedBox(width: context.design.spacing.xs),
                Text(
                  '创建班级',
                  style: MistralTypography.bodyMd.copyWith(color: MistralColors.primary, fontWeight: FontWeight.w600),
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
      _CommentData(userName: '用户A', avatar: 'A', content: '班级签到功能让我更有动力学习了，每天和同学一起比拼，进步很快！', rating: 5, time: '3天前'),
      _CommentData(userName: '用户B', avatar: 'B', content: '排行榜功能很棒，可以看到自己的学习进度，激励我继续努力。', rating: 5, time: '1周前'),
      _CommentData(userName: '用户C', avatar: 'C', content: '和同学们一起学习的感觉真好，互相监督，共同进步！', rating: 4, time: '2周前'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('用户评价', style: MistralTypography.heading5.copyWith(color: skin.text1)),
            Text('查看全部', style: MistralTypography.bodySm.copyWith(color: MistralColors.primary)),
          ],
        ),
        SizedBox(height: context.design.spacing.md),
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
        Text('热门班级', style: MistralTypography.heading5.copyWith(color: skin.text1)),
        SizedBox(height: context.design.spacing.sm),
        ...hotClasses.map(
          (c) => Padding(
            padding: EdgeInsets.only(bottom: context.design.spacing.sm),
            child: _HotClassTile(
              data: c,
              skin: skin,
              onTap: () {
                setState(() {
                  _hasJoinedClass = true;
                  _className;
                });
              },
            ),
          ),
        ),
      ],
    );
  }

  // ── 已加入班级：显示签到界面 ──

  Widget _buildJoinedContent(BuildContext context, ThemeVars skin) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(context.responsive.pageMargin),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 班级信息卡片
          _ClassInfoCard(skin: skin, className: _className, memberCount: _classMemberCount, streakDays: _streakDays),
          SizedBox(height: context.design.spacing.lg),
          // 每日签到按钮
          _CheckInButton(
            skin: skin,
            checkedIn: _checkedInToday,
            onTap: () async {
              if (_checkedInToday) return;
              // 接入真实签到逻辑：+10 尖叫币（与首页弹性日历共用账本）
              await context.read<ScareCoinStore>().checkIn();
              if (!context.mounted) return;
              setState(() => _checkedInToday = true);
              _showCheckInSuccess(context, skin);
            },
          ),
          SizedBox(height: context.design.spacing.lg),
          // 签到统计
          _CheckInStats(skin: skin, totalDays: _streakDays, rank: _classRank),
          SizedBox(height: context.design.spacing.lg),
          // 弹性签到日历（spring_calendar，数据来自尖叫币账本）
          _SpringCalendarCard(skin: skin),
          SizedBox(height: context.design.spacing.lg),
          // 班级排行榜
          Text('班级排行榜', style: MistralTypography.heading5.copyWith(color: skin.text1)),
          SizedBox(height: context.design.spacing.sm),
          _ClassRankList(skin: skin, members: _members),
          SizedBox(height: context.design.spacing.xl),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(context.design.radius.xl))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: context.design.spacing.lg,
          right: context.design.spacing.lg,
          top: context.design.spacing.lg,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + context.design.spacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('加入班级', style: MistralTypography.heading4.copyWith(color: skin.text1)),
            SizedBox(height: context.design.spacing.md),
            TextField(
              controller: codeController,
              decoration: InputDecoration(
                hintText: '请输入班级口令',
                hintStyle: TextStyle(color: skin.text3),
                filled: true,
                fillColor: skin.pageBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(context.design.radius.lg),
                  borderSide: BorderSide.none,
                ),
                contentPadding: EdgeInsets.symmetric(horizontal: context.design.spacing.md, vertical: context.design.spacing.sm),
              ),
            ),
            SizedBox(height: context.design.spacing.md),
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
                  foregroundColor: AppColors.white100,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(context.design.radius.lg)),
                ),
                child: Text(
                  '加入',
                  style: MistralTypography.bodyMd.copyWith(color: AppColors.white100, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    ).then((_) => codeController.dispose());
  }

  void _showCheckInSuccess(BuildContext context, ThemeVars skin) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: AppColors.white100, size: 20),
            SizedBox(width: 8),
            Text('签到成功！连续 $_streakDays 天'),
          ],
        ),
        backgroundColor: MistralColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(context.design.radius.md)),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

// ── 子组件 ──

/// 班级信息卡片
