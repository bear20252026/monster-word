part of '../home_screen.dart';

/// 问候头部：左侧怪兽伙伴（呼吸 bob + 点击咕噜进我的空间）+ 时段问候 + 日期；右侧词典/单词机入口。
class _Header extends StatefulWidget {
  const _Header({required this.skin});

  final SkinSystem skin;

  @override
  State<_Header> createState() => _HeaderState();
}

class _HeaderState extends State<_Header> with TickerProviderStateMixin {
  // 怪兽呼吸 bob 相位（2.8s 一循环，写法参照 profile_screen _idleCtrl：repeat + sin 相位；
  // 档位复用 MotionDurations.splash —— 唯一的 2800ms 档，棘轮口径内）
  late final AnimationController _bobCtrl = AnimationController(vsync: this, duration: MotionDurations.splash);
  // 点击问候：张嘴 0→0.3 的 0.3s 过渡
  late final AnimationController _mouthCtrl = AnimationController(vsync: this, duration: MotionDurations.slow);
  late final Animation<double> _mouth = CurvedAnimation(parent: _mouthCtrl, curve: Curves.easeInOut);
  bool _gurgleVisible = false;

  bool get _reduceMotion => WidgetsBinding.instance.platformDispatcher.accessibilityFeatures.disableAnimations;

  @override
  void initState() {
    super.initState();
    if (!_reduceMotion) _bobCtrl.repeat();
  }

  @override
  void dispose() {
    _bobCtrl.dispose();
    _mouthCtrl.dispose();
    super.dispose();
  }

  /// 点怪兽：张嘴冒「咕噜~」，留出可感知节拍后进入「我的空间」。
  Future<void> _greet() async {
    _mouthCtrl.forward(from: 0);
    setState(() => _gurgleVisible = true);
    await Future<void>.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    Navigator.pushNamed(context, RouteNames.mySpace);
    unawaited(_settleGurgle());
  }

  /// 跳转后首页仍在路由栈下：气泡淡出、嘴闭合，状态收敛。
  Future<void> _settleGurgle() async {
    await Future<void>.delayed(const Duration(milliseconds: 1600));
    if (!mounted) return;
    setState(() => _gurgleVisible = false);
    _mouthCtrl.reverse();
  }

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
          _monsterGreeting(colors),
          const SizedBox(width: 10),
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

  /// 怪兽伙伴：2.8s 呼吸 bob；点击张嘴 0.3s 并冒「咕噜~」气泡。
  Widget _monsterGreeting(ThemeVars colors) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _greet,
      child: AnimatedBuilder(
        animation: _bobCtrl,
        builder: (context, child) {
          // reduce-motion 时静止（不 repeat，不位移）
          if (_reduceMotion) return child!;
          return Transform.translate(offset: Offset(0, 2 * math.sin(2 * math.pi * _bobCtrl.value)), child: child);
        },
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            AnimatedBuilder(
              animation: _mouth,
              builder: (context, _) => MonsterIcon(size: 32, mouthOpen: 0.3 * _mouth.value),
            ),
            // 「咕噜~」气泡：悬在怪兽头顶右上，默认隐藏
            Positioned(
              top: -16,
              left: 20,
              child: AnimatedOpacity(
                opacity: _gurgleVisible ? 1 : 0,
                duration: const Duration(milliseconds: 180),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: ShapeDecoration(
                    color: colors.cardBg,
                    shape: StadiumBorder(side: BorderSide(color: colors.divider)),
                  ),
                  child: Text(
                    '咕噜~',
                    style: MwTypography.micro.copyWith(fontWeight: FontWeight.w600, color: colors.text2),
                  ),
                ),
              ),
            ),
          ],
        ),
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
