// 由 Claude 团队生成 | Monster Word App

// 由账号4生成
// 词书选择页：1:1 复刻原版 activity_lib_select.xml + lv_item_select_library.xml
// 结构：顶部导航栏 + 分类选项卡(TabPageIndicator) + 词书列表(封面+名称+描述+单词量, 120dp/项)
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/wordbook_database.dart';
import '../state/learning_state.dart';
import '../theme/skin_system.dart';
import 'learn_page.dart';
import 'search_page.dart';

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
    final books = await WordBookDatabase.instance.getBooks();
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

  @override
  Widget build(BuildContext context) {
    final colors = context.skin.colors;
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
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '选择词书',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: colors.text1,
                      ),
                    ),
                  ),
                  // 搜索图标
                  IconButton(
                    icon: const Icon(Icons.search, size: 22),
                    color: colors.text1,
                    onPressed: () {
                      Navigator.pushNamed(context, SearchPage.routeName);
                    },
                  ),
                  // 眼睛图标（显示/隐藏词书描述）
                  IconButton(
                    icon: Icon(
                      _showDescription
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 22,
                    ),
                    color: colors.text1,
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
            // ===== 分类选项卡（原版 TabPageIndicator）=====
            SizedBox(
              height: 40,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                itemCount: _tabs.length,
                itemBuilder: (context, i) {
                  final selected = i == _tabIndex;
                  return GestureDetector(
                    onTap: () => setState(() => _tabIndex = i),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: selected ? colors.accent : Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        _tabs[i],
                        style: TextStyle(
                          fontSize: 12,
                          color: selected ? Colors.white : colors.text3,
                          fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Container(height: 1, color: colors.divider),
            // ===== 词书列表（原版 ListView，每项 120dp）=====
            Expanded(
              child: FutureBuilder<List<Book>>(
                future: _booksFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('加载失败: ${snapshot.error}'));
                  }
                  final books = _filterByTab(_allBooks, _tabIndex);
                  if (books.isEmpty) {
                    return const Center(child: Text('暂无词书'));
                  }
                  return ListView.builder(
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
                    _BottomToolItem(
                      icon: Icons.style,
                      label: '沉浸刷词',
                      onTap: () => _onToolTap(context, 'immersive'),
                    ),
                    _BottomToolItem(
                      icon: Icons.headphones,
                      label: '随身听',
                      onTap: () => _onToolTap(context, 'listen'),
                    ),
                    _BottomToolItem(
                      icon: Icons.edit_note,
                      label: '听写',
                      onTap: () => _onToolTap(context, 'dictation'),
                    ),
                    _BottomToolItem(
                      icon: Icons.spellcheck,
                      label: '随手拼',
                      onTap: () => _onToolTap(context, 'spell'),
                    ),
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

  void _onToolTap(BuildContext context, String tool) {
    switch (tool) {
      case 'immersive':
        Navigator.pushNamed(context, '/immersive_swipe');
        break;
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$tool 功能开发中...')),
        );
    }
  }

  void _showMoreMenu(BuildContext context, dynamic colors) {
    showModalBottomSheet(
      context: context,
      backgroundColor: colors.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
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

  String _coverText() {
    final name = book.name.replaceAll(RegExp(r'MonsterWord_'), '');
    return name.length > 4 ? name.substring(0, 4) : name;
  }

  @override
  Widget build(BuildContext context) {
    final state = context.read<LearningState>();
    final colors = context.skin.colors;
    final isLearning = state.currentBook?.id == book.id;

    return GestureDetector(
      onTap: () async {
        await state.loadBook(book, limit: 50);
        if (context.mounted) {
          Navigator.pushNamed(context, LearnPage.routeName);
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
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  _coverText(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
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
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: colors.text1,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // 正在学习标签（原版 right_tag）
                      if (isLearning)
                        Text(
                          '正在学习',
                          style: TextStyle(
                            fontSize: 12,
                            color: colors.success,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (showDescription)
                    Text(
                      '考研核心高频 | 2026',
                      style: TextStyle(fontSize: 12, color: colors.text3),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const Spacer(),
                  // 底部行：单词量（原版底部对齐）
                  Row(
                    children: [
                      Text(
                        '单词量',
                        style: TextStyle(fontSize: 12, color: colors.text3),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '${book.wordCount}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: colors.text3,
                        ),
                      ),
                    ],
                  ),
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

  const _BottomToolItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.skin.colors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22, color: colors.text1),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: colors.text1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
