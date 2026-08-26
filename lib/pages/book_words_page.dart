// 由 Claude 团队生成 | Monster Word App

// 移植自 v3.2 BookWordsActivity
// 词书单词列表：显示指定词书中的所有单词 + 配套真题词组卡片
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/di/service_locator.dart';
import '../repositories/book_repository.dart';
import '../state/learning_state.dart';
import '../state/learn_state.dart';
import '../models/word.dart';
import '../theme/skin_system.dart';
import '../widgets/exam_phrase_widgets.dart';
import '../widgets/sb_fab.dart';
import 'learn_page.dart';
import 'list_words_page.dart';

class BookWordsPage extends ListWordsPage {
  final int bookId;
  final String bookName;

  const BookWordsPage({
    super.key,
    required this.bookId,
    required this.bookName,
  });

  static const routeName = '/book_words';

  @override
  State<BookWordsPage> createState() => _BookWordsPageState();
}

class _BookWordsPageState extends ListWordsPageState<BookWordsPage> {
  // 配套真题词组状态
  final List<ExamPhraseGroup> _phraseGroups = [];
  List<ExamPhraseGroup> _availableGroups = [];

  /// 词书内容页主操作：加载当前词书后开始学习
  @override
  Widget? get learningFab => SbFab(
        icon: Icons.play_arrow_rounded,
        label: '开始学习',
        onTap: () async {
          // ✅ 修复：使用 LearnState（与 LearnPage 一致），而非 LearningState
          final learnState = context.read<LearnState>();
          final bookRepo = sl<BookRepository>();
          final books = await bookRepo.getBooks();
          final book = books.where((b) => b.id == widget.bookId).firstOrNull;
          if (book == null) return;
          await learnState.loadBook(book, shuffle: true);
          if (context.mounted) {
            Navigator.pushNamed(context, LearnPage.routeName);
          }
        },
      );

  @override
  String get pageTitle => widget.bookName;

  @override
  void initState() {
    super.initState();
    _loadPhraseGroups();
  }

  void _loadPhraseGroups() {
    // 模拟数据：根据词书生成可用的真题词组
    final bookName = widget.bookName;
    String examType = 'CET4';
    if (bookName.contains('六级') || bookName.contains('CET6')) examType = 'CET6';
    if (bookName.contains('高考') || bookName.contains('GK')) examType = '高考';
    if (bookName.contains('考研') || bookName.contains('KY')) examType = '考研';
    if (bookName.contains('雅思') || bookName.contains('IELTS')) examType = '雅思';
    if (bookName.contains('托福') || bookName.contains('TOEFL')) examType = '托福';

    setState(() {
      _availableGroups = [
        ExamPhraseGroup(
          id: 1,
          bookId: widget.bookId,
          name: '$examType高频真题词组',
          examType: examType,
          phraseCount: 120,
        ),
        ExamPhraseGroup(
          id: 2,
          bookId: widget.bookId,
          name: '$examType阅读真题词组',
          examType: examType,
          phraseCount: 85,
        ),
        ExamPhraseGroup(
          id: 3,
          bookId: widget.bookId,
          name: '$examType写作真题词组',
          examType: examType,
          phraseCount: 60,
        ),
      ];
    });
  }

  void _addPhraseGroup(ExamPhraseGroup group) {
    setState(() {
      _phraseGroups.add(ExamPhraseGroup(
        id: group.id,
        bookId: group.bookId,
        name: group.name,
        examType: group.examType,
        phraseCount: group.phraseCount,
        isAdded: true,
      ));
      _availableGroups = _availableGroups.where((g) => g.id != group.id).toList();
    });
  }

  void _showAddSheet() {
    ExamPhraseSheet.show(
      context,
      bookName: widget.bookName,
      availableGroups: _availableGroups,
      onAdd: _addPhraseGroup,
    );
  }

  @override
  Future<List<Word>> loadWords(LearningState state) async {
    return state.getWordsByBook(widget.bookId);
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;

    // 在 base 的 Column 中插入真题词组卡片
    // 由于 base 是 Scaffold，我们需要重新构建
    return Scaffold(
      backgroundColor: skin.colors.pageBg,
      body: SafeArea(
        child: Column(
          children: [
            // 复用基类的导航栏
            _buildNavBar(skin),
            Container(height: 1, color: skin.colors.divider),
            // 内容区
            Expanded(
              child: CustomScrollView(
                slivers: [
                  // 配套真题词组卡片
                  SliverToBoxAdapter(
                    child: ExamPhraseCard(
                      bookId: widget.bookId,
                      bookName: widget.bookName,
                      phraseGroups: _phraseGroups,
                      onAdd: _showAddSheet,
                      onTap: (group) {
                        // TODO: 跳转到词组详情页
                      },
                    ),
                  ),
                  // 单词列表
                  _buildWordListSliver(skin),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavBar(SkinSystem skin) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
            color: skin.colors.text1,
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 4),
          Text(
            pageTitle,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: skin.colors.text1,
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildWordListSliver(SkinSystem skin) {
    // 使用基类已加载的单词列表，避免重复加载
    if (isLoading) {
      return const SliverFillRemaining(
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final words = this.words;
    if (words.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.inbox_outlined, size: 64, color: skin.colors.text3),
              const SizedBox(height: 16),
              Text('暂无单词', style: TextStyle(color: skin.colors.text3)),
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: () => refreshData(),
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('刷新'),
              ),
            ],
          ),
        ),
      );
    }
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final word = words[index];
          return ListTile(
            title: Text(
              word.word,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: skin.colors.text1,
              ),
            ),
            subtitle: word.usPron.isNotEmpty
                ? Text(
                    '/${word.usPron}/',
                    style: TextStyle(fontSize: 13, color: skin.colors.text3),
                  )
                : null,
            trailing: Icon(Icons.chevron_right, color: skin.colors.text3),
            onTap: () => Navigator.pushNamed(context, '/word_detail', arguments: word),
          );
        },
        childCount: words.length,
      ),
    );
  }
}
