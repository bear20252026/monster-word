// 由 Claude 团队生成 | Monster Word App
// 字典详情页：完整单词释义、柯林斯、例句、派生、词根、近义词

import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import '../data/example_parser.dart';
import '../features/learning/presentation/new_words_state.dart';
import '../features/player/presentation/audio_playback_state.dart';
import '../models/word.dart';
import '../services/dictionary_service.dart';
import '../features/learning/presentation/learning_favorites_state.dart';
import '../theme/skin_system.dart';
import '../tokens/design_tokens.dart';
import '../widgets/word_root_tab.dart';

class DictionaryPage extends StatefulWidget {
  final Word word;
  const DictionaryPage({super.key, required this.word});

  static const routeName = '/dictionary';

  @override
  State<DictionaryPage> createState() => _DictionaryPageState();
}

class _DictionaryPageState extends State<DictionaryPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin.colors;
    final word = widget.word;

    return Scaffold(
      backgroundColor: skin.pageBg,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(context, skin, word),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildWordHeader(skin, word),
                    const SizedBox(height: AppSpacing.lg),
                    _buildPronunciation(skin, word),
                    const SizedBox(height: AppSpacing.lg),
                    _buildInterpretation(skin, word),
                    const SizedBox(height: AppSpacing.lg),
                    _buildTabs(skin, word),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, ThemeVars skin, Word word) {
    return Container(
      height: AppSpacing.navH,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: skin.cardBg,
        border: Border(bottom: BorderSide(color: skin.divider, width: 0.5)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
            color: skin.text1,
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              '字典',
              style: MistralTypography.heading5.copyWith(color: skin.text1, fontSize: 17, fontWeight: FontWeight.w600),
            ),
          ),
          Consumer2<LearningFavoritesState, NewWordsState>(
            builder: (context, favorites, newWords, _) {
              final isFav = favorites.isFavorite(word.word);
              final isNewWord = newWords.isNewWord(word.id);
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(
                      isNewWord ? Icons.bookmark_added : Icons.bookmark_add_outlined,
                      color: isNewWord ? MistralColors.primary : skin.text3,
                      size: 24,
                    ),
                    tooltip: isNewWord ? '移出生词本' : '加入生词本',
                    onPressed: word.id <= 0
                        ? null
                        : () async {
                            final isAdded = await newWords.toggleNewWord(word, source: 'dictionary');
                            if (context.mounted) {
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(SnackBar(content: Text(isAdded ? '已加入生词本' : '已移出生词本')));
                            }
                          },
                  ),
                  IconButton(
                    icon: Icon(
                      isFav ? Icons.star : Icons.star_border,
                      color: isFav ? MistralColors.primary : skin.text3,
                      size: 24,
                    ),
                    onPressed: () => favorites.toggle(word.word),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildWordHeader(ThemeVars skin, Word word) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                word.word,
                style: MistralTypography.heading2.copyWith(color: skin.text1, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: AppSpacing.xs),
              _buildCETTags(skin),
            ],
          ),
        ),
        GestureDetector(
          onTap: () => _playAudio(word.word),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(color: skin.cardBgAlt, borderRadius: BorderRadius.circular(AppRadius.lg)),
            child: Icon(Icons.volume_up, color: skin.accent, size: 24),
          ),
        ),
      ],
    );
  }

  Widget _buildCETTags(ThemeVars skin) {
    // 根据单词长度简单分类（后续可从 Word 模型获取真实等级）
    final wordLen = widget.word.word?.length ?? 0;
    final label = wordLen <= 4
        ? '基础'
        : wordLen <= 8
        ? '核心'
        : '进阶';
    final color = wordLen <= 4
        ? MistralColors.success
        : wordLen <= 8
        ? skin.accent
        : MistralColors.warning;
    return Row(children: [_buildTag(label, color, skin)]);
  }

  Widget _buildTag(String text, Color color, ThemeVars skin) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        text,
        style: MistralTypography.micro.copyWith(color: color, fontWeight: FontWeight.w600, fontSize: 11),
      ),
    );
  }

  Widget _buildPronunciation(ThemeVars skin, Word word) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: skin.cardBg,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: skin.divider, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (word.usPron.isNotEmpty) _buildPronunciationRow('美式', '/${word.usPron}/', skin),
          if (word.ukPron.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            _buildPronunciationRow('英式', '/${word.ukPron}/', skin),
          ],
        ],
      ),
    );
  }

  Widget _buildPronunciationRow(String label, String phonetic, ThemeVars skin) {
    return Row(
      children: [
        Text(
          label,
          style: MistralTypography.bodySm.copyWith(color: skin.text3, fontWeight: FontWeight.w500),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(phonetic, style: MistralTypography.bodyMd.copyWith(color: skin.text1)),
      ],
    );
  }

  Widget _buildInterpretation(ThemeVars skin, Word word) {
    final lines = word.hasStructuredDefinitions
        ? word.formattedDefinitions.split('\n').where((l) => l.trim().isNotEmpty).toList()
        : word.interpretLines;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: skin.cardBg,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: skin.divider, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '释义',
            style: MistralTypography.bodyMd.copyWith(color: skin.text1, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpacing.sm),
          ...lines.map(
            (line) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Text(line, style: MistralTypography.bodyMd.copyWith(color: skin.text1, height: 1.5)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs(ThemeVars skin, Word word) {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: skin.cardBg,
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: Border.all(color: skin.divider, width: 0.5),
          ),
          child: TabBar(
            controller: _tabController,
            isScrollable: true,
            labelColor: skin.accent,
            unselectedLabelColor: skin.text3,
            indicatorColor: skin.accent,
            indicatorWeight: 2,
            indicatorSize: TabBarIndicatorSize.label,
            labelStyle: MistralTypography.bodySm.copyWith(fontWeight: FontWeight.w600),
            unselectedLabelStyle: MistralTypography.bodySm,
            tabs: const [
              Tab(text: '柯林斯'),
              Tab(text: '例句'),
              Tab(text: '派生'),
              Tab(text: '词根'),
              Tab(text: '近义'),
              Tab(text: '真题'),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildCollinsTab(skin, word),
              _buildExamplesTab(skin, word),
              _buildDerivativesTab(skin, word),
              _buildRootsTab(skin, word),
              _buildSynonymsTab(skin, word),
              _buildExamTab(skin, word),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCollinsTab(ThemeVars skin, Word word) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: skin.cardBg,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: skin.divider, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '柯林斯释义',
                  style: MistralTypography.bodyMd.copyWith(color: skin.text1, fontWeight: FontWeight.w600),
                ),
              ),
              IconButton(
                icon: Icon(Icons.refresh, size: 18, color: skin.text3),
                tooltip: '刷新',
                onPressed: () => setState(() {}),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text('暂无柯林斯释义数据', style: MistralTypography.bodyMd.copyWith(color: skin.text3)),
        ],
      ),
    );
  }

  Widget _buildExamplesTab(ThemeVars skin, Word word) {
    final examples = ExampleParser.parse(word.example);
    if (examples.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: skin.cardBg,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(color: skin.divider, width: 0.5),
        ),
        child: Center(
          child: Text('暂无例句数据', style: MistralTypography.bodyMd.copyWith(color: skin.text3)),
        ),
      );
    }

    return ListView.builder(
      itemCount: examples.length,
      addAutomaticKeepAlives: false,
      addRepaintBoundaries: true,
      itemBuilder: (context, index) {
        final ex = examples[index];
        return Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: skin.cardBg,
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: Border.all(color: skin.divider, width: 0.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RichText(
                text: TextSpan(
                  style: MistralTypography.bodyMd.copyWith(color: skin.text1, height: 1.5),
                  children: ex.highlightedParts
                      .map(
                        (p) => TextSpan(
                          text: p.text,
                          style: p.highlight ? TextStyle(fontWeight: FontWeight.bold, color: skin.accent) : null,
                        ),
                      )
                      .toList(),
                ),
              ),
              if (ex.cn.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(ex.cn, style: MistralTypography.bodySm.copyWith(color: skin.text3)),
              ],
              if (ex.source.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(ex.source, style: MistralTypography.micro.copyWith(color: skin.text3)),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildDerivativesTab(ThemeVars skin, Word word) {
    return FutureBuilder<List<Word>>(
      future: DictionaryService.instance.getDerivedWords(word.word),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: skin.cardBg,
              borderRadius: BorderRadius.circular(AppRadius.xl),
              border: Border.all(color: skin.divider, width: 0.5),
            ),
            child: const Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: skin.cardBg,
              borderRadius: BorderRadius.circular(AppRadius.xl),
              border: Border.all(color: skin.divider, width: 0.5),
            ),
            child: Center(
              child: Text('加载失败', style: TextStyle(color: skin.text3)),
            ),
          );
        }

        final derived = snapshot.data ?? [];
        if (derived.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: skin.cardBg,
              borderRadius: BorderRadius.circular(AppRadius.xl),
              border: Border.all(color: skin.divider, width: 0.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '派生词',
                  style: MistralTypography.bodyMd.copyWith(color: skin.text1, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text('暂无派生词', style: MistralTypography.bodyMd.copyWith(color: skin.text3)),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: derived.length,
          addAutomaticKeepAlives: false,
          addRepaintBoundaries: true,
          itemBuilder: (context, index) {
            final w = derived[index];
            final firstInterp = w.firstInterpretLine;
            return GestureDetector(
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => DictionaryPage(word: w)));
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: skin.cardBg,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: skin.divider, width: 0.5),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            w.word,
                            style: MistralTypography.bodyMd.copyWith(color: skin.text1, fontWeight: FontWeight.w600),
                          ),
                          if (w.usPron.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(w.usPron, style: MistralTypography.bodySm.copyWith(color: skin.text3)),
                          ],
                          if (firstInterp.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              firstInterp,
                              style: MistralTypography.bodySm.copyWith(color: skin.text3),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    Icon(Icons.arrow_forward_ios, color: skin.text3, size: 14),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildRootsTab(ThemeVars skin, Word word) {
    return WordRootTab(wordRootJson: word.wordRoot);
  }

  Widget _buildSynonymsTab(ThemeVars skin, Word word) {
    return FutureBuilder<List<Word>>(
      future: DictionaryService.instance.getSynonyms(word.word),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: skin.cardBg,
              borderRadius: BorderRadius.circular(AppRadius.xl),
              border: Border.all(color: skin.divider, width: 0.5),
            ),
            child: const Center(child: CircularProgressIndicator(color: MistralColors.white54)),
          );
        }

        if (snapshot.hasError) {
          return Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: skin.cardBg,
              borderRadius: BorderRadius.circular(AppRadius.xl),
              border: Border.all(color: skin.divider, width: 0.5),
            ),
            child: Center(
              child: Text('加载失败', style: TextStyle(color: skin.text3)),
            ),
          );
        }

        final synonyms = snapshot.data ?? [];
        if (synonyms.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: skin.cardBg,
              borderRadius: BorderRadius.circular(AppRadius.xl),
              border: Border.all(color: skin.divider, width: 0.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '近义词',
                  style: MistralTypography.bodyMd.copyWith(color: skin.text1, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text('暂无近义词数据', style: MistralTypography.bodyMd.copyWith(color: skin.text3)),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: synonyms.length,
          addAutomaticKeepAlives: false,
          addRepaintBoundaries: true,
          itemBuilder: (context, index) {
            final synonym = synonyms[index];
            final firstInterpret = synonym.firstInterpretLine;
            return GestureDetector(
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => DictionaryPage(word: synonym)));
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: skin.cardBg,
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                  border: Border.all(color: skin.divider, width: 0.5),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            synonym.word,
                            style: MistralTypography.bodyMd.copyWith(color: skin.text1, fontWeight: FontWeight.w600),
                          ),
                          if (firstInterpret.isNotEmpty) ...[
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              firstInterpret,
                              style: MistralTypography.bodySm.copyWith(color: skin.text3),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    Icon(Icons.arrow_forward_ios, color: skin.text3, size: 14),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildExamTab(ThemeVars skin, Word word) {
    return FutureBuilder<List<Map<String, String>>>(
      future: DictionaryService.instance.getExamExamples(word.word),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: skin.cardBg,
              borderRadius: BorderRadius.circular(AppRadius.xl),
              border: Border.all(color: skin.divider, width: 0.5),
            ),
            child: const Center(child: CircularProgressIndicator()),
          );
        }

        final examples = snapshot.data ?? [];
        if (examples.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: skin.cardBg,
              borderRadius: BorderRadius.circular(AppRadius.xl),
              border: Border.all(color: skin.divider, width: 0.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '真题例句',
                  style: MistralTypography.bodyMd.copyWith(color: skin.text1, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text('暂无真题例句', style: MistralTypography.bodyMd.copyWith(color: skin.text3)),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: examples.length,
          addAutomaticKeepAlives: false,
          addRepaintBoundaries: true,
          itemBuilder: (context, index) {
            final ex = examples[index];
            return Container(
              margin: const EdgeInsets.only(bottom: AppSpacing.sm),
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: skin.cardBg,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: skin.divider, width: 0.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(ex['sentence'] ?? '', style: MistralTypography.bodyMd.copyWith(color: skin.text1, height: 1.5)),
                  if ((ex['translation'] ?? '').isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(ex['translation']!, style: MistralTypography.bodySm.copyWith(color: skin.text3)),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _playAudio(String word) async {
    try {
      // 通过播放器功能域播放音频
      await context.read<AudioPlaybackState>().playWord(word);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('发音加载失败，请检查网络'), duration: Duration(seconds: 2)));
      }
    }
  }
}
