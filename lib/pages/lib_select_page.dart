// 由账号4生成
// 词书选择页：1:1 复刻原版 activity_lib_select.xml + lv_item_select_library.xml
// 结构：顶部导航栏 + 分类选项卡(TabPageIndicator) + 词书列表(封面+名称+描述+单词量, 120dp/项)
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/wordbook_database.dart';
import '../state/learning_state.dart';
import '../theme/app_theme.dart';
import 'learn_page.dart';

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
    return Scaffold(
      backgroundColor: AppColors.cardBg,
      body: SafeArea(
        child: Column(
          children: [
            // ===== 顶部导航栏（原版 CustomHeadView：左箭头 + "选择词书"）=====
            Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              color: AppColors.cardBg,
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                    color: AppColors.black87,
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    '选择词书',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.black87,
                    ),
                  ),
                ],
              ),
            ),
            Container(height: 1, color: AppColors.dividerGrey),
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
                        color: selected ? AppColors.successGreen : Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        _tabs[i],
                        style: TextStyle(
                          fontSize: 13,
                          color: selected ? Colors.white : AppColors.textTertiary,
                          fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Container(height: 1, color: AppColors.dividerGrey),
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
                      return _LibItem(book: book);
                    },
                  );
                },
              ),
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
  const _LibItem({required this.book});

  @override
  Widget build(BuildContext context) {
    final state = context.read<LearningState>();
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
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.dividerGrey)),
        ),
        child: Row(
          children: [
            // ===== 词书封面（原版 lib_fengmian，圆角 4dp）=====
            Container(
              width: 72,
              height: 88,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.mainBgTop, AppColors.mainBgBottom],
                ),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Center(
                child: Text(
                  _coverText(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
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
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: AppColors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // 正在学习标签（原版 right_tag）
                      if (isLearning)
                        const Text(
                          '正在学习',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.successGreen,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '考研核心高频 | 2026',
                    style: const TextStyle(fontSize: 12, color: AppColors.textTertiary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Spacer(),
                  // 底部行：单词量（原版底部对齐）
                  Row(
                    children: [
                      Text(
                        '单词量',
                        style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '${book.wordCount}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textTertiary,
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

  String _coverText() {
    final name = book.name.replaceAll(RegExp(r'LangEasyLexisV3_'), '');
    return name.length > 4 ? name.substring(0, 4) : name;
  }
}
