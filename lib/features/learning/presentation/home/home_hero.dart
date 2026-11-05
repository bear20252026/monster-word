part of '../home_screen.dart';

/// 今日进度主卡：进度环 + 目标文案 + Learn/Review 双 CTA。
///
/// 数据统一来自 [TodayProgressStore]（目标/已学/待复习单一事实源），
/// 学习会话、复习调度或改目标都会 notify → 本卡即时刷新，不再各自直读偏好。
class _TodayHeroCard extends StatelessWidget {
  const _TodayHeroCard();

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final resp = context.responsive;
    return Selector<TodayProgressStore, ({int goal, int learned, int due})>(
      selector: (_, s) => (goal: s.goal, learned: s.learned, due: s.due),
      builder: (context, p, _) {
        final goal = p.goal;
        final learned = p.learned;
        final dueCount = p.due;
        final progress = goal > 0 ? (learned / goal).clamp(0.0, 1.0) : 0.0;
        final done = goal > 0 && learned >= goal;
        // 主卡只回答一个问题：「现在点哪里」。时长与动作口径收在纯函数里，
        // 三态（未学 / 有到期 / 已达标）各只有一句下一步 + 一个主按钮。
        final step = resolveHomeNextStep(goal: goal, learned: learned, due: dueCount);

        final heroCard = MwCard(
          padding: EdgeInsets.all(24 * resp.scale),
          child: Row(
            children: [
              _ProgressRing(
                size: 96 * resp.scale,
                progress: progress,
                trackColor: skin.colors.divider,
                // 今日达标：金色环庆祝；未达标保持主题 accent
                progressColor: done ? StarGold.gold : skin.colors.accent,
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
                      step.title,
                      style: TextStyle(
                        fontSize: AppFontSizes.titleSm * resp.fontScale,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                        letterSpacing: -0.3,
                        color: skin.colors.text1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '已学 $learned / $goal · 待复习 $dueCount',
                      style: TextStyle(fontSize: AppFontSizes.caption * resp.fontScale, color: skin.colors.text3),
                    ),
                    SizedBox(height: 16 * resp.scale),
                    // 一键开始：主按钮只指一个方向（到期优先复习，其余开学）。
                    SizedBox(
                      width: double.infinity,
                      child: _HeroCta(
                        label: step.ctaLabel,
                        icon: step.primaryIsReview ? Icons.history_rounded : Icons.play_arrow_rounded,
                        backgroundColor: skin.colors.accent,
                        foregroundColor: AppColors.white100,
                        onTap: step.primaryIsReview
                            ? () => showReviewDialog(context)
                            : () => startHomeLearning(context),
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
                            foregroundColor: skin.colors.accent,
                          ),
                          child: Text(
                            step.secondaryLabel!,
                            style: TextStyle(
                              fontSize: AppFontSizes.caption * resp.fontScale,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
        // 今日达标沿触发一次金色 confetti（30 粒 StarGold.gold）
        return _DoneConfetti(done: done, child: heroCard);
      },
    );
  }
}

/// 直接开始背单词（加载第一本书并跳转到学习页），行为与旧版一致。
/// 首页主卡与路线弹层共用。
Future<void> startHomeLearning(BuildContext context) async {
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
      duration: MotionDurations.count,
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
                    fontSize: AppFontSizes.displaySm * resp.fontScale,
                    fontWeight: FontWeight.w700,
                    height: 1.1,
                    color: progressColor,
                  ),
                ),
                Text(
                  '/ $goal',
                  style: TextStyle(
                    fontSize: AppFontSizes.micro * resp.fontScale,
                    height: 1.3,
                    color: context.skin.colors.text3,
                  ),
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
                  fontSize: AppFontSizes.bodySm,
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
