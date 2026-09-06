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
                            foregroundColor: AppColors.white100,
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
