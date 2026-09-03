import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import 'package:provider/provider.dart';

import 'package:word_app/models/word.dart';
import 'package:word_app/core/audio/audio_playback_state.dart';
import 'package:word_app/theme/skin_system.dart';
import 'package:word_app/tokens/design_tokens.dart';
import 'package:word_app/widgets/word_root_tab.dart';
import 'package:word_app/features/dictionary/presentation/dictionary_detail_state.dart';
import 'package:word_app/features/dictionary/presentation/dictionary_feature_providers.dart';
import 'package:word_app/features/dictionary/presentation/word_detail/word_detail_example_tile.dart';

/// 词典详情页。
///
/// 展示单词的完整释义、音标、例句、派生、词根、近义词及真题。
/// 通过 [DictionaryDetailState] 获取数据与状态，
/// 支持收藏、加入生词本、播放发音等交互。
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
    // 根因修复（error_boundary.log 实锤 Provider<DictionaryDetailState> not found）：
    // buildDictionaryDetailScope 此前全工程零调用，页面所有 Consumer 均因缺 Provider
    // 构建即崩（"页面出错了"）。页面自挂载数据源，任何入口（路由/按名/跳转）都自洽。
    // 注意：scope 读取的四个端口由 app.dart 顶层 buildDictionaryFeatureScope 提供。
    return buildDictionaryDetailScope(
      word: widget.word,
      child: Builder(builder: (context) => _buildPage(context)),
    );
  }

  Widget _buildPage(BuildContext context) {
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
                padding: EdgeInsets.all(context.design.spacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildWordHeader(skin, word),
                    SizedBox(height: context.design.spacing.lg),
                    _buildPronunciation(skin, word),
                    SizedBox(height: context.design.spacing.lg),
                    _buildInterpretation(skin, word),
                    SizedBox(height: context.design.spacing.lg),
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
      height: context.design.spacing.navH,
      padding: EdgeInsets.symmetric(horizontal: 4),
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
          SizedBox(width: 4),
          Expanded(
            child: Text(
              '字典',
              style: MistralTypography.heading5.copyWith(color: skin.text1, fontSize: 17, fontWeight: FontWeight.w600),
            ),
          ),
          Consumer<DictionaryDetailState>(
            builder: (context, state, _) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(
                      state.isNewWord ? Icons.bookmark_added : Icons.bookmark_add_outlined,
                      color: state.isNewWord ? MistralColors.primary : skin.text3,
                      size: 24,
                    ),
                    tooltip: state.isNewWord ? '移出生词本' : '加入生词本',
                    onPressed: word.id <= 0
                        ? null
                        : () async {
                            final wasNew = state.isNewWord;
                            await state.toggleNewWord();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(SnackBar(content: Text(wasNew ? '已移出生词本' : '已加入生词本')));
                            }
                          },
                  ),
                  IconButton(
                    icon: Icon(
                      state.isFavorite ? Icons.star : Icons.star_border,
                      color: state.isFavorite ? MistralColors.primary : skin.text3,
                      size: 24,
                    ),
                    tooltip: state.isFavorite ? '取消收藏' : '收藏单词',
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      state.toggleFavorite();
                    },
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
              SizedBox(height: context.design.spacing.xs),
              _buildCETTags(skin),
            ],
          ),
        ),
        GestureDetector(
          onTap: () => _playAudio(word.word),
          child: Container(
            padding: EdgeInsets.all(context.design.spacing.sm),
            decoration: BoxDecoration(
              color: skin.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(context.design.radius.lg),
            ),
            child: Icon(Icons.volume_up, color: skin.accent, size: 24),
          ),
        ),
      ],
    );
  }

  Widget _buildCETTags(ThemeVars skin) {
    final wordLen = widget.word.word.length;
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
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(context.design.radius.sm),
      ),
      child: Text(
        text,
        style: MistralTypography.micro.copyWith(color: color, fontWeight: FontWeight.w600, fontSize: 11),
      ),
    );
  }

  Widget _buildPronunciation(ThemeVars skin, Word word) {
    return Consumer<DictionaryDetailState>(
      builder: (context, state, _) {
        final phonetic = state.phonetic;
        if (phonetic == null || (phonetic.american.isEmpty && phonetic.english.isEmpty)) {
          return const SizedBox.shrink();
        }
        final hasUs = phonetic.american.isNotEmpty;
        final hasUk = phonetic.english.isNotEmpty;
        return Container(
          padding: EdgeInsets.all(context.design.spacing.md),
          decoration: BoxDecoration(
            color: skin.cardBg,
            borderRadius: BorderRadius.circular(context.design.radius.xl),
            border: Border.all(color: skin.divider, width: 0.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (hasUs) _buildPronunciationRow('美式', '/${phonetic.american}/', skin),
              if (hasUs && hasUk) Divider(height: context.design.spacing.md + 2, thickness: 0.5, color: skin.divider),
              if (hasUk) _buildPronunciationRow('英式', '/${phonetic.english}/', skin),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPronunciationRow(String label, String phonetic, ThemeVars skin) {
    return Row(
      children: [
        Text(
          label,
          style: MistralTypography.bodySm.copyWith(color: skin.text3, fontWeight: FontWeight.w500),
        ),
        SizedBox(width: context.design.spacing.sm),
        Text(phonetic, style: MistralTypography.bodyMd.copyWith(color: skin.text1)),
      ],
    );
  }

  Widget _buildInterpretation(ThemeVars skin, Word word) {
    return Consumer<DictionaryDetailState>(
      builder: (context, state, _) {
        final defs = state.definitions;
        if (defs.isEmpty) return const SizedBox.shrink();
        return Container(
          width: double.infinity,
          padding: EdgeInsets.all(context.design.spacing.md),
          decoration: BoxDecoration(
            color: skin.cardBg,
            borderRadius: BorderRadius.circular(context.design.radius.xl),
            border: Border.all(color: skin.divider, width: 0.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '释义',
                style: MistralTypography.bodyMd.copyWith(color: skin.text1, fontWeight: FontWeight.w600),
              ),
              SizedBox(height: context.design.spacing.sm),
              ...defs.expand((item) sync* {
                if (item.partOfSpeech.isNotEmpty) {
                  yield Padding(
                    padding: EdgeInsets.only(top: context.design.spacing.xs, bottom: context.design.spacing.xs),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: skin.accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(context.design.radius.sm),
                      ),
                      child: Text(
                        item.partOfSpeech,
                        style: MistralTypography.bodySm.copyWith(color: skin.accent, fontWeight: FontWeight.w600),
                      ),
                    ),
                  );
                }
                for (final d in item.definitions) {
                  yield Padding(
                    padding: EdgeInsets.only(left: 2, bottom: context.design.spacing.sm),
                    child: Text(d, style: MistralTypography.bodyMd.copyWith(color: skin.text1, height: 1.5)),
                  );
                }
              }),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTabs(ThemeVars skin, Word word) {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: skin.cardBg,
            borderRadius: BorderRadius.circular(context.design.radius.xl),
            border: Border.all(color: skin.divider, width: 0.5),
          ),
          child: TabBar(
            controller: _tabController,
            isScrollable: true,
            dividerColor: Colors.transparent,
            labelColor: skin.accent,
            unselectedLabelColor: skin.text3,
            indicatorColor: skin.accent,
            indicatorWeight: 2.5,
            indicatorSize: TabBarIndicatorSize.label,
            indicatorPadding: EdgeInsets.only(bottom: 2),
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
        SizedBox(height: context.design.spacing.md),
        // 修复：本页整体位于 SingleChildScrollView 内（高度无界），
        // Expanded 在此非法、构建即崩（页面曾显示"页面出错了"）。
        // TabBarView 需要有界高度，改为固定高度（约 6 行内容，可滚动）。
        SizedBox(
          height: 360,
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
    return Consumer<DictionaryDetailState>(
      builder: (context, state, _) {
        // 柯林斯式结构化释义（v2.7.46 接入真数据）：释义 i + 用法说明 g.u +
        // 分组例句 g.s（ExampleTile 复用，与例句 tab 体验一致）。
        final senses = state.collinsSenses;
        if (senses.isEmpty) {
          return _emptyTab('暂无柯林斯释义', Icons.menu_book_outlined, skin);
        }
        return ListView.builder(
          padding: const EdgeInsets.only(top: 2),
          itemCount: senses.length,
          addAutomaticKeepAlives: false,
          addRepaintBoundaries: true,
          itemBuilder: (context, index) {
            final sense = senses[index];
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: EdgeInsets.all(context.design.spacing.md),
              decoration: BoxDecoration(
                color: skin.cardBg,
                borderRadius: BorderRadius.circular(context.design.radius.lg),
                border: Border.all(color: skin.divider, width: 0.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (sense.pos.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: skin.accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(context.design.radius.sm),
                      ),
                      child: Text(
                        sense.pos,
                        style: MistralTypography.bodySm.copyWith(color: skin.accent, fontWeight: FontWeight.w600),
                      ),
                    ),
                    SizedBox(height: context.design.spacing.xs),
                  ],
                  if (sense.enDef.isNotEmpty)
                    Text(sense.enDef, style: MistralTypography.bodyMd.copyWith(color: skin.text1, height: 1.5)),
                  if (sense.cnDef.isNotEmpty) ...[
                    SizedBox(height: context.design.spacing.xs),
                    Text(sense.cnDef, style: MistralTypography.bodySm.copyWith(color: skin.text3)),
                  ],
                  if (sense.usage.isNotEmpty) ...[
                    SizedBox(height: context.design.spacing.sm),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: skin.accent.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(context.design.radius.sm),
                      ),
                      child: Text(
                        sense.usage,
                        style: MistralTypography.bodySm.copyWith(color: skin.accent, fontStyle: FontStyle.italic),
                      ),
                    ),
                  ],
                  if (sense.examples.isNotEmpty) ...[
                    SizedBox(height: context.design.spacing.sm),
                    ...sense.examples.map((ex) => ExampleTile(ex, context.skin, word: word.word, wordId: word.id)),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// tab 区统一空状态：图标 + 文案居中，替代各处零散的纯文本占位。
  Widget _emptyTab(String message, IconData icon, ThemeVars skin) {
    return Container(
      padding: EdgeInsets.all(context.design.spacing.lg),
      decoration: BoxDecoration(
        color: skin.cardBg,
        borderRadius: BorderRadius.circular(context.design.radius.xl),
        border: Border.all(color: skin.divider, width: 0.5),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 32, color: skin.text3.withValues(alpha: 0.6)),
            SizedBox(height: context.design.spacing.sm),
            Text(message, style: MistralTypography.bodySm.copyWith(color: skin.text3)),
          ],
        ),
      ),
    );
  }

  Widget _buildExamplesTab(ThemeVars skin, Word word) {
    return Consumer<DictionaryDetailState>(
      builder: (context, state, _) {
        final examples = state.examExamples;
        if (examples.isEmpty) {
          return _emptyTab('暂无例句', Icons.format_quote_outlined, skin);
        }
        // 单一事实来源：直接复用 word_detail 的 ExampleTile（<b> 高亮 + 例句发音 +
        // 句收藏 + 来源标注），两详情页例句体验一致（v2.7.45 收口）。
        return ListView.builder(
          padding: const EdgeInsets.only(top: 2),
          itemCount: examples.length,
          addAutomaticKeepAlives: false,
          addRepaintBoundaries: true,
          itemBuilder: (context, index) {
            final ex = examples[index];
            return ExampleTile(ex, context.skin, word: word.word, wordId: word.id);
          },
        );
      },
    );
  }

  Widget _buildDerivativesTab(ThemeVars skin, Word word) {
    return Consumer<DictionaryDetailState>(
      builder: (context, state, _) {
        final derived = state.derivedWords;
        if (derived.isEmpty) {
          return Container(
            padding: EdgeInsets.all(context.design.spacing.md),
            decoration: BoxDecoration(
              color: skin.cardBg,
              borderRadius: BorderRadius.circular(context.design.radius.xl),
              border: Border.all(color: skin.divider, width: 0.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '派生词',
                  style: MistralTypography.bodyMd.copyWith(color: skin.text1, fontWeight: FontWeight.w600),
                ),
                SizedBox(height: context.design.spacing.sm),
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
                // 页面已自挂载 DetailScope：直接 push，新页为新单词创建全新状态
                // （旧写法 Provider.value 复用上一词的状态，导致新词头配旧词数据）
                Navigator.push(context, MaterialPageRoute(builder: (_) => DictionaryPage(word: w)));
              },
              child: Container(
                margin: EdgeInsets.only(bottom: context.design.spacing.sm),
                padding: EdgeInsets.all(context.design.spacing.md),
                decoration: BoxDecoration(
                  color: skin.cardBg,
                  borderRadius: BorderRadius.circular(context.design.radius.lg),
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
                            SizedBox(height: 2),
                            Text(w.usPron, style: MistralTypography.bodySm.copyWith(color: skin.text3)),
                          ],
                          if (firstInterp.isNotEmpty) ...[
                            SizedBox(height: 4),
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
    return Consumer<DictionaryDetailState>(
      builder: (context, state, _) {
        final synonyms = state.synonyms;
        if (synonyms.isEmpty) {
          return Container(
            padding: EdgeInsets.all(context.design.spacing.md),
            decoration: BoxDecoration(
              color: skin.cardBg,
              borderRadius: BorderRadius.circular(context.design.radius.xl),
              border: Border.all(color: skin.divider, width: 0.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '近义词',
                  style: MistralTypography.bodyMd.copyWith(color: skin.text1, fontWeight: FontWeight.w600),
                ),
                SizedBox(height: context.design.spacing.sm),
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
                // 同上：直接 push，新页自建全新状态
                Navigator.push(context, MaterialPageRoute(builder: (_) => DictionaryPage(word: synonym)));
              },
              child: Container(
                margin: EdgeInsets.only(bottom: context.design.spacing.sm),
                padding: EdgeInsets.all(context.design.spacing.md),
                decoration: BoxDecoration(
                  color: skin.cardBg,
                  borderRadius: BorderRadius.circular(context.design.radius.xl),
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
                            SizedBox(height: context.design.spacing.xs),
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
    return Consumer<DictionaryDetailState>(
      builder: (context, state, _) {
        // 真题数据源（v2.7.45 修复）：改读 dictionary_extra.json 的真题例句
        // （CET-4/CET-6/考研），不再与例句 tab 双写同一份数据。
        final sentences = state.realExamSentences;
        if (sentences.isEmpty) {
          return _emptyTab('暂无真题例句', Icons.school_outlined, skin);
        }
        return ListView.builder(
          padding: const EdgeInsets.only(top: 2),
          itemCount: sentences.length,
          addAutomaticKeepAlives: false,
          addRepaintBoundaries: true,
          itemBuilder: (context, index) {
            final item = sentences[index];
            final sentence = item['sentence'] ?? '';
            final source = item['source'] ?? '';
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: EdgeInsets.all(context.design.spacing.md),
              decoration: BoxDecoration(
                color: skin.cardBg,
                borderRadius: BorderRadius.circular(context.design.radius.lg),
                border: Border.all(color: skin.divider, width: 0.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(sentence, style: MistralTypography.bodyMd.copyWith(color: skin.text1, height: 1.5)),
                  if (source.isNotEmpty) ...[
                    SizedBox(height: context.design.spacing.sm),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: skin.accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(context.design.radius.sm),
                      ),
                      child: Text(
                        source,
                        style: MistralTypography.micro.copyWith(color: skin.accent, fontWeight: FontWeight.w600),
                      ),
                    ),
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
      await context.read<AudioPlaybackState>().playWord(word);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('发音加载失败，请检查网络'), duration: Duration(seconds: 2)));
      }
    }
  }
}
