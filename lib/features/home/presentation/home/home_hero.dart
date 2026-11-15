part of '../home_screen.dart';

/// 今日进度主卡：「星环仪表」玻璃面板（星夜航程）。
///
/// 2026-11-15 推倒重设计：深空画布上悬着一块玻璃仪表——发光星环居左，
/// 下一步标题与统计居右，底部一条极光渐变主按钮。进行中=极光青，
/// 达成=金色庆祝。数据统一来自 [TodayProgressStore]（单一事实源）。
class _TodayHeroCard extends StatelessWidget {
  const _TodayHeroCard();

  @override
  Widget build(BuildContext context) {
    final resp = context.responsive;
    return Selector<TodayProgressStore, ({int goal, int learned, int due})>(
      selector: (_, s) => (goal: s.goal, learned: s.learned, due: s.due),
      builder: (context, p, _) {
        final goal = p.goal;
        final learned = p.learned;
        final dueCount = p.due;
        final progress = goal > 0 ? (learned / goal).clamp(0.0, 1.0) : 0.0;
        final done = goal > 0 && learned >= goal;
        // 主卡只回答一个问题：「现在点哪里」。三态各只有一句下一步 + 一个主按钮。
        final step = resolveHomeNextStep(goal: goal, learned: learned, due: dueCount);
        // 进行中=极光青；达成=金色（测试口：progressColor 达标必须为 StarGold.gold）。
        final accent = done ? StarGold.gold : HomeNightColors.aurora;
        final hero = HomeGlassPanel(
          padding: EdgeInsets.all(22 * resp.scale),
          glow: accent,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  HomeEyebrow(label: '今日航程', color: HomeNightColors.text3),
                  const Spacer(),
                  if (done) HomeDoneBadge(color: StarGold.gold),
                ],
              ),
              SizedBox(height: 18 * resp.scale),
              _buildProgressRow(
                resp: resp,
                progress: progress,
                accent: accent,
                done: done,
                learned: learned,
                goal: goal,
                dueCount: dueCount,
                title: step.title,
              ),
              SizedBox(height: 20 * resp.scale),
              // 一键开始：主按钮只指一个方向（到期优先复习，其余开学）。
              SizedBox(
                width: double.infinity,
                child: HomeGlossyCta(
                  label: step.ctaLabel,
                  icon: step.primaryIsReview ? Icons.history_rounded : Icons.play_arrow_rounded,
                  backgroundColor: accent,
                  gradientEnd: done ? StarGold.goldLight : HomeNightColors.auroraIce,
                  foregroundColor: HomeNightColors.onAurora,
                  onTap: step.primaryIsReview ? () => showReviewDialog(context) : () => startHomeLearning(context),
                ),
              ),
              // 次入口降为文字链：有到期时留「继续学新词」，没有就只剩主按钮。
              if (step.secondaryLabel != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () => startHomeLearning(context),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 32),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      foregroundColor: HomeNightColors.text2,
                    ),
                    child: Text(
                      step.secondaryLabel!,
                      style: TextStyle(fontSize: AppFontSizes.caption * resp.fontScale, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
            ],
          ),
        );
        // 今日达标沿触发一次金色 confetti（30 粒 StarGold.gold）
        return _DoneConfetti(done: done, child: hero);
      },
    );
  }

  /// 进度行：发光星环 + 下一步标题 + 已学/待复习统计（星白文字）。
  Widget _buildProgressRow({
    required AppResponsive resp,
    required double progress,
    required Color accent,
    required bool done,
    required int learned,
    required int goal,
    required int dueCount,
    required String title,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        HomeProgressRing(
          size: 132 * resp.scale,
          progress: progress,
          trackColor: HomeNightColors.track,
          progressColor: accent,
          arcEnd: done ? StarGold.goldLight : HomeNightColors.auroraIce,
          learned: learned,
          goal: goal,
          secondaryColor: HomeNightColors.text3,
        ),
        SizedBox(width: 22 * resp.scale),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: AppFontSizes.titleSm * resp.fontScale,
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                  letterSpacing: -0.3,
                  color: HomeNightColors.text1,
                ),
              ),
              SizedBox(height: 14 * resp.scale),
              Row(
                children: [
                  HomeHeroStat(value: '$learned', label: '已学', color: HomeNightColors.text1),
                  HomeStatDivider(color: HomeNightColors.hairline),
                  HomeHeroStat(value: '$dueCount', label: '待复习', color: HomeNightColors.text1),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 直接开始背单词（加载第一本书并跳转到学习页），行为与旧版一致。
/// 首页主卡与路线弹层共用。[limit] 只对新建会话生效（热身节点传 3 词）；
/// 已有队列时直接续上，不重置用户进度。
Future<void> startHomeLearning(BuildContext context, {int? limit}) async {
  final reader = context.read<LearningSessionReader>();
  final starter = context.read<LearningSessionStarter>();
  if (reader.queue.isNotEmpty) {
    if (context.mounted) {
      Navigator.pushNamed(context, RouteNames.learn);
    }
    return;
  }
  final books = await context.read<BookCatalogReader>().listBooks();
  if (books.isEmpty) {
    if (context.mounted) {
      showMwSnackBar(
        context,
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
  if (reader.currentBook == null && context.mounted) {
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
  await starter.startBookSession(books.first, limit: limit, shuffle: true);
  if (context.mounted) {
    Navigator.pushNamed(context, RouteNames.learn);
  }
}

/// 今日达标沿触发金色 confetti：ConfettiController 字段 + didUpdateWidget 沿触发 play，
/// 惯例照 formal_review_question（跨天复位后再次达标可重放）。
class _DoneConfetti extends StatefulWidget {
  const _DoneConfetti({required this.done, required this.child});

  final bool done;
  final Widget child;

  @override
  State<_DoneConfetti> createState() => _DoneConfettiState();
}

class _DoneConfettiState extends State<_DoneConfetti> {
  final ConfettiController _confetti = ConfettiController();

  @override
  void didUpdateWidget(covariant _DoneConfetti oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 未达标 → 达标的瞬间撒一次；再次变回未达标后重新达标会再触发
    if (widget.done && !oldWidget.done) {
      _confetti.play();
    }
  }

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ConfettiOverlay(
      controller: _confetti,
      particleCount: 30,
      colors: const [StarGold.gold],
      child: widget.child,
    );
  }
}

/// 发光星环与环画笔见 home_visuals.dart 的 [HomeProgressRing] / `_RingPainter`。
/// 主卡 CTA 见 [HomeGlossyCta]。
