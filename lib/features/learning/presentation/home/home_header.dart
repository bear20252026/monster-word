part of '../home_screen.dart';

/// 问候头部：时段问候 + 日期；右侧词典/单词机入口。
///
/// 2026-10-17：怪兽**已从本文件移出**，改为全 app 唯一的浮层
/// （`lib/widgets/monster_presence.dart`，挂在 MaterialApp.builder 上）。
/// 原因：怪兽是「一只宠物」，不是每个页面各画一张贴图 —— 页面只管报事件。
class _Header extends StatefulWidget {
  const _Header({required this.skin});

  final SkinSystem skin;

  @override
  State<_Header> createState() => _HeaderState();
}

class _HeaderState extends State<_Header> {
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
    final colors = widget.skin.colors;
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
                    fontSize: AppFontSizes.title * resp.fontScale,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                    letterSpacing: -0.5,
                    color: colors.text1,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Text(_dateLabel(), style: MwTypography.caption.copyWith(color: colors.text3)),
                    // M3/D3：等级只在首页与结算页出现（不进商店）。
                    const _XpLevelChip(),
                  ],
                ),
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

/// 首页等级角标（M3/D3）：只显示 Lv.N，不显示经验条，不进入商店/兑换。
///
/// 读不到 XpStore（最小装配/单测）时静默不占位。
class _XpLevelChip extends StatelessWidget {
  const _XpLevelChip();

  @override
  Widget build(BuildContext context) {
    final store = context.read<XpStore?>();
    if (store == null) return const SizedBox.shrink();
    final colors = context.skin.colors;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        if (!store.loaded) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(left: AppSpacing.xs),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.auto_awesome_rounded, size: 12, color: colors.accent),
              const SizedBox(width: 3),
              Text(
                'Lv.${store.level}',
                style: MwTypography.caption.copyWith(fontWeight: FontWeight.w700, color: colors.accent),
              ),
            ],
          ),
        );
      },
    );
  }
}

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
          fontSize: AppFontSizes.caption,
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
