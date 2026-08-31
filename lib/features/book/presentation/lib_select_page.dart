// 由 Claude 团队生成 | Monster Word App

// 由账号4生成
// 词书选择页：1:1 复刻原版 activity_lib_select.xml + lv_item_select_library.xml
// 结构：顶部导航栏 + 分类选项卡(TabPageIndicator) + 词书列表(封面+名称+描述+单词量, 120dp/项)
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:word_app/models/book.dart';
import 'package:word_app/widgets/common/mw_empty_state.dart';
import 'package:word_app/widgets/common/mw_skeleton.dart';
import 'package:word_app/features/learning/application/learning_session_reader.dart';
import 'package:word_app/features/learning/application/learning_session_starter.dart';
import 'package:word_app/core/router/nav_utils.dart';
import 'package:word_app/core/router/route_names.dart';
import 'package:word_app/core/presentation/responsive.dart';
import 'package:word_app/theme/skin_system.dart';
import 'package:word_app/tokens/design_tokens.dart';
import 'package:word_app/widgets/bending_gallery.dart';
import 'package:word_app/widgets/daily_goal_picker.dart';
import 'package:word_app/widgets/morphing_tabs.dart';
import 'package:word_app/widgets/word_globe.dart';
import 'package:word_app/features/book/application/book_catalog_reader.dart';
import 'package:word_app/features/book/application/book_words_reader.dart';
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

class _LibSelectPageState extends State<LibSelectPage> {
  late Future<List<Book>> _booksFuture;
  List<Book> _allBooks = [];
  int _tabIndex = 0;
  bool _showDescription = true; // 眼睛图标：显示/隐藏词书描述

  static const _tabs = ['全部', 'CET4', 'CET6', '高考', '考研', '雅思', '托福', '专业出国', '其他'];

  @override
  void initState() {
    super.initState();
    _booksFuture = _load();
  }

  Future<List<Book>> _load() async {
    final books = await context.read<BookCatalogReader>().listBooks();
    _allBooks = books;
    return books;
  }

  /// 按分类过滤词书（复刻原版分类逻辑）
  List<Book> _filterByTab(List<Book> books, int tab) {
    if (tab == 0) return books;
    final code = _tabs[tab];
    return books.where((b) => _categoryOf(b.code) == code).toList();
  }

  String _categoryOf(String code) {
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

  /// 从弯曲画廊打开词书（导航到词书内容页）
  void _openBookFromGallery(BuildContext context, Book book) {
    Navigator.pushNamed(context, RouteNames.bookWords, arguments: book);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.skin.colors;
    final resp = context.responsive;
    return Scaffold(
      backgroundColor: colors.cardBg,
      body: SafeArea(
        child: Column(
          children: [
            // ===== 顶部导航栏（原版 CustomHeadView：左箭头 + 标题 + 搜索/眼睛）=====
            Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              color: colors.cardBg,
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                    color: colors.text1,
                    onPressed: () => NavUtils.safePop(context),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '选择词书',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: colors.text1),
                    ),
                  ),
                  // 搜索图标
                  IconButton(
                    icon: const Icon(Icons.search, size: 22),
                    color: colors.text1,
                    onPressed: () {
                      Navigator.pushNamed(context, RouteNames.search);
                    },
                  ),
                  // 眼睛图标（显示/隐藏词书描述）
                  IconButton(
                    icon: Icon(_showDescription ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 22),
                    color: colors.text1,
                    tooltip: _showDescription ? '隐藏词书描述' : '显示词书描述',
                    onPressed: () {
                      setState(() => _showDescription = !_showDescription);
                    },
                  ),
                  // 更多选项菜单
                  IconButton(
                    icon: const Icon(Icons.more_horiz, size: 22),
                    color: colors.text1,
                    onPressed: () {
                      _showMoreMenu(context, colors);
                    },
                  ),
                ],
              ),
            ),
            Container(height: 1, color: colors.divider),
            // ===== 分类选项卡（Morphing Tabs 变形标签）=====
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: SimpleMorphingTabs(
                labels: _tabs.toList(),
                initialIndex: _tabIndex,
                height: 36,
                borderRadius: 14,
                padding: const EdgeInsets.all(3),
                activeColor: AppColors.white100,
                inactiveColor: colors.text3,
                indicatorColor: colors.accent,
                backgroundColor: colors.cardBgAlt,
                onChanged: (i) => setState(() => _tabIndex = i),
              ),
            ),
            Container(height: 1, color: colors.divider),
            // ===== 词书列表（原版 ListView，每项 120dp）=====
            Expanded(
              child: FutureBuilder<List<Book>>(
                future: _booksFuture,
                builder: (context, snapshot) {
                  final skin = context.skin.colors;
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const MwSkeletonGrid(count: 6);
                  }
                  if (snapshot.hasError) {
                    return const MwEmptyState(
                      kind: MwEmptyKind.error,
                      title: '词书加载失败',
                      subtitle: '检查网络后重试，或稍后再来',
                    );
                  }
                  final books = _filterByTab(_allBooks, _tabIndex);
                  if (books.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.library_books_outlined, size: 64, color: skin.divider),
                          const SizedBox(height: 16),
                          Text('暂无词书', style: MistralTypography.bodyMd.copyWith(color: skin.text3)),
                          const SizedBox(height: 8),
                          Text('当前分类下没有词书，请切换分类或刷新', style: MistralTypography.bodySm.copyWith(color: skin.text3)),
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
                        // ===== 词源星球品牌展示（3D 旋转地球 + 六大词源地，可拖拽/缩放）=====
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 0, 14, 4),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: colors.cardBgAlt, borderRadius: BorderRadius.circular(24)),
                            child: Row(
                              children: [
                                WordGlobe(
                                  size: 100,
                                  arcColor: colors.accent,
                                  atmosphereColor: colors.accent,
                                  points: WordOriginData.origins,
                                  arcs: WordOriginData.connections,
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '单词的环球之旅',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: colors.text1,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '从罗马到伦敦，追溯每个词的起源与传播路径。拖动星球旋转，双指缩放探索。',
                                        style: TextStyle(fontSize: 12, height: 1.4, color: colors.text2),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              '精选词书 · 左右滑动探索',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colors.text2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        BendingGallery(
                          height: 175,
                          itemWidth: 112,
                          curvature: 0.35,
                          activeColor: colors.accent,
                          items: featured.map((book) {
                            final idx = featured.indexOf(book);
                            return BendingGalleryItem(
                              label: book.name,
                              color: _LibItem._coverColorsLight[idx % _LibItem._coverColorsLight.length],
                              onTap: () => _openBookFromGallery(context, book),
                              // 画廊单元格固定约 112×122，放不下完整卡片，
                              // 这里用紧凑封面内容（图标 + 编码 + 词数）
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.menu_book, color: AppColors.white100, size: 26),
                                  const SizedBox(height: 8),
                                  Text(
                                    book.code,
                                    style: MistralTypography.bodyMd.copyWith(
                                      color: AppColors.white100,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${book.wordCount} 词',
                                    style: MistralTypography.caption.copyWith(
                                      color: AppColors.white100.withValues(alpha: 0.75),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
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
            // ===== 底部工具栏（原版底部操作栏）=====
            Container(
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
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 打开词书主页（BookDashboardPage）。
  void _openBookDashboard(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const BookDashboardPage()),
    );
  }

  void _onToolTap(BuildContext context, String tool) {
    final book = context.read<LearningSessionReader>().currentBook;

    if (book == null && tool != 'immersive') {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请先选择一本词书')));
      return;
    }

    switch (tool) {
      case 'immersive':
        Navigator.pushNamed(context, RouteNames.immersiveSwipe);
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
    final words = await context.read<BookWordsReader>().loadWords(book.id);
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
    final words = await context.read<BookWordsReader>().loadWords(book.id);
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

/// 词书列表项（复刻原版 lv_item_select_library：120dp 高）
class _LibItem extends StatelessWidget {
  final Book book;
  final bool showDescription;
  const _LibItem({required this.book, this.showDescription = true});

  // 三档绿（亮色模式）—— 星巴克品牌绿轮换
  static const _coverColorsLight = [
    Color(0xFF006241), // Starbucks Green
    Color(0xFF00754A), // House Green
    Color(0xFF1E3932), // 墨绿
  ];

  // 三档绿（深色模式：绿-3 提亮，避免与深色画布混淆）
  static const _coverColorsDark = [
    Color(0xFF006241),
    Color(0xFF00754A),
    Color(0xFF2b5148), // 墨绿提亮（替代 #1E3932）
  ];

  /// 按 book code hash 稳定分配三档绿
  Color _coverColor(BuildContext context, String code) {
    final index = code.hashCode.abs() % 3;
    final isDark = context.skin.currentTheme.uiBrightness == Brightness.dark;
    return isDark ? _coverColorsDark[index] : _coverColorsLight[index];
  }

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
    final name = book.name.replaceAll(RegExp(r'MonsterWord_'), '');
    return name.length > 4 ? name.substring(0, 4) : name;
  }

  /// 底部行：单词量 + 「查看单词」入口（进词书展示页浏览全部单词）
  Widget _buildWordCountRow(BuildContext context, Book book) {
    final colors = context.skin.colors;
    return Row(
      children: [
        Text('单词量', style: TextStyle(fontSize: 12, color: colors.text3)),
        const SizedBox(width: 5),
        Text(
          '${book.wordCount}',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: colors.text3),
        ),
        const Spacer(),
        GestureDetector(
          onTap: () => Navigator.pushNamed(
            context,
            RouteNames.bookWords,
            arguments: {'bookId': book.id, 'bookName': book.name},
          ),
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
    final isLearning = session.currentBook?.id == book.id;

    return GestureDetector(
      onTap: () async {
        // 选择页语义（2026-08-31 交互分离最终版）：
        // 点书 = 直接完成选中并生效（填充学习队列 + 同步词书聚合状态 + 持久化选中），
        // 然后返回首页；查看单词列表走卡片右侧「查看单词」进词书详情页。
        try {
          await context.read<LearningSessionStarter>().startBookSession(book, limit: 50);
          if (context.mounted) {
            // 同步词书聚合状态（currentBook 标记 + selectBook 持久化 + 全量词表）
            await context.read<BookState>().selectAndLoad(book);
          }
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('已选中《${book.name}》')),
            );
            // 用户需求：选书后提供每日学习目标设置（如每天背 50 个单词）
            await showModalBottomSheet<void>(
              context: context,
              builder: (sheetCtx) => SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('设置每日学习目标',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      const DailyGoalPicker(),
                      const SizedBox(height: 8),
                      FilledButton(
                        onPressed: () => Navigator.pop(sheetCtx),
                        child: const Text('完成，回首页开始学习'),
                      ),
                    ],
                  ),
                ),
              ),
            );
            if (context.mounted) Navigator.pop(context); // 选中完成，返回首页
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('加载词书失败: $e')));
          }
        }
      },
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
                color: _coverColor(context, book.code),
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
            // ===== 右侧文字区（原版 tv_lib_name + tv_desc + tv_word_count）=====
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          book.name,
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: colors.text1),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // 正在学习标签（原版 right_tag）
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
