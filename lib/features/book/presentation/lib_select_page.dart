// 由 Claude 团队生成 | Monster Word App

// 课程 tab / 词书选择页（双语境）：
// 结构：顶部导航（tab「课程」/ push「选择词书」）+ 分类签 + 在学词书卡 + 词书网格 + 底部工具栏
// v2.8.3 重设计：废除星球横幅/弯曲画廊/重复命名，收敛为「在学卡 + 统一网格」单滚动区
import 'package:word_app/widgets/common/mw_feedback.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:word_app/models/book.dart';
import 'package:word_app/widgets/app_dock.dart';
import 'package:word_app/widgets/common/mw_empty_state.dart';
import 'package:word_app/widgets/common/mw_skeleton.dart';
import 'package:word_app/widgets/floating_tilt_card.dart';
import 'package:word_app/widgets/flow_in.dart';
import 'package:word_app/widgets/morphing_tabs.dart';
import 'package:word_app/widgets/mw_section_header.dart';
import 'package:word_app/features/learning/application/learning_session_reader.dart';
import 'package:word_app/features/learning/application/learning_session_starter.dart';
import 'package:word_app/app/router/nav_utils.dart';
import 'package:word_app/app/router/route_names.dart';
import 'package:word_app/core/presentation/responsive.dart';
import 'package:word_app/theme/skin_system.dart';
import 'package:word_app/tokens/design_tokens.dart';
import 'package:word_app/core/application/presentation_prefs.dart';
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

part 'lib_select_widgets.dart';

class LibSelectPage extends StatefulWidget {
  const LibSelectPage({super.key});

  static const routeName = RouteNames.libSelect;

  @override
  State<LibSelectPage> createState() => _LibSelectPageState();
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
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxs),
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
              style: MwTypography.bodyBold.copyWith(fontWeight: FontWeight.w600, color: colors.text1),
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
        SliverToBoxAdapter(
          child: FlowIn(index: 0, child: _CurrentBookHero(onOpen: _openCurrentBookWords)),
        ),
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
                    // 有序流动入场：首屏三行走完整对角波次；滚动懒加载的行只带
                    // 本列相位，新入列卡片近乎立即入场，不排队等长延迟。
                    final firstWave = resp.bookGridColumns * 3;
                    final waveIndex = index < firstWave ? index : index % resp.bookGridColumns;
                    return FlowIn(
                      key: ValueKey('book-flow-$_tabIndex-$index'),
                      index: waveIndex,
                      child: _BookCard(
                        book: book,
                        isLearning: isLearning,
                        onSelect: () => _selectBook(book),
                        onViewWords: () => _openBookWords(context, book),
                      ),
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
      await context.read<LearningSessionStarter>().startBookSession(
        book,
        limit: context.read<PresentationPrefs>().dailyGoal,
      );
      if (mounted) {
        await context.read<BookState>().selectAndLoad(book);
      }
      if (mounted) {
        showMwSnackBar(context, SnackBar(content: Text('已选中《${book.name}》')));
        final prefs = context.read<PresentationPrefs>();
        final firstTime = !prefs.dailyGoalPromptShown;
        if (!firstTime) {
          if (mounted && Navigator.of(context).canPop()) Navigator.pop(context);
          return;
        }
        await prefs.markDailyGoalPromptShown();
        if (!mounted) return;
        final nav = Navigator.of(context);
        await showModalBottomSheet<void>(
          context: context,
          builder: (sheetCtx) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '设置每日学习目标',
                    style: TextStyle(fontSize: AppFontSizes.bodyMd, fontWeight: FontWeight.w600),
                  ),
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
        showMwSnackBar(context, SnackBar(content: Text('加载词书失败: $e')));
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
      // key 挂在可见条带上：几何回归测试测量的是可见内容底边（不含预留区）
      child: Container(
        key: const ValueKey('lib-select-bottom-toolbar'),
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
      showMwSnackBar(context, const SnackBar(content: Text('请先选择一本词书')));
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
        showMwSnackBar(context, SnackBar(content: Text('$tool 功能开发中...')));
    }
  }

  Future<void> _startDictation(BuildContext context, Book book) async {
    final words = await context.read<BookWordListReader>().loadWords(book.id);
    if (!context.mounted) return;
    if (words.isEmpty) {
      showMwSnackBar(context, const SnackBar(content: Text('该词书暂无单词')));
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
      showMwSnackBar(context, const SnackBar(content: Text('该词书暂无单词')));
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
