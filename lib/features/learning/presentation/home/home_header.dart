part of '../home_screen.dart';

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
                Text(_dateLabel(), style: MwTypography.caption.copyWith(color: colors.text3)),
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
