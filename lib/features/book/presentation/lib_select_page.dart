// 由 Claude 团队生成 | Monster Word App

// 课程 tab / 词书选择页（双语境）：
// 结构：顶部导航（tab「课程」/ push「选择词书」）+ 分类签 + 在学词书卡 + 词书网格 + 底部工具栏
// v2.8.3 重设计：废除星球横幅/弯曲画廊/重复命名，收敛为「在学卡 + 统一网格」单滚动区
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:word_app/models/book.dart';
import 'package:word_app/widgets/app_dock.dart';
import 'package:word_app/widgets/common/mw_empty_state.dart';
import 'package:word_app/widgets/common/mw_skeleton.dart';
import 'package:word_app/widgets/morphing_tabs.dart';
import 'package:word_app/widgets/mw_section_header.dart';
import 'package:word_app/features/learning/application/learning_session_reader.dart';
import 'package:word_app/features/learning/application/learning_session_starter.dart';
import 'package:word_app/app/router/nav_utils.dart';
import 'package:word_app/app/router/route_names.dart';
import 'package:word_app/core/presentation/responsive.dart';
import 'package:word_app/theme/skin_system.dart';
import 'package:word_app/tokens/design_tokens.dart';
import 'package:word_app/core/infrastructure/app_preferences.dart';
import 'package:word_app/features/book/application/book_catalog_reader.dart';
import 'package:word_app/features/book/application/book_word_list_reader.dart';
import 'package:word_app/features/book/domain/book_groups.dart';
import 'package:word_app/features/book/presentation/book_state.dart';
import 'package:word_app/features/book/presentation/books_page.dart';
import 'package:word_app/features/book/presentation/extensive_model_select_page.dart';
import 'package:word_app/features/book/presentation/word_export_page.dart';
import 'package:word_app/tokens/motion_tokens.dart';
import 'package:word_app/widgets/daily_goal_picker.dart';
import 'package:word_app/widgets/scale_down_on_press.dart';

class LibSelectPage extends StatefulWidget {
  const LibSelectPage({super.key});

  static const routeName = '/lib_select';

  @override
  State<LibSelectPage> createState() => _LibSelectPageState();
}

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

class _LibSelectPageState extends State<LibSelectPage> {
  late Future<List<Book>> _booksFuture;
  List<Book> _allBooks = [];
  int _tabIndex = 0; // 当前分组下标（0 = 全部）
  bool _selecting = false; // 选书防连点

  @override
  void initState() {
    super.initState();
    _booksFuture = _load();
  }

  Future<List<Book>> _load() async {
    final books = await context.read<BookCatalogReader>().listBooks();
    _allBooks = books;
    if (mounted) setState(() {});
    return books;
  }

  /// 当前词库中非空的分组（有序）
  List<int> get _visibleGroups {
    final present = _allBooks.map((b) => bookGroupOf(b.code)).toSet();
    return List<int>.generate(
      kBookGroupNames.length,
      (i) => i,
    ).where((g) => g == BookGroup.all || present.contains(g)).toList();
  }

  /// 按分组过滤词书
  List<Book> _filterByTab(List<Book> books, int tab) {
    if (tab == BookGroup.all) return books;
    return books.where((b) => bookGroupOf(b.code) == tab).toList();
  }

  // ===== 顶部导航：tab 语境标题「课程」无返回；被「切换」push 时「选择词书」+ 返回 =====
  Widget _buildTopNav(ThemeVars colors) {
    final canPop = Navigator.of(context).canPop();
    final title = canPop ? '选择词书' : '课程';
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      color: colors.cardBg,
      child: Row(
        children: [
          if (canPop)
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, size: 20),
              color: colors.text1,
              onPressed: () => NavUtils.safePop(context),
            )
          else
            const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: colors.text1),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.search, size: 22),
            color: colors.text1,
            onPressed: () => Navigator.pushNamed(context, RouteNames.search),
          ),
          IconButton(
            icon: const Icon(Icons.more_horiz, size: 22),
            color: colors.text1,
            onPressed: () => _showMoreMenu(context, colors),
          ),
        ],
      ),
    );
  }

  // ===== 分类选项卡 =====
  Widget _buildGroupTabs(ThemeVars colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: SimpleMorphingTabs(
        labels: _visibleGroups.map((g) => kBookGroupNames[g]).toList(),
        initialIndex: 0,
        height: 36,
        borderRadius: 14,
        padding: const EdgeInsets.all(3),
        activeColor: AppColors.white100,
        inactiveColor: colors.text3,
        indicatorColor: colors.accent,
        backgroundColor: colors.cardBgAlt,
        onChanged: (i) => setState(() => _tabIndex = _visibleGroups[i]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.skin.colors;
    final resp = context.responsive;
    final contentMaxWidth = resp.isDesktop ? 1200.0 : double.infinity;
    return Scaffold(
      backgroundColor: colors.cardBg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: contentMaxWidth),
            child: Column(
              children: [
                _buildTopNav(colors),
                Container(height: 1, color: colors.divider),
                _buildGroupTabs(colors),
                Container(height: 1, color: colors.divider),
                Expanded(
                  child: FutureBuilder<List<Book>>(
                    future: _booksFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState != ConnectionState.done) {
                        return const MwSkeletonGrid(count: 6);
                      }
                      if (snapshot.hasError) {
                        return const MwEmptyState(kind: MwEmptyKind.error, title: '词书加载失败', subtitle: '检查网络后重试，或稍后再来');
                      }
                      final books = _filterByTab(_allBooks, _tabIndex);
                      if (books.isEmpty) {
                        return MwEmptyState(
                          kind: MwEmptyKind.empty,
                          title: '暂无词书',
                          subtitle: '当前分类下没有词书，请切换分类或刷新',
                          actionLabel: '刷新',
                          onAction: () => setState(() => _booksFuture = _load()),
                        );
                      }
                      return _buildBookScroll(context, colors, books);
                    },
                  ),
                ),
                _buildBottomToolbar(colors),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ===== 内容滚动区：在学卡 + 分组网格 =====
  Widget _buildBookScroll(BuildContext context, ThemeVars colors, List<Book> books) {
    final resp = context.responsive;
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _CurrentBookHero(onOpen: _openCurrentBookWords)),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
            child: MwSectionHeader(title: '全部词书 · ${books.length} 本'),
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, FloatingDock.clearance(context)),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: resp.bookGridColumns,
              mainAxisExtent: 196,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            delegate: SliverChildBuilderDelegate(
              childCount: books.length,
              // select 必须绑定网格 item 内部的 context（provider 禁止在
              // SliverList/Grid 的 itemBuilder 直接 select，会整网格重建）。
              (context, index) {
                final book = books[index];
                return Builder(
                  builder: (cardContext) {
                    final isLearning = cardContext.select<LearningSessionReader, bool>(
                      (s) => s.currentBook?.id == book.id,
                    );
                    return _BookCard(
                      book: book,
                      isLearning: isLearning,
                      onSelect: () => _selectBook(book),
                      onViewWords: () => _openBookWords(context, book),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  /// 打开当前在学词书的单词页。
  void _openCurrentBookWords() {
    final book = context.read<LearningSessionReader>().currentBook;
    if (book == null) return;
    _openBookWords(context, book);
  }

  void _openBookWords(BuildContext context, Book book) {
    Navigator.pushNamed(context, RouteNames.bookWords, arguments: {'bookId': book.id, 'bookName': book.name});
  }

  /// 点卡片 = 选中该词书并生效：填充学习队列 + 同步词书聚合状态 + 持久化；
  /// 首次选书弹每日目标设置；push 语境下选中后返回上一页。
  Future<void> _selectBook(Book book) async {
    if (_selecting) return; // 防连点/并发竞态（体验审计 A-3）
    setState(() => _selecting = true);
    try {
      await context.read<LearningSessionStarter>().startBookSession(book, limit: 50);
      if (mounted) {
        await context.read<BookState>().selectAndLoad(book);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('已选中《${book.name}》')));
        final prefs = AppPreferences();
        final firstTime = !prefs.getBool(AppPreferences.dailyGoalPromptShownKey, defaultValue: false);
        if (!firstTime) {
          if (mounted && Navigator.of(context).canPop()) Navigator.pop(context);
          return;
        }
        await prefs.setBool(AppPreferences.dailyGoalPromptShownKey, true);
        if (!mounted) return;
        final nav = Navigator.of(context);
        await showModalBottomSheet<void>(
          context: context,
          builder: (sheetCtx) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('设置每日学习目标', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  const DailyGoalPicker(),
                  const SizedBox(height: 8),
                  FilledButton(onPressed: () => Navigator.pop(sheetCtx), child: const Text('完成，回首页开始学习')),
                ],
              ),
            ),
          ),
        );
        if (nav.canPop()) nav.pop(); // 选中完成，返回首页
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('加载词书失败: $e')));
      }
    } finally {
      if (mounted) setState(() => _selecting = false);
    }
  }

  // ===== 底部工具栏 =====
  // 预留悬浮 Dock 高度：否则工具栏与主壳悬浮 Dock 重叠（v2.7.22 用户实测；
  // v2.8.3 课程页重写时回归，必须保留 FloatingDock.clearance 底部预留）。
  Widget _buildBottomToolbar(ThemeVars colors) {
    return Padding(
      padding: EdgeInsets.only(bottom: FloatingDock.clearance(context)),
      child: Container(
        decoration: BoxDecoration(
          color: colors.cardBg,
          border: Border(top: BorderSide(color: colors.divider)),
        ),
        child: SafeArea(
          top: false,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _BottomToolItem(icon: Icons.dashboard_outlined, label: '词书主页', onTap: () => _openBookDashboard(context)),
              _BottomToolItem(icon: Icons.style, label: '沉浸刷词', onTap: () => _onToolTap(context, 'immersive')),
              _BottomToolItem(icon: Icons.headphones, label: '随身听', onTap: () => _onToolTap(context, 'listen')),
              _BottomToolItem(icon: Icons.edit_note, label: '听写', onTap: () => _onToolTap(context, 'dictation')),
              _BottomToolItem(icon: Icons.spellcheck, label: '随手拼', onTap: () => _onToolTap(context, 'spell')),
              _BottomToolItem(
                icon: Icons.file_download_outlined,
                label: '导出',
                onTap: () => _onToolTap(context, 'export'),
              ),
              _BottomToolItem(icon: Icons.bolt, label: '考试速刷', onTap: () => _onToolTap(context, 'quickReview')),
            ],
          ),
        ),
      ),
    );
  }

  /// 打开词书主页（BookDashboardPage）。
  void _openBookDashboard(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const BookDashboardPage()));
  }

  void _onToolTap(BuildContext context, String tool) {
    final book = context.read<LearningSessionReader>().currentBook;

    if (book == null && tool != 'immersive' && tool != 'quickReview') {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请先选择一本词书')));
      return;
    }

    switch (tool) {
      case 'immersive':
        Navigator.pushNamed(context, RouteNames.immersiveSwipe);
        break;
      case 'quickReview':
        Navigator.pushNamed(context, RouteNames.examQuickReview);
        break;
      case 'listen':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ExtensiveModelSelectPage(bookId: book!.id.toString(), bookName: book.name),
          ),
        );
        break;
      case 'dictation':
        _startDictation(context, book!);
        break;
      case 'spell':
        _startQuickSpell(context, book!);
        break;
      case 'export':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => WordExportPage(bookId: book!.id, bookName: book.name),
          ),
        );
        break;
      default:
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$tool 功能开发中...')));
    }
  }

  Future<void> _startDictation(BuildContext context, Book book) async {
    final words = await context.read<BookWordListReader>().loadWords(book.id);
    if (!context.mounted) return;
    if (words.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('该词书暂无单词')));
      return;
    }
    await context.read<LearningSessionStarter>().startWordSession(words, book: book);
    if (!context.mounted) return;
    Navigator.pushNamed(context, RouteNames.dictationSession);
  }

  Future<void> _startQuickSpell(BuildContext context, Book book) async {
    final words = await context.read<BookWordListReader>().loadWords(book.id);
    if (!context.mounted) return;
    if (words.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('该词书暂无单词')));
      return;
    }
    await context.read<LearningSessionStarter>().startWordSession(words, book: book);
    if (!context.mounted) return;
    Navigator.pushNamed(context, RouteNames.quickSpell);
  }

  void _showMoreMenu(BuildContext context, ThemeVars colors) {
    showModalBottomSheet(
      context: context,
      backgroundColor: colors.cardBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.sort, color: colors.text1),
              title: Text('排序', style: TextStyle(color: colors.text1)),
              onTap: () => Navigator.pop(ctx),
            ),
            ListTile(
              leading: Icon(Icons.filter_list, color: colors.text1),
              title: Text('筛选', style: TextStyle(color: colors.text1)),
              onTap: () => Navigator.pop(ctx),
            ),
            ListTile(
              leading: Icon(Icons.refresh, color: colors.text1),
              title: Text('刷新词书', style: TextStyle(color: colors.text1)),
              onTap: () {
                Navigator.pop(ctx);
                setState(() => _booksFuture = _load());
              },
            ),
          ],
        ),
      ),
    );
  }
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
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: skin.accent.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: skin.accent.withValues(alpha: 0.18)),
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
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: ScaleTapCard(
        onTap: onOpen,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: skin.cardBg,
            borderRadius: BorderRadius.circular(16),
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
                  borderRadius: BorderRadius.circular(12),
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
                        fontSize: 18,
                        fontWeight: FontWeight.w400,
                        color: skin.text1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
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
          // 封面
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: coverColor, borderRadius: BorderRadius.circular(14)),
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
                          style: MwTypography.micro.copyWith(color: AppColors.white100.withValues(alpha: 0.75)),
                        ),
                      ],
                    ),
                  ),
                ),
                // 浏览单词入口
                Positioned(
                  top: 4,
                  right: 4,
                  child: InkWell(
                    onTap: onViewWords,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(Icons.list_alt_rounded, size: 17, color: AppColors.white100.withValues(alpha: 0.85)),
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
                        color: AppColors.white100.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '在学',
                        style: MwTypography.micro.copyWith(color: coverColor, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
              ],
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
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22, color: colors.text1),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 11, color: colors.text1)),
          ],
        ),
      ),
    );
  }
}
