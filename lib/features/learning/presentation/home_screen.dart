// Monster Word — 首页（星巴克改造 batch4a）
// 星巴克设计方案：奶油画布 + 白卡 + 圆润温润
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:word_app/core/router/route_names.dart';
import 'package:word_app/features/book/application/book_catalog_reader.dart';
import 'package:word_app/features/checkin/application/checkin_status_reader.dart';
import 'package:word_app/core/presentation/responsive.dart';
import 'package:word_app/features/learning/presentation/learn_page.dart';
import 'package:word_app/features/learning/presentation/word_machine_page.dart';
import 'package:word_app/features/learning/presentation/learning_session_state.dart';
import 'package:word_app/features/learning/presentation/learning_statistics_state.dart';
import 'package:word_app/theme/skin_system.dart';
import 'package:word_app/tokens/design_tokens.dart';
import 'package:word_app/widgets/mw_card.dart';
import 'package:word_app/widgets/daily_goal_picker.dart';
import 'package:word_app/features/learning/presentation/review_dialog.dart';
import 'package:word_app/widgets/scale_down_on_press.dart';
import 'package:word_app/widgets/spring_check_in_calendar.dart';
import 'package:word_app/widgets/testimonial_slider.dart';
import 'package:word_app/widgets/text_reveal_card.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  String _formatDate() {
    final now = DateTime.now();
    const weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    return '${now.month}月${now.day}日 ${weekdays[now.weekday - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final resp = context.responsive;

    // 横屏检测
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    // 方案C：奶油画布，移除壁纸系统
    // 下滑查词：在首页任意位置向下滑动打开查词页（提示卡也可直接点击）
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragEnd: (details) {
        final v = details.primaryVelocity ?? 0;
        if (v > 160) Navigator.pushNamed(context, RouteNames.search);
      },
      child: Container(
        color: skin.colors.pageBg,
        child: Stack(
          children: [
            SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: isLandscape ? double.infinity : resp.contentMaxWidth),
                  child: isLandscape
                      ? _buildLandscapeLayout(context, skin, resp)
                      : Column(
                          children: [
                            const Spacer(flex: 2),
                            // 签到卡片（MwCard 白卡，替代毛玻璃）
                            _EntranceIn(delayMs: 120, child: _buildCheckInCard(context, skin)),
                            const Spacer(flex: 2),
                            // Learn / Review 入口卡（MwCard 替代 GlassEntryCard）
                            _EntranceIn(
                              delayMs: 260,
                              child: Padding(
                                padding: EdgeInsets.fromLTRB(resp.pageMargin, 0, resp.pageMargin, 16),
                                // Selector 只订阅学习统计快照，避免会话状态变化导致整页 rebuild。
                                child: Selector<LearningStatisticsState, ({int remaining, int dueCount})>(
                                  // 用户需求：Learn 显示「今日目标 - 今日已学」剩余量，与 Review 动态联动
                                  selector: (_, s) => (remaining: s.todayRemaining, dueCount: s.dueCount),
                                  builder: (context, state, _) => Row(
                                    children: [
                                      Expanded(
                                        child: _EntryCard(
                                          title: 'Learn',
                                          count: state.remaining,
                                          // 直接开始背单词（不再跳转到选书页）
                                          onTap: () => _startLearning(context),
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
                              ),
                            ),
                            // 每日学习目标选择器（滚轮选择 1-200 个单词/天）
                            _EntranceIn(delayMs: 320, child: const DailyGoalPicker()),
                            // 每日一句励志语轮播（testimonial-slider，自动轮播+弹性滑动）
                            _EntranceIn(
                              delayMs: 380,
                              child: Padding(
                                padding: EdgeInsets.fromLTRB(resp.pageMargin, 0, resp.pageMargin, 16),
                                child: TestimonialSlider(
                                  items: TestimonialData.defaults,
                                  height: 120,
                                  activeColor: skin.colors.accent,
                                  inactiveColor: skin.colors.divider,
                                  borderRadius: BorderRadius.circular(24),
                                ),
                              ),
                            ),
                            // 底部：选择词书区域（点击跳转到词书选择页）
                            _EntranceIn(
                              delayMs: 480,
                              child: Padding(
                                padding: EdgeInsets.fromLTRB(resp.pageMargin, 0, resp.pageMargin, 16),
                                child: _buildBookSelector(context, skin, resp),
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
            // 右上角：单词机入口（GameBoy 风格保留，word_machine 豁免）
            Positioned(top: 0, right: 0, child: _buildWordMachineButton(context, skin)),
            // 左上角：查词入口（MwCard 风格圆形按钮）
            Positioned(top: 0, left: 0, child: _buildSearchButton(context, skin)),
          ],
        ),
      ),
    );
  }

  /// 直接开始背单词（加载第一本书并跳转到学习页）
  Future<void> _startLearning(BuildContext context) async {
    // 学习会话由 LearningSessionState 统一驱动，与 LearnPage 保持一致。
    final state = context.read<LearningSessionState>();
    // 如果已有队列，直接开始学习
    if (state.queue.isNotEmpty) {
      if (context.mounted) {
        Navigator.pushNamed(context, LearnPage.routeName);
      }
      return;
    }
    final books = await context.read<BookCatalogReader>().listBooks();
    if (books.isEmpty) {
      // B-1 空态引导：无词书时引导去选词书页，而非仅弹 SnackBar
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('还没有词书，先去选一本吧'),
            action: SnackBarAction(
              label: '去选词书',
              onPressed: () {
                if (context.mounted) {
                  Navigator.pushNamed(context, RouteNames.libSelect);
                }
              },
            ),
          ),
        );
      }
      return;
    }
    // 本次冷启动还没有选过书：先给引导弹层（明确选择感），
    // 用户可"去选词书"或"随便学一本"（保留旧的自动第一本快捷路径）。
    if (state.currentBook == null && context.mounted) {
      final goPick = await showModalBottomSheet<bool>(
        context: context,
        builder: (sheetCtx) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('开始今天的学习', style: Theme.of(sheetCtx).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text('选择一本词书，或直接从第一本开始', style: Theme.of(sheetCtx).textTheme.bodyMedium),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => Navigator.pop(sheetCtx, true),
                    icon: const Icon(Icons.menu_book_rounded, size: 18),
                    label: const Text('去选词书'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(onPressed: () => Navigator.pop(sheetCtx, false), child: const Text('随便学一本')),
                ),
              ],
            ),
          ),
        ),
      );
      if (goPick == true) {
        if (context.mounted) {
          Navigator.pushNamed(context, RouteNames.libSelect);
        }
        return;
      }
    }
    // 加载第一本书（乱序）——"随便学一本"路径
    await state.loadBook(books.first, shuffle: true);
    if (context.mounted) {
      Navigator.pushNamed(context, LearnPage.routeName);
    }
  }

  /// 底部词书选择器（点击跳转到词书选择页）
  Widget _buildBookSelector(BuildContext context, SkinSystem skin, AppResponsive resp) {
    return ScaleDownOnPress(
      onTap: () => Navigator.pushNamed(context, RouteNames.libSelect),
      child: MwCard(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Icon(Icons.library_books_outlined, color: skin.colors.accent, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '选择词书',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: skin.colors.text1),
                  ),
                  const SizedBox(height: 2),
                  Text('点击切换不同的单词书', style: TextStyle(fontSize: 13, color: skin.colors.text3)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 20, color: skin.colors.text3),
          ],
        ),
      ),
    );
  }

  /// 横屏布局：左右分栏
  Widget _buildLandscapeLayout(BuildContext context, SkinSystem skin, AppResponsive resp) {
    return Row(
      children: [
        // 左侧：签到 + 入口
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _EntranceIn(delayMs: 120, child: _buildCheckInCard(context, skin)),
              const SizedBox(height: 16),
              _EntranceIn(
                delayMs: 200,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: resp.pageMargin),
                  child: Selector<LearningStatisticsState, ({int remaining, int dueCount})>(
                    selector: (_, s) => (remaining: s.todayRemaining, dueCount: s.dueCount),
                    builder: (context, state, _) => Row(
                      children: [
                        Expanded(
                          child: _EntryCard(
                            title: 'Learn',
                            count: state.remaining,
                            // 横屏布局也直接开始背单词
                            onTap: () => _startLearning(context),
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
                ),
              ),
            ],
          ),
        ),
        // 右侧：推荐语 + 选择词书
        Expanded(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _EntranceIn(
                  delayMs: 380,
                  child: Padding(
                    padding: EdgeInsets.all(resp.pageMargin),
                    child: TestimonialSlider(
                      items: TestimonialData.defaults,
                      height: 160,
                      activeColor: skin.colors.accent,
                      inactiveColor: skin.colors.divider,
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // 横屏布局：底部词书选择器
                _EntranceIn(
                  delayMs: 480,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: resp.pageMargin),
                    child: _buildBookSelector(context, skin, resp),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// 签到卡片（TextRevealCard：点击揭示每日一句）；右上角「签到」角标打开弹性签到日历
  Widget _buildCheckInCard(BuildContext context, SkinSystem skin) {
    return Center(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          TextRevealCard(
            title: '📅 签到 ${_formatDate()}',
            revealText:
                '"The limits of my language mean the limits of my world." — Wittgenstein\n\n今天也要加油背单词！每一个单词都在拓展你的世界。',
            icon: null,
            bgColor: skin.colors.cardBg,
            revealBgColor: skin.colors.cardBgAlt,
            titleStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: skin.colors.text1),
            revealStyle: TextStyle(fontSize: 13, color: skin.colors.text2, height: 1.5),
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
            borderRadius: 16,
          ),
          // 弹性签到日历入口（不干扰卡片自身的每日一句揭示交互）
          Positioned(top: -8, right: -8, child: _CheckInBadge(skin: skin)),
          // 查看签到历史按钮
          Positioned(
            top: -8,
            left: -8,
            child: ScaleDownOnPress(
              onTap: () => Navigator.pushNamed(context, '/check_in_history'),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: skin.colors.cardBg,
                  shape: BoxShape.circle,
                  boxShadow: const [
                    BoxShadow(color: Color(0x23000000), blurRadius: 0.5, offset: Offset(0, 0)),
                    BoxShadow(color: Color(0x3D000000), blurRadius: 1.0, offset: Offset(0, 1)),
                  ],
                ),
                child: Icon(Icons.calendar_today, size: 16, color: skin.colors.accent),
              ),
            ),
          ),
        ],
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
              boxShadow: [BoxShadow(color: MistralColors.black26, blurRadius: 6, offset: const Offset(0, 2))],
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

  /// 左上角查词入口按钮（点击打开词典查询界面）
  Widget _buildSearchButton(BuildContext context, dynamic skin) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(left: 12, top: 12),
        child: ScaleDownOnPress(
          onTap: () => Navigator.pushNamed(context, RouteNames.search),
          child: Tooltip(
            message: '词典查询',
            triggerMode: TooltipTriggerMode.longPress,
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
      ),
    );
  }
}

/// 入场动画：淡入 + 上滑，delayMs 提供错峰节奏（首页卡片灵动感）
class _EntranceIn extends StatelessWidget {
  final Widget child;
  final int delayMs;

  const _EntranceIn({required this.child, this.delayMs = 0});

  @override
  Widget build(BuildContext context) {
    final total = 520 + delayMs;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: total),
      // 用 Interval 把延迟编入时间线：前段保持初值，实现"晚开始"
      curve: Interval(delayMs / total, 1.0, curve: Curves.easeOutCubic),
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.translate(offset: Offset(0, 24 * (1 - t)), child: child),
      ),
      child: child,
    );
  }
}

/// 入口卡片（替代 GlassEntryCard，使用 MwCard 白卡风格）
class _EntryCard extends StatelessWidget {
  final String title;
  final int count;
  final VoidCallback onTap;

  const _EntryCard({required this.title, required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final resp = context.responsive;
    // 微交互：按压缩放反馈（星巴克 --buttonActiveScale）
    return ScaleDownOnPress(
      onTap: onTap,
      child: MwCard(
        padding: EdgeInsets.symmetric(vertical: 20 * resp.scale, horizontal: 16 * resp.scale),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: TextStyle(fontSize: 18 * resp.fontScale, fontWeight: FontWeight.w700, color: skin.colors.text1),
            ),
            const SizedBox(height: 8),
            Text(
              '$count',
              style: TextStyle(fontSize: 28 * resp.fontScale, fontWeight: FontWeight.w300, color: skin.colors.accent),
            ),
            const SizedBox(height: 4),
            Text(
              title == 'Learn' ? '待学' : '待复习',
              style: TextStyle(fontSize: 12 * resp.fontScale, color: skin.colors.text3),
            ),
          ],
        ),
      ),
    );
  }
}

/// 签到角标：根据签到状态自适应展示。
/// 未签到 → 橙色高亮「签到 +10」；已签到 → 中性态「已签 N 天」并把连签天数前置展示。
/// 角标自行打开弹性签到日历，弹层关闭后自动刷新状态。
class _CheckInBadge extends StatefulWidget {
  const _CheckInBadge({required this.skin});

  final SkinSystem skin;

  @override
  State<_CheckInBadge> createState() => _CheckInBadgeState();
}

class _CheckInBadgeState extends State<_CheckInBadge> {
  bool? _checkedToday;
  int _streakDays = 0;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final reader = context.read<CheckinStatusReader>();
    final results = await Future.wait([reader.hasCheckedInToday(), reader.getStreakDays()]);
    if (!mounted) return;
    setState(() {
      _checkedToday = results[0] as bool;
      _streakDays = results[1] as int;
    });
  }

  Future<void> _openSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetCtx) => Padding(
        padding: EdgeInsets.only(left: 20, right: 20, top: 12, bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 24),
        child: const SpringCheckInCalendar(),
      ),
    );
    unawaited(_reload());
  }

  @override
  Widget build(BuildContext context) {
    final checked = _checkedToday;
    if (checked == null) {
      // 加载中：占位避免布局跳动
      return const SizedBox(width: 84, height: 32);
    }
    final skin = widget.skin.colors;
    final isDark = widget.skin.effectiveUiBrightness == Brightness.dark;

    if (checked) {
      // 已签到：中性胶囊 + 连签天数前置
      return ScaleDownOnPress(
        onTap: _openSheet,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: skin.cardBg,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: skin.divider),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🔥', style: TextStyle(fontSize: 12)),
              const SizedBox(width: 4),
              Text(
                '已签 $_streakDays 天',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isDark ? skin.text1 : skin.text2),
              ),
            ],
          ),
        ),
      );
    }

    // 未签到：橙色高亮召唤
    return ScaleDownOnPress(
      onTap: _openSheet,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [AppColors.highlightOrange, MistralColors.sunshine500]),
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(
              color: AppColors.highlightOrange.withValues(alpha: 0.35),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.redeem_rounded, size: 14, color: AppColors.white100),
            SizedBox(width: 4),
            Text(
              '签到 +10',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.white100),
            ),
          ],
        ),
      ),
    );
  }
}
