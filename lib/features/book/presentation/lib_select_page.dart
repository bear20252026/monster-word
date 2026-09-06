// 由 Claude 团队生成 | Monster Word App

// 由账号4生成
// 词书选择页：词书列表 + 分类过滤
// 结构：顶部导航栏 + 分类选项卡(TabPageIndicator) + 词书列表(封面+名称+描述+单词量, 120dp/项)
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:word_app/models/book.dart';
import 'package:word_app/features/book/domain/book_groups.dart';
import 'package:word_app/widgets/app_dock.dart';
import 'package:word_app/widgets/common/mw_empty_state.dart';
import 'package:word_app/widgets/common/mw_skeleton.dart';
import 'package:word_app/features/learning/application/learning_session_reader.dart';
import 'package:word_app/features/learning/application/learning_session_starter.dart';
import 'package:word_app/app/router/nav_utils.dart';
import 'package:word_app/app/router/route_names.dart';
import 'package:word_app/core/presentation/responsive.dart';
import 'package:word_app/theme/skin_system.dart';
import 'package:word_app/tokens/design_tokens.dart';
import 'package:word_app/core/infrastructure/app_preferences.dart';
import 'package:word_app/widgets/bending_gallery.dart';
import 'package:word_app/widgets/daily_goal_picker.dart';
import 'package:word_app/widgets/morphing_tabs.dart';
import 'package:word_app/widgets/word_globe.dart';
import 'package:word_app/features/book/application/book_catalog_reader.dart';
import 'package:word_app/features/book/application/book_word_list_reader.dart';
import 'package:word_app/features/book/presentation/book_state.dart';
import 'package:word_app/features/book/presentation/books_page.dart';
import 'package:word_app/features/book/presentation/extensive_model_select_page.dart';
import 'package:word_app/features/book/presentation/word_export_page.dart';

class LibSelectPage extends StatefulWidget {
  const LibSelectPage({super.key});

  static const routeName = '/lib_select';

  @override
  State<LibSelectPage> createState() => _LibSelectPageState();
}

/// 按 book code hash 稳定分配三档封面色——基于当前皮肤 accent 的
/// HSL 明度变体（本色/提亮/加深），跟随主题适配（用户反馈修复：
/// 此前是星巴克绿硬编码色表，任何皮肤下都是绿色）。
Color coverColorFor(BuildContext context, String code) {
  final accent = context.skin.colors.accent;
  final hsl = HSLColor.fromColor(accent);
  final index = code.hashCode.abs() % 3;
  final isDark = context.skin.currentTheme.uiBrightness == Brightness.dark;
  // 明度偏移量（深色画布整体提亮一档，避免封面与背景混淆）
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
  int _tabIndex = 0; // 当前分组下标（对应 _groupDefs 的组号，0 = 全部）
  bool _showDescription = true; // 眼睛图标：显示/隐藏词书描述

  // 分组排布：规则下沉在 book/domain/book_groups.dart，UI 只消费结果；
  // 标签栏数据驱动，仅展示当前词库里非空的组。
  @override
  void initState() {
    super.initState();
    _booksFuture = _load();
  }

  Future<List<Book>> _load() async {
    final books = await context.read<BookCatalogReader>().listBooks();
    _allBooks = books;
    // 分组标签依赖 _allBooks 计算非空组，加载完成后刷新（标签栏在 FutureBuilder 之外）
    if (mounted) setState(() {});
    return books;
  }

  /// 当前词库中非空的分组（有序）
  List<int> get _visibleGroups {
    final present = _allBooks.map((b) => bookGroupOf(b.code)).toSet();
    return kBookGroupNames.indexed.map((e) => e.$1).where((g) => g == BookGroup.all || present.contains(g)).toList();
  }

  /// 按分组过滤词书
  List<Book> _filterByTab(List<Book> books, int tab) {
    if (tab == BookGroup.all) return books;
    return books.where((b) => bookGroupOf(b.code) == tab).toList();
  }

  /// 从弯曲画廊打开词书（导航到词书内容页）
  void _openBookFromGallery(BuildContext context, Book book) {
    Navigator.pushNamed(context, RouteNames.bookWords, arguments: book);
  }

  // ===== 顶部导航栏（左箭头 + 标题 + 搜索/眼睛/更多）=====
  Widget _buildTopNav(ThemeVars colors) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      color: colors.cardBg,
      child: Row(
        children: [
          // 作为 tab 时无返回箭头（标题「课程」）；被「切换」push 时标题「选择词书」
          if (Navigator.of(context).canPop())
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, size: 20),
              color: colors.text1,
              onPressed: () => NavUtils.safePop(context),
            )
          else
            const SizedBox(width: 12),
          Expanded(
            child: Text(
              Navigator.of(context).canPop() ? '选择词书' : '课程',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: colors.text1),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.search, size: 22),
            color: colors.text1,
            onPressed: () => Navigator.pushNamed(context, RouteNames.search),
          ),
          IconButton(
            icon: Icon(_showDescription ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 22),
            color: colors.text1,
            tooltip: _showDescription ? '隐藏词书描述' : '显示词书描述',
            onPressed: () => setState(() => _showDescription = !_showDescription),
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

  // ===== 精选区：词源星球（品牌一刻）+ 弯曲画廊，卡片名只出现一次 =====
  Widget _buildFeaturedStrip(BuildContext context, ThemeVars colors, List<Book> featured) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
          child: Row(
            children: [
              SizedBox(
                width: 56,
                height: 56,
                child: WordGlobe(
                  size: 56,
                  arcColor: colors.accent,
                  atmosphereColor: colors.accent,
                  points: WordOriginData.origins,
                  arcs: WordOriginData.connections,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '单词的环球之旅',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: colors.text1),
                    ),
                    const SizedBox(height: 2),
                    Text('拖动星球，追溯每个词的起源与传播路径', style: TextStyle(fontSize: 11, height: 1.3, color: colors.text3)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        BendingGallery(
          height: 148,
          itemWidth: 104,
          curvature: 0.35,
          activeColor: colors.accent,
          items: featured.map((book) {
            return BendingGalleryItem(
              color: coverColorFor(context, book.code),
              onTap: () => _openBookFromGallery(context, book),
              // 封面内已含名称与词数，不再传 label（旧版名称出现两次）
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.menu_book_rounded, color: AppColors.white100, size: 22),
                  const SizedBox(height: 6),
                  Text(
                    friendlyBookName(book.name),
                    style: MwTypography.bodySm.copyWith(
                      color: AppColors.white100,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${book.wordCount} 词',
                    style: MwTypography.micro.copyWith(color: AppColors.white100.withValues(alpha: 0.75)),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.skin.colors;
    final resp = context.responsive;
    // 桌面端把内容收窄到阅读宽度，避免整条柱拉满全宽显得散
    final contentMaxWidth = resp.isDesktop ? 1200.0 : double.infinity;
    return Scaffold(
      backgroundColor: colors.cardBg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: contentMaxWidth),
            child: _buildBody(colors, resp),
          ),
        ),
      ),
    );
  }

  /// 课程页主体：顶部导航 + 分类签 + 词书列表 + 底部工具栏。
  Widget _buildBody(ThemeVars colors, AppResponsive resp) {
    return Column(
      children: [
        _buildTopNav(colors),
        Container(height: 1, color: colors.divider),
        // ===== 分类选项卡（Morphing Tabs 变形标签，仅展示非空分组）=====
        Padding(
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
        ),
        Container(height: 1, color: colors.divider),
        // ===== 词书列表（ListView，每项 120dp）=====
        Expanded(
          child: FutureBuilder<List<Book>>(
            future: _booksFuture,
            builder: (context, snapshot) {
              final skin = context.skin.colors;
              if (snapshot.connectionState != ConnectionState.done) {
                return const MwSkeletonGrid(count: 6);
              }
              if (snapshot.hasError) {
                return const MwEmptyState(kind: MwEmptyKind.error, title: '词书加载失败', subtitle: '检查网络后重试，或稍后再来');
              }
              final books = _filterByTab(_allBooks, _tabIndex);
              if (books.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.library_books_outlined, size: 64, color: skin.divider),
                      const SizedBox(height: 16),
                      Text('暂无词书', style: MwTypography.bodyMd.copyWith(color: skin.text3)),
                      const SizedBox(height: 8),
                      Text('当前分类下没有词书，请切换分类或刷新', style: MwTypography.bodySm.copyWith(color: skin.text3)),
                      const SizedBox(height: 24),
                      OutlinedButton.icon(
                        onPressed: () => setState(() => _booksFuture = _load()),
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text('刷新'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: skin.text2,
                          side: BorderSide(color: skin.divider),
                        ),
                      ),
                    ],
                  ),
                );
              }
              // 全部标签页顶部展示推荐词书「弯曲画廊」（3D透视+交互弯曲）
              if (_tabIndex == 0 && books.length > 3) {
                final featured = books.take(8).toList();
                return Column(
                  children: [
                    const SizedBox(height: 10),
                    _buildFeaturedStrip(context, colors, featured),
                    const Divider(height: 1),
                    Expanded(
                      child: ListView.builder(
                        itemCount: books.length,
                        itemBuilder: (context, index) {
                          final book = books[index];
                          return _LibItem(book: book, showDescription: _showDescription);
                        },
                      ),
                    ),
                  ],
                );
              }
              return resp.isDesktop
                  ? GridView.builder(
                      padding: EdgeInsets.all(resp.horizontalPadding),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: resp.bookGridColumns,
                        childAspectRatio: 0.75,
                        crossAxisSpacing: resp.horizontalPadding,
                        mainAxisSpacing: resp.horizontalPadding,
                      ),
                      itemCount: books.length,
                      itemBuilder: (context, index) {
                        final book = books[index];
                        return _LibItem(book: book, showDescription: _showDescription);
                      },
                    )
                  : ListView.builder(
                      itemCount: books.length,
                      itemBuilder: (context, index) {
                        final book = books[index];
                        return _LibItem(book: book, showDescription: _showDescription);
                      },
                    );
            },
          ),
        ),
        // ===== 底部工具栏 =====
        _buildBottomToolbar(colors),
      ],
    );
  }

  /// 底部工具栏。
  /// 预留悬浮 Dock 高度：否则工具栏与主壳悬浮 Dock 重叠（v2.7.22 用户实测）。
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
        // 考试速刷 → 独立于词书的考试模式速刷
        Navigator.pushNamed(context, RouteNames.examQuickReview);
        break;
      case 'listen':
        // 随身听 → 模式选择页
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ExtensiveModelSelectPage(bookId: book!.id.toString(), bookName: book.name),
          ),
        );
        break;
      case 'dictation':
        // 听写 → 直接加载单词进入听写
        _startDictation(context, book!);
        break;
      case 'spell':
        // 随手拼 → 直接加载单词进入拼写
        _startQuickSpell(context, book!);
        break;
      case 'export':
        // 导出 → 导出页面
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

  void _showMoreMenu(BuildContext context, dynamic colors) {
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

/// 词书列表项（120dp 高）
class _LibItem extends StatefulWidget {
  const _LibItem({required this.book, this.showDescription = true});

  final Book book;
  final bool showDescription;

  @override
  State<_LibItem> createState() => _LibItemState();
}

class _LibItemState extends State<_LibItem> {
  bool _selecting = false;

  // 三档绿（亮色模式）—— 星巴克品牌绿轮换

  /// 从词书 code 推断描述标签（如 'CET4 | 1200词'），替代硬编码文本
  static String _categoryOf(String code) {
    if (RegExp(r'CET4|四级').hasMatch(code)) return 'CET4';
    if (RegExp(r'CET6|六级').hasMatch(code)) return 'CET6';
    if (RegExp(r'GK|高考|GKCJ|GKHX|GKSG').hasMatch(code)) return '高考';
    if (RegExp(r'KY|考研|KAOYAN|LLYC|KYSG').hasMatch(code)) return '考研';
    if (RegExp(r'IELTS|雅思').hasMatch(code)) return '雅思';
    if (RegExp(r'TOEFL|托福|GDTOEFL').hasMatch(code)) return '托福';
    if (RegExp(r'GRE|GMAT|SAT|BEC|TEM|专四|专八|PRO4|PRO8|XHPRO|PETS').hasMatch(code)) {
      return '专业出国';
    }
    return '其他';
  }

  String _coverText() {
    final name = friendlyBookName(widget.book.name).replaceAll(RegExp(r'\s'), '');
    // 中文显示名最多取 4 字，编码名最多取 6 字符，避免封面溢出
    final isChinese = name.contains(RegExp(r'[\u4e00-\u9fff]'));
    final limit = isChinese ? 4 : 6;
    return name.length > limit ? name.substring(0, limit) : name;
  }

  /// 底部行：单词量 + 「查看单词」入口（进词书展示页浏览全部单词）
  Widget _buildWordCountRow(BuildContext context, Book book) {
    final colors = context.skin.colors;
    return Row(
      children: [
        Text('单词量', style: TextStyle(fontSize: 12, color: colors.text3)),
        const SizedBox(width: 5),
        Text(
          '${widget.book.wordCount}',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: colors.text3),
        ),
        const Spacer(),
        GestureDetector(
          onTap: () =>
              Navigator.pushNamed(context, RouteNames.bookWords, arguments: {'bookId': book.id, 'bookName': book.name}),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.list_alt, size: 16, color: colors.accent),
              const SizedBox(width: 4),
              Text(
                '查看单词',
                style: TextStyle(fontSize: 12, color: colors.accent, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = context.read<LearningSessionReader>();
    final colors = context.skin.colors;
    final book = widget.book;
    final showDescription = widget.showDescription;
    final isLearning = session.currentBook?.id == widget.book.id;

    return GestureDetector(
      onTap: () => _handleCardTap(context),
      child: Container(
        height: 120,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: colors.divider)),
        ),
        child: Row(
          children: [
            // ===== 词书封面（星巴克风格：纯色底 + 白字，三档绿 hash 轮换）=====
            Container(
              width: 72,
              height: 88,
              decoration: BoxDecoration(
                color: coverColorFor(context, widget.book.code),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Text(
                  _coverText(),
                  style: const TextStyle(color: AppColors.white100, fontSize: 11, fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            const SizedBox(width: 16),
            // ===== 右侧文字区（tv_lib_name + tv_desc + tv_word_count）=====
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          friendlyBookName(book.name),
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: colors.text1),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // 正在学习标签（right_tag）
                      if (isLearning)
                        Text(
                          '正在学习',
                          style: TextStyle(fontSize: 12, color: colors.success, fontWeight: FontWeight.w500),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (showDescription)
                    Text(
                      '${_categoryOf(book.code)} | ${book.wordCount}词',
                      style: TextStyle(fontSize: 12, color: colors.text3),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const Spacer(),
                  _buildWordCountRow(context, book),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 点卡片 = 直接完成选中并生效（选择页语义 2026-08-31 交互分离最终版）：
  /// 填充学习队列 + 同步词书聚合状态 + 持久化选中，然后返回首页；
  /// 查看单词列表走卡片右侧「查看单词」进词书详情页。
  Future<void> _handleCardTap(BuildContext context) async {
    if (_selecting) return; // 防连点/并发竞态（体验审计 A-3）
    setState(() => _selecting = true);
    try {
      await context.read<LearningSessionStarter>().startBookSession(widget.book, limit: 50);
      if (context.mounted) {
        // 同步词书聚合状态（currentBook 标记 + selectBook 持久化 + 全量词表）
        await context.read<BookState>().selectAndLoad(widget.book);
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('已选中《${widget.book.name}》')));
        // 每日目标仅首次选书时弹出（体验审计 A-3：每次换书都弹是打扰）
        final prefs = AppPreferences();
        final firstTime = !prefs.getBool(AppPreferences.dailyGoalPromptShownKey, defaultValue: false);
        if (!firstTime) {
          if (context.mounted) Navigator.pop(context);
          return;
        }
        await prefs.setBool(AppPreferences.dailyGoalPromptShownKey, true);
        if (!context.mounted) return;
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
        nav.pop(); // 选中完成，返回首页
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('加载词书失败: $e')));
      }
    } finally {
      if (mounted) setState(() => _selecting = false);
    }
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
