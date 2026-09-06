import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import 'package:provider/provider.dart';

import 'package:word_app/models/word.dart';
import 'package:word_app/core/audio/audio_playback_state.dart';
import 'package:word_app/core/presentation/responsive.dart';
import 'package:word_app/theme/skin_system.dart';
import 'package:word_app/tokens/design_tokens.dart';
import 'package:word_app/widgets/mw_card.dart';
import 'package:word_app/widgets/mw_section_header.dart';
import 'package:word_app/widgets/word_root_tab.dart';
import 'package:word_app/features/dictionary/presentation/dictionary_detail_state.dart';
import 'package:word_app/features/dictionary/presentation/dictionary_feature_providers.dart';
import 'package:word_app/features/dictionary/presentation/word_detail/word_detail_exam_sentence_card.dart';
import 'package:word_app/features/dictionary/presentation/word_detail/word_detail_example_tile.dart';

/// 词典详情页 — 编辑式单页排版。
///
/// 设计原则（v2.7.61 重构）：
/// - 废除 6 标签页 + 360px 固定窗口的旧版式（嵌套滚动难翻、空标签占位），
///   改为单页连贯流：有数据的区块才出现，空区块整个消失，一次滚动看全。
/// - 桌面/手机同构：内容列由 [AppResponsive.contentMaxWidth] 约束，
///   宽屏自然居中成阅读版面。
/// - 展示数据源与交互（ExampleTile / ExamSentenceCard / WordRootTab /
///   派生·近义跳转）与旧版一致。
class DictionaryPage extends StatefulWidget {
  final Word word;
  const DictionaryPage({super.key, required this.word});

  static const routeName = '/dictionary';

  @override
  State<DictionaryPage> createState() => _DictionaryPageState();
}

class _DictionaryPageState extends State<DictionaryPage> {
  @override
  Widget build(BuildContext context) {
    // 根因修复（error_boundary.log 实锤 Provider<DictionaryDetailState> not found）：
    // 页面自挂载数据源，任何入口（路由/按名/跳转）都自洽。
    return buildDictionaryDetailScope(
      word: widget.word,
      child: Builder(builder: (context) => _buildPage(context)),
    );
  }

  Widget _buildPage(BuildContext context) {
    final skin = context.skin.colors;
    final resp = context.responsive;

    return Scaffold(
      backgroundColor: skin.pageBg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: resp.contentMaxWidth),
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: _buildTopBar(context, skin, widget.word)),
                SliverPadding(
                  padding: EdgeInsets.symmetric(horizontal: resp.pageMargin),
                  sliver: SliverList.list(
                    children: [
                      const SizedBox(height: 8),
                      _WordHero(word: widget.word, onPlayAudio: _playAudio),
                      const SizedBox(height: 24),
                      _buildBody(context, skin, widget.word),
                      const SizedBox(height: 48),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 正文：所有内容区块按阅读动线排序，空区块整个省略。
  Widget _buildBody(BuildContext context, ThemeVars skin, Word word) {
    return Consumer<DictionaryDetailState>(
      builder: (context, state, _) {
        final sections = <Widget>[
          if (state.definitions.isNotEmpty)
            _Section(
              title: '释义',
              child: _DefinitionList(state: state, skin: skin),
            ),
          if (state.collinsSenses.isNotEmpty)
            _Section(
              title: '柯林斯释义',
              child: _CollinsList(state: state, skin: skin, word: word),
            ),
          if (state.examExamples.isNotEmpty)
            _Section(
              title: '例句',
              child: Column(
                children: [
                  for (final ex in state.examExamples) ExampleTile(ex, context.skin, word: word.word, wordId: word.id),
                ],
              ),
            ),
          if (state.realExamSentences.isNotEmpty)
            _Section(
              title: '真题例句',
              child: Column(
                children: [
                  for (final item in state.realExamSentences)
                    ExamSentenceCard(sentence: item['sentence'] ?? '', source: item['source'] ?? ''),
                ],
              ),
            ),
          if (_hasRoots(word))
            _Section(
              title: '词根词缀',
              child: WordRootTab(wordRootJson: word.wordRoot),
            ),
          if (state.derivedWords.isNotEmpty)
            _Section(
              title: '派生词',
              child: Column(
                children: [
                  for (final w in state.derivedWords) _RelatedWordCard(word: w, skin: skin, onPlayAudio: _playAudio),
                ],
              ),
            ),
          if (state.synonyms.isNotEmpty)
            _Section(
              title: '近义词',
              child: Column(
                children: [for (final w in state.synonyms) _RelatedWordCard(word: w, skin: skin)],
              ),
            ),
        ];

        if (sections.isEmpty) {
          return _Section(
            title: '释义',
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.menu_book_outlined, size: 36, color: skin.text3.withValues(alpha: 0.6)),
                    const SizedBox(height: 12),
                    Text('这个词的扩展释义还没有收录', style: MwTypography.bodySm.copyWith(color: skin.text3)),
                  ],
                ),
              ),
            ),
          );
        }
        // 区块间以呼吸感分隔（编辑式版面：留白即层次）
        return Column(
          children: [
            for (var i = 0; i < sections.length; i++) ...[if (i > 0) const SizedBox(height: 28), sections[i]],
          ],
        );
      },
    );
  }

  bool _hasRoots(Word word) {
    final raw = word.wordRoot.trim();
    if (raw.isEmpty || raw == '{}' || raw == '[]' || raw == '[{}]') return false;
    return raw.contains('roots') || raw.contains('prefix') || raw.contains('suffix');
  }

  Widget _buildTopBar(BuildContext context, ThemeVars skin, Word word) {
    return Container(
      height: context.design.spacing.navH,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: skin.pageBg,
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
              '词典',
              style: MwTypography.heading5.copyWith(color: skin.text1, fontSize: 17, fontWeight: FontWeight.w600),
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
                      color: state.isNewWord ? MwColors.primary : skin.text3,
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
                      color: state.isFavorite ? MwColors.primary : skin.text3,
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

/// 词头：衬线大词 + 音标胶囊（点按即读）。
class _WordHero extends StatelessWidget {
  const _WordHero({required this.word, required this.onPlayAudio});

  final Word word;
  final ValueChanged<String> onPlayAudio;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin.colors;
    final resp = context.responsive;
    return Consumer<DictionaryDetailState>(
      builder: (context, state, _) {
        final phonetic = state.phonetic;
        final us = phonetic?.american ?? '';
        final uk = phonetic?.english ?? '';
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              word.word,
              style: TextStyle(
                fontFamily: 'Charter',
                fontSize: 40.0 * resp.fontScale,
                fontWeight: FontWeight.w400,
                letterSpacing: -0.8,
                height: 1.15,
                color: skin.text1,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (us.isNotEmpty)
                  _PhoneticChip(label: '美', phonetic: us, accent: skin.accent, onTap: () => onPlayAudio(word.word)),
                if (uk.isNotEmpty)
                  _PhoneticChip(label: '英', phonetic: uk, accent: skin.accent, onTap: () => onPlayAudio(word.word)),
                if (us.isEmpty && uk.isEmpty)
                  _PhoneticChip(label: '发音', phonetic: '', accent: skin.accent, onTap: () => onPlayAudio(word.word)),
              ],
            ),
          ],
        );
      },
    );
  }
}

/// 音标胶囊：词性标签 + 音标 + 喇叭，整体可点播放。
class _PhoneticChip extends StatelessWidget {
  const _PhoneticChip({required this.label, required this.phonetic, required this.accent, required this.onTap});

  final String label;
  final String phonetic;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: ShapeDecoration(
          color: skin.cardBg,
          shape: StadiumBorder(side: BorderSide(color: skin.divider)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: MwTypography.micro.copyWith(color: accent, fontWeight: FontWeight.w700),
            ),
            const SizedBox(width: 6),
            if (phonetic.isNotEmpty) Text('/$phonetic/', style: MwTypography.bodySm.copyWith(color: skin.text2)),
            const SizedBox(width: 6),
            Icon(Icons.volume_up_rounded, size: 15, color: accent),
          ],
        ),
      ),
    );
  }
}

/// 编辑式区块头：强调色小竖条 + 标题 + 延伸发丝线。
class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MwSectionHeader(title: title),
        const SizedBox(height: 14),
        child,
      ],
    );
  }
}

/// 结构化释义：词性徽标悬挂 + 义项列表（词性不再逐条断行）。
class _DefinitionList extends StatelessWidget {
  const _DefinitionList({required this.state, required this.skin});

  final DictionaryDetailState state;
  final ThemeVars skin;

  @override
  Widget build(BuildContext context) {
    final defs = state.definitions;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < defs.length; i++) ...[
          if (i > 0) const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (defs[i].partOfSpeech.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 2, right: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: skin.accent.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    defs[i].partOfSpeech,
                    style: MwTypography.micro.copyWith(color: skin.accent, fontWeight: FontWeight.w700),
                  ),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final d in defs[i].definitions)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(d, style: MwTypography.bodyMd.copyWith(color: skin.text1, height: 1.6)),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// 柯林斯释义：义项卡（英文定义 + 中文对译 + 用法 + 例句组）。
class _CollinsList extends StatelessWidget {
  const _CollinsList({required this.state, required this.skin, required this.word});

  final DictionaryDetailState state;
  final ThemeVars skin;
  final Word word;

  @override
  Widget build(BuildContext context) {
    final senses = state.collinsSenses;
    return Column(
      children: [
        for (var i = 0; i < senses.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: skin.cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: skin.divider, width: 0.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 义项序号：衬线数字，编辑感
                    SizedBox(
                      width: 22,
                      child: Text(
                        '${i + 1}',
                        style: TextStyle(
                          fontFamily: 'Charter',
                          fontSize: 17,
                          fontStyle: FontStyle.italic,
                          color: skin.accent,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (senses[i].enDef.isNotEmpty)
                            Text(senses[i].enDef, style: MwTypography.bodyMd.copyWith(color: skin.text1, height: 1.55)),
                          if (senses[i].cnDef.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(senses[i].cnDef, style: MwTypography.bodyMd.copyWith(color: skin.text2, height: 1.5)),
                          ],
                          if (senses[i].usage.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              senses[i].usage,
                              style: MwTypography.bodySm.copyWith(color: skin.text3, fontStyle: FontStyle.italic),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                if (senses[i].examples.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  ...senses[i].examples.map((ex) => ExampleTile(ex, context.skin, word: word.word, wordId: word.id)),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// 派生词/近义词卡：词头 + 首行释义 + 整卡跳转（跳转后即新词典页）。
class _RelatedWordCard extends StatelessWidget {
  const _RelatedWordCard({required this.word, required this.skin, this.onPlayAudio});

  final Word word;
  final ThemeVars skin;
  final ValueChanged<String>? onPlayAudio;

  @override
  Widget build(BuildContext context) {
    final firstInterp = word.firstInterpretLine;
    return MwCard(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DictionaryPage(word: word))),
      margin: const EdgeInsets.only(bottom: 10),
      borderRadius: 16,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    word.word,
                    style: MwTypography.bodyMd.copyWith(color: skin.text1, fontWeight: FontWeight.w600),
                  ),
                  if (word.usPron.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text('/${word.usPron}/', style: MwTypography.micro.copyWith(color: skin.text3)),
                  ],
                  if (firstInterp.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      firstInterp,
                      style: MwTypography.bodySm.copyWith(color: skin.text3),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (onPlayAudio != null && word.usPron.isNotEmpty) ...[
              GestureDetector(
                onTap: () => onPlayAudio!(word.word),
                child: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: skin.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(Icons.volume_up, color: skin.accent, size: 16),
                ),
              ),
              const SizedBox(width: 8),
            ],
            Icon(Icons.arrow_forward_ios, color: skin.text3, size: 14),
          ],
        ),
      ),
    );
  }
}
