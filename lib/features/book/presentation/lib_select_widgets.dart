part of 'lib_select_page.dart';

// lib_select_page 的展示组件与纯函数（I58 拆分：主文件只保留页面状态与编排）。
// 经 part 共享 library：可访问主文件的私有类型与 import。

/// 按 book code hash 稳定分配三档封面色——基于当前皮肤 accent 的
/// HSL 明度变体（本色/提亮/加深），跟随主题适配。
Color coverColorFor(BuildContext context, String code) {
  final accent = context.skin.colors.accent;
  final hsl = HSLColor.fromColor(accent);
  final index = code.hashCode.abs() % 3;
  final isDark = context.skin.currentTheme.uiBrightness == Brightness.dark;
  final lightnessDelta = isDark ? [0.06, 0.14, -0.02] : [0.0, 0.10, -0.12];
  return hsl.withLightness((hsl.lightness + lightnessDelta[index]).clamp(0.15, 0.85)).toColor();
}

/// 词书展示名：数据层 name 缺失时回退为原始 code（如 CET4DGCH），观感差。
/// 这里只解码有把握的命名规则（拼音首字母后缀 + 已知词表缩写），
/// 无法识别时原样返回，不臆造名称。
String friendlyBookName(String raw) {
  final name = raw.replaceAll('MonsterWord_', '');
  // 已含中文即视为可读名
  if (name.contains(RegExp(r'[\u4e00-\u9fff]'))) return name;

  // 已知词表缩写（官方/通用命名，把握高）
  const exact = {
    'AWL': '学术词汇 AWL',
    'BARRONSAT': '巴朗 SAT 词汇',
    'BECHIGHER': 'BEC 高级',
    'BECVAN': 'BEC 中级',
    'BECPRE': 'BEC 初级',
  };
  final exactName = exact[name];
  if (exactName != null) return exactName;

  // 拼音首字母后缀：DGCH=大纲词汇 / HXCH=核心词汇（如 CET4DGCH → 四级大纲词汇）
  final suffix = RegExp(r'(DGCH|HXCH)$').firstMatch(name);
  if (suffix != null) {
    final stem = name.substring(0, name.length - 4);
    final category = _categoryNameOf(stem);
    if (category != null) {
      return '$category${suffix.group(1) == 'DGCH' ? '大纲词汇' : '核心词汇'}';
    }
  }
  return name;
}

String? _categoryNameOf(String code) {
  if (code.startsWith('CET4')) return '四级';
  if (code.startsWith('CET6')) return '六级';
  if (code.startsWith('GK')) return '高考';
  if (code.startsWith('KY')) return '考研';
  if (code.startsWith('IELTS')) return '雅思';
  if (code.startsWith('TOEFL') || code.startsWith('GDTOEFL')) return '托福';
  return null;
}

/// 在学词书卡：当前词书 + 会话进度；点击进入词书单词页。
class _CurrentBookHero extends StatelessWidget {
  const _CurrentBookHero({required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin.colors;
    final book = context.select<LearningSessionReader, Book?>((s) => s.currentBook);
    final total = context.select<LearningSessionReader, int>((s) => s.total);
    final learned = context.select<LearningSessionReader, int>((s) => s.learnedNum);

    // 尚未在学：引导卡
    if (book == null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.xxs),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: skin.accent.withValues(alpha: AppAlphas.o06),
            borderRadius: BorderRadius.circular(context.design.radius.control),
            border: Border.all(color: skin.accent.withValues(alpha: AppAlphas.o18)),
          ),
          child: Row(
            children: [
              Icon(Icons.auto_stories_rounded, color: skin.accent, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text('还没有在学词书，从下方选一本开始吧', style: MwTypography.bodySm.copyWith(color: skin.text2)),
              ),
            ],
          ),
        ),
      );
    }

    final progress = total > 0 ? (learned / total).clamp(0.0, 1.0) : 0.0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.xxs),
      child: ScaleTapCard(
        onTap: onOpen,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: skin.cardBg,
            borderRadius: BorderRadius.circular(context.design.radius.control),
            border: Border.all(color: skin.divider),
          ),
          child: Row(
            children: [
              // 封面
              Container(
                width: 56,
                height: 72,
                decoration: BoxDecoration(
                  color: coverColorFor(context, book.code),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                alignment: Alignment.center,
                child: Icon(Icons.menu_book_rounded, color: AppColors.white100, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '正在学习',
                      style: MwTypography.micro.copyWith(color: skin.accent, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      friendlyBookName(book.name),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Charter',
                        fontSize: AppFontSizes.heading5,
                        fontWeight: FontWeight.w400,
                        color: skin.text1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.xs),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(end: progress),
                        duration: MotionDurations.count,
                        curve: Curves.easeOutCubic,
                        builder: (context, value, _) => LinearProgressIndicator(
                          value: value,
                          minHeight: 5,
                          backgroundColor: skin.divider,
                          valueColor: AlwaysStoppedAnimation(skin.accent),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text('已学 $learned / $total 词', style: MwTypography.micro.copyWith(color: skin.text3)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, size: 20, color: skin.text3),
            ],
          ),
        ),
      ),
    );
  }
}

/// 词书网格卡：封面（名称/词数内嵌）+ 分类行 + 在学徽标。
/// 点卡片 = 选中并开始学习；右上角按钮 = 浏览单词列表。
class _BookCard extends StatelessWidget {
  const _BookCard({required this.book, required this.isLearning, required this.onSelect, required this.onViewWords});

  final Book book;
  final bool isLearning;
  final VoidCallback onSelect;
  final VoidCallback onViewWords;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin.colors;
    final coverColor = coverColorFor(context, book.code);
    final category = kBookGroupNames[bookGroupOf(book.code)];

    return ScaleDownOnPress(
      onTap: onSelect,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 封面（桌面鼠标悬浮：朝指针微倾 + 抬升 + 眩光，见 FloatingTiltCard）
          Expanded(
            child: FloatingTiltCard(
              borderRadius: BorderRadius.circular(context.design.radius.md),
              cursor: SystemMouseCursors.click,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: coverColor,
                        borderRadius: BorderRadius.circular(context.design.radius.md),
                      ),
                      foregroundDecoration: _coverSheen(context),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.menu_book_rounded, color: AppColors.white100, size: 22),
                          const SizedBox(height: 6),
                          Text(
                            friendlyBookName(book.name),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: MwTypography.bodySm.copyWith(
                              color: AppColors.white100,
                              fontWeight: FontWeight.w700,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${book.wordCount} 词',
                            style: MwTypography.micro.copyWith(
                              color: AppColors.white100.withValues(alpha: AppAlphas.o75),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  ..._coverOverlays(coverColor),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          // 分类行
          SizedBox(
            height: 16,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    category,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: MwTypography.micro.copyWith(color: skin.text3),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 静置亦有体积感：左上高光 → 右下暗角的微渐变（卡片廊光感语言）。
  Decoration _coverSheen(BuildContext context) {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(context.design.radius.md),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          AppColors.white100.withValues(alpha: AppAlphas.o10),
          AppColors.white100.withValues(alpha: AppAlphas.o0),
          AppColors.black12.withValues(alpha: AppAlphas.o10),
        ],
        stops: const [0, 0.5, 1],
      ),
    );
  }

  /// 封面覆盖层：右上浏览单词入口 + 左上「在学」徽标。
  List<Widget> _coverOverlays(Color coverColor) {
    return [
      Positioned(
        top: 4,
        right: 4,
        child: InkWell(
          onTap: onViewWords,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xxs),
            child: Icon(Icons.list_alt_rounded, size: 17, color: AppColors.white100.withValues(alpha: AppAlphas.o85)),
          ),
        ),
      ),
      if (isLearning)
        Positioned(
          left: 6,
          top: 6,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.white100.withValues(alpha: AppAlphas.o92),
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Text(
              '在学',
              style: MwTypography.micro.copyWith(color: coverColor, fontWeight: FontWeight.w700),
            ),
          ),
        ),
    ];
  }
}

/// 底部工具栏项（图标 + 文字）
class _BottomToolItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _BottomToolItem({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.skin.colors;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs, horizontal: AppSpacing.sm),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22, color: colors.text1),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(fontSize: AppFontSizes.micro, color: colors.text1),
            ),
          ],
        ),
      ),
    );
  }
}

/// 卡片按压容器（缩放反馈 + 圆角裁切），供网格卡复用。
class ScaleTapCard extends StatelessWidget {
  const ScaleTapCard({super.key, required this.onTap, required this.child});

  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(onTap: onTap, behavior: HitTestBehavior.opaque, child: child);
  }
}
