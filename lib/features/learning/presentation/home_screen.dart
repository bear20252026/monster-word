// Monster Word — 首页（"今日"版式）
// 层级：问候头部 → 今日进度主卡（学习/复习 CTA）→ 签到条 → 词书条 → 目标档位 → 引言脚注
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:word_app/app/router/route_names.dart';
import 'package:word_app/core/infrastructure/app_preferences.dart';
import 'package:word_app/core/presentation/responsive.dart';
import 'package:word_app/features/book/application/book_catalog_reader.dart';
import 'package:word_app/features/checkin/application/checkin_status_reader.dart';
import 'package:word_app/features/learning/presentation/learn_page.dart';
import 'package:word_app/features/learning/presentation/word_machine_page.dart';
import 'package:word_app/features/learning/presentation/learning_session_state.dart';
import 'package:word_app/features/learning/presentation/learning_statistics_state.dart';
import 'package:word_app/theme/skin_system.dart';
import 'package:word_app/tokens/design_tokens.dart';
import 'package:word_app/widgets/app_dock.dart';
import 'package:word_app/widgets/mw_card.dart';
import 'package:word_app/widgets/daily_goal_picker.dart';
import 'package:word_app/features/learning/presentation/review_dialog.dart';
import 'package:word_app/widgets/scale_down_on_press.dart';
import 'package:word_app/widgets/spring_check_in_calendar.dart';
import 'package:word_app/widgets/testimonial_slider.dart' show TestimonialData;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  /// 目标档位变更信号：设置后首页主卡的进度环/文案立即重读偏好刷新。
  final ValueNotifier<int> _goalSignal = ValueNotifier(0);

  @override
  void dispose() {
    _goalSignal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final resp = context.responsive;
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    // 下滑查词：在首页任意位置向下滑动打开查词页
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragEnd: (details) {
        final v = details.primaryVelocity ?? 0;
        if (v > 160) Navigator.pushNamed(context, RouteNames.search);
      },
      child: Container(
        color: skin.colors.pageBg,
        child: SafeArea(
          bottom: false,
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: isLandscape ? double.infinity : resp.contentMaxWidth),
              child: Padding(
                // 底部为悬浮 Dock 预留空隙（Dock 悬浮于内容之上）
                padding: EdgeInsets.only(bottom: FloatingDock.clearance(context) + 8),
                child: isLandscape ? _buildLandscape(context, skin, resp) : _buildPortrait(context, skin, resp),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---- 竖屏 ----

  Widget _buildPortrait(BuildContext context, SkinSystem skin, AppResponsive resp) {
    return Column(
      children: [
        _EntranceIn(child: _Header(skin: skin)),
        const Spacer(flex: 3),
        // 今日进度主卡（唯一视觉锚点）
        _EntranceIn(
          delayMs: 80,
          child: Padding(
            padding: EdgeInsets.fromLTRB(resp.pageMargin, 0, resp.pageMargin, 12),
            child: _TodayHeroCard(goalSignal: _goalSignal),
          ),
        ),
        // 签到条
        _EntranceIn(
          delayMs: 180,
          child: Padding(
            padding: EdgeInsets.fromLTRB(resp.pageMargin, 0, resp.pageMargin, 12),
            child: const _CheckInStrip(),
          ),
        ),
        // 当前词书条
        _EntranceIn(
          delayMs: 260,
          child: Padding(
            padding: EdgeInsets.fromLTRB(resp.pageMargin, 0, resp.pageMargin, 12),
            child: const _BookStrip(),
          ),
        ),
        // 每日目标快捷档位
        _EntranceIn(
          delayMs: 340,
          child: Padding(
            padding: EdgeInsets.fromLTRB(resp.pageMargin, 0, resp.pageMargin, 0),
            child: _GoalChips(goalSignal: _goalSignal),
          ),
        ),
        const Spacer(flex: 2),
        // 每日一句脚注
        _EntranceIn(delayMs: 420, child: const _QuoteFooter()),
      ],
    );
  }

  // ---- 横屏：左右分栏 ----

  Widget _buildLandscape(BuildContext context, SkinSystem skin, AppResponsive resp) {
    return Column(
      children: [
        _EntranceIn(child: _Header(skin: skin)),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Padding(
                  padding: EdgeInsets.all(resp.pageMargin),
                  child: _TodayHeroCard(goalSignal: _goalSignal),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.all(resp.pageMargin),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _EntranceIn(delayMs: 180, child: const _CheckInStrip()),
                      const SizedBox(height: 12),
                      _EntranceIn(delayMs: 260, child: const _BookStrip()),
                      const SizedBox(height: 12),
                      _EntranceIn(delayMs: 340, child: _GoalChips(goalSignal: _goalSignal)),
                      const SizedBox(height: 16),
                      _EntranceIn(delayMs: 420, child: const _QuoteFooter()),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 问候头部：按时段问候 + 日期；右侧词典/单词机入口。
class _Header extends StatelessWidget {
  const _Header({required this.skin});

  final SkinSystem skin;

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 11) return '早上好';
    if (hour >= 11 && hour < 13) return '中午好';
    if (hour >= 13 && hour < 18) return '下午好';
    return '晚上好';
  }

  String _dateLabel() {
    final now = DateTime.now();
    const weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    return '${now.month}月${now.day}日 ${weekdays[now.weekday - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = skin.colors;
    final resp = context.responsive;
    return Padding(
      padding: EdgeInsets.fromLTRB(resp.pageMargin, 12, resp.pageMargin, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _greeting(),
                  style: TextStyle(
                    fontSize: 26 * resp.fontScale,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                    letterSpacing: -0.5,
                    color: colors.text1,
                  ),
                ),
                const SizedBox(height: 3),
                Text(_dateLabel(), style: TextStyle(fontSize: 13, color: colors.text3)),
              ],
            ),
          ),
          _HeaderIconButton(
            icon: Icons.menu_book_rounded,
            tooltip: '词典查询',
            colors: colors,
            onTap: () => Navigator.pushNamed(context, RouteNames.search),
          ),
          const SizedBox(width: 10),
          _HeaderIconButton(
            icon: Icons.sports_esports_rounded,
            tooltip: '单词机',
            colors: colors,
            onTap: () => Navigator.pushNamed(context, WordMachinePage.routeName),
          ),
        ],
      ),
    );
  }
}

/// 头部圆形入口按钮（与 MwCard 同语言：白底 + 双层细影）
class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({required this.icon, required this.tooltip, required this.colors, required this.onTap});

  final IconData icon;
  final String tooltip;
  final ThemeVars colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      triggerMode: TooltipTriggerMode.longPress,
      child: ScaleDownOnPress(
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: colors.cardBg,
            shape: BoxShape.circle,
            boxShadow: const [
              BoxShadow(color: MwShadows.hairlineShadow, blurRadius: 0.5),
              BoxShadow(color: MwShadows.liftShadow, blurRadius: 1.0, offset: Offset(0, 1)),
            ],
          ),
          child: Icon(icon, color: colors.accent, size: 22),
        ),
      ),
    );
  }
}

/// 今日进度主卡：进度环 + 目标文案 + Learn/Review 双 CTA。
///
/// 进度数据直读偏好（今日已学/每日目标，与会话队列实际限额同源）；
/// 复习到期数来自 [LearningStatisticsState]。goalSignal 变更时重读刷新。
class _TodayHeroCard extends StatelessWidget {
  const _TodayHeroCard({required this.goalSignal});

  final ValueNotifier<int> goalSignal;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final resp = context.responsive;
    return Selector<LearningStatisticsState, int>(
      selector: (_, s) => s.dueCount,
      builder: (context, dueCount, _) => ValueListenableBuilder<int>(
        valueListenable: goalSignal,
        builder: (context, _, _) {
          final goal = UserPreferences().getDailyGoal();
          final learned = AppPreferences().getTodayLearned();
          final progress = goal > 0 ? (learned / goal).clamp(0.0, 1.0) : 0.0;
          final done = goal > 0 && learned >= goal;

          return MwCard(
            padding: EdgeInsets.all(24 * resp.scale),
            child: Row(
              children: [
                _ProgressRing(
                  size: 96 * resp.scale,
                  progress: progress,
                  trackColor: skin.colors.divider,
                  progressColor: skin.colors.accent,
                  learned: learned,
                  goal: goal,
                ),
                SizedBox(width: 22 * resp.scale),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        done ? '今日目标已完成' : '还差 ${goal - learned} 个单词',
                        style: TextStyle(
                          fontSize: 19 * resp.fontScale,
                          fontWeight: FontWeight.w700,
                          height: 1.25,
                          letterSpacing: -0.3,
                          color: skin.colors.text1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '已学 $learned / $goal · 待复习 $dueCount',
                        style: TextStyle(fontSize: 13 * resp.fontScale, color: skin.colors.text3),
                      ),
                      SizedBox(height: 16 * resp.scale),
                      Row(
                        children: [
                          Expanded(
                            child: _HeroCta(
                              label: done ? '再加一组' : '开始学习',
                              icon: done ? Icons.add_rounded : Icons.play_arrow_rounded,
                              backgroundColor: skin.colors.accent,
                              foregroundColor: Colors.white,
                              onTap: () => _startLearning(context),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _HeroCta(
                              label: '复习 $dueCount',
                              icon: Icons.history_rounded,
                              backgroundColor: skin.colors.accent.withValues(alpha: 0.10),
                              foregroundColor: skin.colors.accent,
                              onTap: () => showReviewDialog(context),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// 直接开始背单词（加载第一本书并跳转到学习页），行为与旧版一致。
  Future<void> _startLearning(BuildContext context) async {
    final state = context.read<LearningSessionState>();
    if (state.queue.isNotEmpty) {
      if (context.mounted) {
        Navigator.pushNamed(context, LearnPage.routeName);
      }
      return;
    }
    final books = await context.read<BookCatalogReader>().listBooks();
    if (books.isEmpty) {
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
    await state.loadBook(books.first, shuffle: true);
    if (context.mounted) {
      Navigator.pushNamed(context, LearnPage.routeName);
    }
  }
}

/// 环形进度（track + 圆头弧线），中心显示 已学/目标。
class _ProgressRing extends StatelessWidget {
  const _ProgressRing({
    required this.size,
    required this.progress,
    required this.trackColor,
    required this.progressColor,
    required this.learned,
    required this.goal,
  });

  final double size;
  final double progress;
  final Color trackColor;
  final Color progressColor;
  final int learned;
  final int goal;

  @override
  Widget build(BuildContext context) {
    final resp = context.responsive;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: progress),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (context, animated, _) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _RingPainter(trackColor: trackColor, progressColor: progressColor, progress: animated),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$learned',
                  style: TextStyle(
                    fontSize: 24 * resp.fontScale,
                    fontWeight: FontWeight.w700,
                    height: 1.1,
                    color: progressColor,
                  ),
                ),
                Text(
                  '/ $goal',
                  style: TextStyle(fontSize: 12 * resp.fontScale, height: 1.3, color: context.skin.colors.text3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({required this.trackColor, required this.progressColor, required this.progress});

  final Color trackColor;
  final Color progressColor;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 8.0;
    final inset = stroke / 2 + 1;
    final arcRect = Rect.fromLTWH(inset, inset, size.width - inset * 2, size.height - inset * 2);

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = trackColor;
    canvas.drawArc(arcRect, 0, 2 * math.pi, false, track);

    if (progress > 0) {
      final arc = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = progressColor;
      canvas.drawArc(arcRect, -math.pi / 2, 2 * math.pi * progress, false, arc);
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.progress != progress || old.trackColor != trackColor || old.progressColor != progressColor;
}

/// 主卡胶囊 CTA（图标 + 文字，StadiumBorder，按压缩放）
class _HeroCta extends StatelessWidget {
  const _HeroCta({
    required this.label,
    required this.icon,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color backgroundColor;
  final Color foregroundColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ScaleDownOnPress(
      onTap: onTap,
      child: Container(
        height: 46,
        alignment: Alignment.center,
        decoration: ShapeDecoration(color: backgroundColor, shape: const StadiumBorder()),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: foregroundColor),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.15,
                  color: foregroundColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 签到条：火焰图标 + 连签天数/召唤，点击打开弹性签到日历。
class _CheckInStrip extends StatefulWidget {
  const _CheckInStrip();

  @override
  State<_CheckInStrip> createState() => _CheckInStripState();
}

class _CheckInStripState extends State<_CheckInStrip> {
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
    final skin = context.skin;
    final checked = _checkedToday;
    // 加载中：占位避免布局跳动
    if (checked == null) return const SizedBox(height: 56);

    return ScaleDownOnPress(
      onTap: _openSheet,
      child: MwCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(color: skin.colors.accent.withValues(alpha: 0.10), shape: BoxShape.circle),
              child: Icon(
                Icons.local_fire_department_rounded,
                size: 18,
                color: checked ? skin.colors.accent : skin.colors.text3,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                checked ? '已连续签到 $_streakDays 天，保持下去' : '今天还没签到，别断啦',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: skin.colors.text1),
              ),
            ),
            if (!checked)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: ShapeDecoration(color: skin.colors.accent, shape: const StadiumBorder()),
                child: const Text('签到 +10', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
              )
            else
              Icon(Icons.chevron_right, size: 20, color: skin.colors.text3),
          ],
        ),
      ),
    );
  }
}

/// 当前词书条：显示在学词书，点击进入词书选择。
class _BookStrip extends StatelessWidget {
  const _BookStrip();

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Selector<LearningStatisticsState, String?>(
      selector: (_, s) => s.currentBook?.name,
      builder: (context, bookName, _) => ScaleDownOnPress(
        onTap: () => Navigator.pushNamed(context, RouteNames.libSelect),
        child: MwCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(color: skin.colors.accent.withValues(alpha: 0.10), shape: BoxShape.circle),
                child: Icon(Icons.collections_bookmark_outlined, size: 18, color: skin.colors.accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('当前词书', style: TextStyle(fontSize: 11, color: skin.colors.text3)),
                    const SizedBox(height: 1),
                    Text(
                      bookName ?? '还没有选择词书',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: skin.colors.text1),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: ShapeDecoration(
                  shape: StadiumBorder(side: BorderSide(color: skin.colors.accent.withValues(alpha: 0.4))),
                ),
                child: Text('切换', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: skin.colors.accent)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 每日目标快捷档位：预设 chip + 自定义（打开原有滚轮选择弹层）。
class _GoalChips extends StatefulWidget {
  const _GoalChips({required this.goalSignal});

  final ValueNotifier<int> goalSignal;

  @override
  State<_GoalChips> createState() => _GoalChipsState();
}

class _GoalChipsState extends State<_GoalChips> {
  static const _presets = [10, 20, 50, 100];

  Future<void> _select(int value) async {
    await UserPreferences().setDailyGoal(value);
    if (!mounted) return;
    setState(() {});
    widget.goalSignal.value++;
  }

  Future<void> _openCustomPicker() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(sheetCtx).viewInsets.bottom + 24),
          child: const DailyGoalPicker(),
        ),
      ),
    );
    if (!mounted) return;
    setState(() {});
    widget.goalSignal.value++;
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final current = UserPreferences().getDailyGoal();
    return Row(
      children: [
        Text('每日目标', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: skin.colors.text3)),
        const SizedBox(width: 12),
        Expanded(
          child: Row(
            children: [
              for (final value in _presets) ...[
                _goalChip(value, current == value, skin),
                const SizedBox(width: 8),
              ],
              // 当前值不在预设档位时，展示当前值 chip（选中态）
              if (!_presets.contains(current)) ...[_goalChip(current, true, skin), const SizedBox(width: 8)],
              _customChip(skin),
            ],
          ),
        ),
      ],
    );
  }

  Widget _goalChip(int value, bool selected, SkinSystem skin) {
    return ScaleDownOnPress(
      onTap: () => _select(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: ShapeDecoration(
          color: selected ? skin.colors.accent : skin.colors.cardBg,
          shape: StadiumBorder(
            side: BorderSide(color: selected ? skin.colors.accent : skin.colors.divider),
          ),
        ),
        child: Text(
          '$value',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : skin.colors.text2,
          ),
        ),
      ),
    );
  }

  Widget _customChip(SkinSystem skin) {
    return ScaleDownOnPress(
      onTap: _openCustomPicker,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: ShapeDecoration(
          color: Colors.transparent,
          shape: StadiumBorder(side: BorderSide(color: skin.colors.divider)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.tune, size: 14, color: skin.colors.text2),
            const SizedBox(width: 4),
            Text('自定义', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: skin.colors.text2)),
          ],
        ),
      ),
    );
  }
}

/// 每日一句脚注：按日期轮换，单行优雅呈现（衬线斜体）。
class _QuoteFooter extends StatelessWidget {
  const _QuoteFooter();

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final resp = context.responsive;
    final items = TestimonialData.defaults;
    final item = items[DateTime.now().day % items.length];
    final author = item.author ?? item.source ?? '';
    return Padding(
      padding: EdgeInsets.fromLTRB(resp.pageMargin + 8, 0, resp.pageMargin + 8, 12),
      child: Text(
        '「 ${item.text} 」${author.isEmpty ? '' : ' — $author'}',
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontFamily: 'Charter',
          fontSize: 13,
          fontStyle: FontStyle.italic,
          height: 1.6,
          color: skin.colors.text3,
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
