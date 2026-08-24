// 由 Claude 团队生成 | Monster Word App

// 由账号4生成
// L3 学习页：壁纸沉浸 + HeroWord + 音标 + 释义 + 例句 + 派生词 + SegmentTabs + 底部双按钮
// 翻译自 Figma 03a-screens-learning.json learn_session
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/example_parser.dart';
import '../engine/fsrs5_engine.dart';
import '../hooks/responsive.dart';
import '../state/learning_state.dart';
import '../theme/skin_system.dart';
import '../tokens/design_tokens.dart';
import '../widgets/animations.dart';
import '../widgets/glass_widgets.dart';
import '../widgets/word_dictionary_popup.dart';

class LearnSession extends StatefulWidget {
  const LearnSession({super.key});
  static const routeName = '/learn_session';

  @override
  State<LearnSession> createState() => _LearnSessionState();
}

class _LearnSessionState extends State<LearnSession>
    with TickerProviderStateMixin {
  int _selectedTab = 0;

  static const _tabs = ['派生', '词组搭配', '词根', '笔记', '近义'];

  // Card page view (PageView with spring physics)
  late PageController _pageController;

  // Bottom bar spring slide-in animation
  late AnimationController _bottomBarController;
  late Animation<Offset> _bottomBarAnim;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _bottomBarController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _bottomBarAnim = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _bottomBarController,
      curve: SpringCurve(),
    ));
    // Trigger bottom bar slide-in
    _bottomBarController.forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _bottomBarController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final resp = context.responsive;
    final state = context.watch<LearningState>();
    final word = state.currentWord;

    if (word == null) {
      return const Scaffold(body: Center(child: Text('暂无单词')));
    }

    return Scaffold(
      body: GlassBg(
        child: SafeArea(
          child: Column(
            children: [
              // 透明导航栏（原版 nav：返回 + 进度 + 操作）
              _buildNav(skin, state),
              // 内容区 — PageView with spring scroll physics for card swiping
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  onPageChanged: (page) {
                    if (page != state.currentIndex) {
                      state.jumpTo(page);
                      setState(() {});
                    }
                  },
                  itemCount: state.total,
                  itemBuilder: (context, index) {
                    final w = state.queue[index];
                    final exs = ExampleParser.parse(w.example);
                    return SingleChildScrollView(
                      padding: EdgeInsets.symmetric(horizontal: resp.pageMargin),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 24),
                          // HeroWord (with syllable separators, green dot, like count) — 点击弹出字典
                          GestureDetector(
                            onTap: () {
                              WordDictionaryPopup.show(
                                context,
                                w,
                                onViewDetail: () {
                                  Navigator.pushNamed(context, '/word_detail');
                                },
                              );
                            },
                            child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                _addSyllableSeparators(w.word),
                                style: AppTypography.heroWord.copyWith(
                                  fontSize: resp.heroFontSize,
                                  color: skin.colors.onGlassText1,
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Green dot (mastered indicator)
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: skin.colors.success,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              // Like count
                              Icon(Icons.thumb_up_alt_outlined,
                                size: 14, color: skin.colors.onGlassText2),
                              const SizedBox(width: 2),
                              Text('1',
                                style: AppTypography.footnote.copyWith(
                                  color: skin.colors.onGlassText2)),
                            ],
                          ),
                          ),
                          const SizedBox(height: 8),
                          // 音标
                          if (w.usPron.isNotEmpty || w.ukPron.isNotEmpty)
                            Row(
                              children: [
                                if (w.usPron.isNotEmpty) ...[
                                  _PhoneticPill(label: '美', skin: skin),
                                  const SizedBox(width: 4),
                                  Text(
                                    '/${w.usPron}/',
                                    style: AppTypography.phonetic,
                                  ),
                                ],
                                if (w.ukPron.isNotEmpty) ...[
                                  const SizedBox(width: 12),
                                  _PhoneticPill(label: '英', skin: skin),
                                  const SizedBox(width: 4),
                                  Text(
                                    '/${w.ukPron}/',
                                    style: AppTypography.phonetic,
                                  ),
                                ],
                              ],
                            ),
                          const SizedBox(height: 20),
                          // 释义
                          ...w.interpretLines.map(
                            (line) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text(
                                line,
                                style: AppTypography.body.copyWith(
                                  color: skin.colors.onGlassText1,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          // 例句卡
                          if (exs.isNotEmpty)
                            ...exs.take(2).map(
                              (ex) => _ExampleCard(example: ex, skin: skin),
                            ),
                          const SizedBox(height: 16),
                          // 派生词卡片（原版橙色三角标记 + 派生词列表）
                          _DerivedWordsCard(word: w.word, skin: skin),
                          const SizedBox(height: 16),
                        ],
                      ),
                    );
                  },
                ),
              ),
              // 1/3 page indicator
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: AnimatedBuilder(
                  animation: _pageController,
                  builder: (context, _) {
                    final page = _pageController.hasClients
                        ? (_pageController.page ?? state.currentIndex.toDouble())
                        : state.currentIndex.toDouble();
                    return _buildPageIndicator(skin, page, state.total);
                  },
                ),
              ),
              // SegmentTabs（原版 派生/词组搭配/词根/近义）
              _buildSegmentTabs(skin),
              // 底部按钮（原版 下一词 + 记错了 + 重学）— 弹性滑入动画
              SlideTransition(
                position: _bottomBarAnim,
                child: _buildBottomActions(skin, state),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 透明导航栏（原版 nav_transparent）
  Widget _buildNav(SkinSystem skin, LearningState state) {
    final word = state.currentWord;
    final isFav = word != null && state.isFavorite(word.word);
    final isMastered = word != null && state.isMastered(word.word);

    return Container(
      height: AppSpacing.navH,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_ios_new, size: 20, color: skin.colors.onGlassText1),
            onPressed: () => Navigator.pop(context),
          ),
          Text(
            '${state.currentIndex + 1}/${state.total}',
            style: AppTypography.caption.copyWith(color: skin.colors.onGlassText1),
          ),
          const Spacer(),
          // 撤销按钮（原版 ↩）
          IconButton(
            icon: Icon(Icons.undo, color: skin.colors.onGlassText2, size: 20),
            onPressed: () {},
          ),
          // 收藏（原版 star_border 按钮）
          IconButton(
            icon: Icon(
              isFav ? Icons.star : Icons.star_border,
              color: isFav ? skin.colors.vipGoldBg : skin.colors.onGlassText2,
              size: 20,
            ),
            tooltip: isFav ? '取消收藏' : '收藏',
            onPressed: word == null
                ? null
                : () async {
                    await state.toggleFavorite(word.word);
                    if (mounted) setState(() {});
                  },
          ),
          // abc 拼写按钮
          IconButton(
            icon: Text('abc',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: skin.colors.onGlassText2,
              )),
            onPressed: () {},
          ),
          // 熟（标记已掌握）
          IconButton(
            icon: Text('熟',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isMastered ? skin.colors.onGlassAccent : skin.colors.onGlassText2,
              )),
            tooltip: isMastered ? '取消掌握' : '标记已掌握',
            onPressed: word == null
                ? null
                : () async {
                    await state.toggleMastered(word.word);
                    if (mounted) setState(() {});
                  },
          ),
          // 更多按钮
          IconButton(
            icon: Icon(Icons.more_horiz, color: skin.colors.onGlassText2, size: 20),
            onPressed: () {},
          ),
        ],
      ),
    );
  }

  /// SegmentTabs（原版 word_tabs：派生/词组搭配/词根/近义）
  /// 下划线使用 Stack + AnimatedPositioned 实现平滑滑动过渡
  Widget _buildSegmentTabs(SkinSystem skin) {
    return Container(
      height: 36,
      margin: const EdgeInsets.symmetric(horizontal: 24),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tabWidth = constraints.maxWidth / _tabs.length;
          return Stack(
            children: [
              // Tab 标签行
              Row(
                children: List.generate(_tabs.length, (i) {
                  final on = i == _selectedTab;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedTab = i),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 200),
                            curve: standardCurve,
                            style: on
                                ? AppTypography.tabActive
                                : AppTypography.tabInactive,
                            child: Text(_tabs[i]),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
              // 滑动下划线指示器
              AnimatedPositioned(
                duration: const Duration(milliseconds: 250),
                curve: standardCurve,
                left: _selectedTab * tabWidth,
                bottom: 0,
                width: tabWidth,
                child: Center(
                  child: Container(
                    width: 24,
                    height: 2,
                    decoration: BoxDecoration(
                      color: skin.colors.onGlassAccent,
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// 1/3 page indicator (animated dot position)
  Widget _buildPageIndicator(SkinSystem skin, double page, int total) {
    if (total <= 1) return const SizedBox.shrink();
    return SizedBox(
      height: 16,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(total.clamp(0, 10), (i) {
          final distance = (page - i).abs();
          final isActive = distance < 0.5;
          final opacity = (1.0 - distance).clamp(0.3, 1.0);
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: isActive ? 16 : 6,
            height: 6,
            decoration: BoxDecoration(
              color: (isActive
                      ? skin.colors.onGlassAccent
                      : skin.colors.onGlassText2)
                  .withValues(alpha: opacity),
              borderRadius: BorderRadius.circular(3),
            ),
          );
        }),
      ),
    );
  }

  /// 底部单按钮「下一词」+ 绿色下划线（原版样式）
  Widget _buildBottomActions(SkinSystem skin, LearningState state) {
    return SlideTransition(
      position: _bottomBarAnim,
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
        child: Center(
          child: GestureDetector(
            onTap: () {
              state.rate(FsrsRating.good);
              if (_pageController.hasClients) {
                _pageController.animateToPage(
                  state.currentIndex,
                  duration: const Duration(milliseconds: 300),
                  curve: standardCurve,
                );
              }
              setState(() {});
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '下一词',
                  style: AppTypography.body.copyWith(
                    color: skin.colors.onGlassText1,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 4),
                // 绿色下划线（原版签名元素）
                Container(
                  width: 32,
                  height: 3,
                  decoration: BoxDecoration(
                    color: skin.colors.success,
                    borderRadius: BorderRadius.circular(1.5),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 添加音节分隔符（原版 in·stinct 风格）
  String _addSyllableSeparators(String word) {
    // 简单规则：在元音前插入中点（模拟音节分割）
    // 实际应用中应使用音节数据库
    if (word.length <= 4) return word;
    final vowels = 'aeiouAEIOU';
    final buffer = StringBuffer();
    int lastConsonantRun = 0;
    for (int i = 1; i < word.length - 1; i++) {
      if (vowels.contains(word[i]) && !vowels.contains(word[i - 1])) {
        if (i - lastConsonantRun >= 2) {
          buffer.write(word.substring(lastConsonantRun, i));
          buffer.write('·');
          lastConsonantRun = i;
        }
      }
    }
    buffer.write(word.substring(lastConsonantRun));
    return buffer.toString();
  }
}

/// 音标 Pill（原版美/英标签）
class _PhoneticPill extends StatelessWidget {
  final String label;
  final SkinSystem skin;
  const _PhoneticPill({required this.label, required this.skin});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: skin.colors.divider,
        borderRadius: BorderRadius.circular(AppRadius.control),
      ),
      child: Text(
        label,
        style: AppTypography.footnote.copyWith(color: skin.colors.onGlassText2),
      ),
    );
  }
}

/// 例句卡（原版 ExampleCard，奶油半透明底）
class _ExampleCard extends StatelessWidget {
  final ExampleSentence example;
  final SkinSystem skin;
  const _ExampleCard({required this.example, required this.skin});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        // 奶油半透明底（适配深色模式）
        color: skin.colors.cardBg.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              style: AppTypography.body.copyWith(
                color: skin.colors.text1,
                height: 1.5,
              ),
              children: example.highlightedParts
                  .map(
                    (p) => TextSpan(
                      text: p.text,
                      style: p.highlight
                          ? TextStyle(fontWeight: FontWeight.bold, color: skin.colors.teal)
                          : null,
                    ),
                  )
                  .toList(),
            ),
          ),
          if (example.cn.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              example.cn,
              style: AppTypography.caption.copyWith(color: skin.colors.text2),
            ),
          ],
          if (example.source.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                example.source,
                style: AppTypography.footnote.copyWith(color: skin.colors.text3),
              ),
            ),
        ],
      ),
    );
  }
}

/// 派生词卡片（原版橙色三角标记 + 派生词列表 + 查看详细解析）
class _DerivedWordsCard extends StatelessWidget {
  final String word;
  final SkinSystem skin;

  const _DerivedWordsCard({required this.word, required this.skin});

  @override
  Widget build(BuildContext context) {
    // 模拟派生词数据（实际应从 API 或本地数据库获取）
    final derivedWords = _getDerivedWords(word);

    if (derivedWords.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: skin.colors.cardBg.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题行：橙色三角 + "派生词"
          Row(
            children: [
              // 橙色三角标记
              CustomPaint(
                size: const Size(12, 12),
                painter: _OrangeTrianglePainter(color: skin.colors.accent),
              ),
              const SizedBox(width: 8),
              Text(
                '派生词',
                style: AppTypography.body.copyWith(
                  color: skin.colors.text1,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 派生词列表
          ...derivedWords.map((dw) => _DerivedWordItem(
            derivedWord: dw,
            skin: skin,
          )),
          const SizedBox(height: 12),
          // 查看详细解析链接
          GestureDetector(
            onTap: () {
              // TODO: 导航到详细解析页面
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('详细解析功能开发中...')),
              );
            },
            child: Row(
              children: [
                Text(
                  '查看详细解析',
                  style: AppTypography.caption.copyWith(
                    color: skin.colors.accent,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 12,
                  color: skin.colors.accent,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 获取派生词数据（模拟数据，实际应从 API 获取）
  List<DerivedWord> _getDerivedWords(String word) {
    // 常见派生词映射（示例）
    final Map<String, List<DerivedWord>> derivedMap = {
      'instinct': [
        DerivedWord(word: 'instinctive', partOfSpeech: 'adj.', meaning: '本能的；直觉的'),
        DerivedWord(word: 'instinctively', partOfSpeech: 'adv.', meaning: '本能地；直觉地'),
      ],
      'nature': [
        DerivedWord(word: 'natural', partOfSpeech: 'adj.', meaning: '自然的；天然的'),
        DerivedWord(word: 'naturally', partOfSpeech: 'adv.', meaning: '自然地'),
        DerivedWord(word: 'naturalize', partOfSpeech: 'v.', meaning: '使归化；使适应'),
      ],
      'create': [
        DerivedWord(word: 'creation', partOfSpeech: 'n.', meaning: '创造；创建'),
        DerivedWord(word: 'creative', partOfSpeech: 'adj.', meaning: '创造性的'),
        DerivedWord(word: 'creativity', partOfSpeech: 'n.', meaning: '创造力'),
        DerivedWord(word: 'creator', partOfSpeech: 'n.', meaning: '创造者'),
      ],
      'develop': [
        DerivedWord(word: 'development', partOfSpeech: 'n.', meaning: '发展；开发'),
        DerivedWord(word: 'developer', partOfSpeech: 'n.', meaning: '开发者'),
        DerivedWord(word: 'developing', partOfSpeech: 'adj.', meaning: '发展中的'),
        DerivedWord(word: 'developed', partOfSpeech: 'adj.', meaning: '发达的'),
      ],
    };

    return derivedMap[word.toLowerCase()] ?? [];
  }
}

/// 派生词数据模型
class DerivedWord {
  final String word;
  final String partOfSpeech;
  final String meaning;

  const DerivedWord({
    required this.word,
    required this.partOfSpeech,
    required this.meaning,
  });
}

/// 派生词条目组件
class _DerivedWordItem extends StatelessWidget {
  final DerivedWord derivedWord;
  final SkinSystem skin;

  const _DerivedWordItem({required this.derivedWord, required this.skin});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 单词
          SizedBox(
            width: 100,
            child: Text(
              derivedWord.word,
              style: AppTypography.body.copyWith(
                color: skin.colors.accent,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          // 词性
          SizedBox(
            width: 40,
            child: Text(
              derivedWord.partOfSpeech,
              style: AppTypography.caption.copyWith(
                color: skin.colors.text3,
              ),
            ),
          ),
          // 中文释义
          Expanded(
            child: Text(
              derivedWord.meaning,
              style: AppTypography.caption.copyWith(
                color: skin.colors.text1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 橙色三角标记绘制器
class _OrangeTrianglePainter extends CustomPainter {
  final Color color;
  _OrangeTrianglePainter({this.color = const Color(0xFF00754A)});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, size.height / 2)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
