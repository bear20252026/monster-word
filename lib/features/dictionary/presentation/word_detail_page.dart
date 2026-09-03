// 字典详情页：单词详解（释义+音标+例句+常见用法+词根+形近词+笔记）
// 从学习页答题后进入，看完后点击"下一词"返回学习
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:word_app/core/repositories/word_repository.dart';
import 'package:word_app/models/word.dart';
import 'package:word_app/core/infrastructure/app_preferences.dart';
import 'package:word_app/features/dictionary/data/dictionary_extra.dart';
import 'package:word_app/core/parsers/example_parser.dart';
import 'package:word_app/features/dictionary/presentation/word_detail/word_detail_exam_sentence_card.dart';
import 'package:word_app/features/dictionary/presentation/word_detail/word_detail_example_tile.dart';
import 'package:word_app/features/dictionary/presentation/word_detail/word_detail_fsrs.dart';
import 'package:word_app/features/dictionary/presentation/word_detail/word_detail_notes_section.dart';
import 'package:word_app/features/dictionary/presentation/word_detail/word_detail_phrases.dart';
import 'package:word_app/core/parsers/phrase_parser.dart';
import 'package:word_app/core/presentation/responsive.dart';
import 'package:word_app/core/engine/fsrs6_engine.dart' show FsrsRating;
import 'package:word_app/features/learning/application/review_schedule_reader.dart';
import 'package:word_app/features/learning/application/learning_session_reader.dart';
import 'package:word_app/features/learning/application/learning_session_starter.dart';
import 'package:word_app/core/audio/audio_playback_state.dart';
import 'package:word_app/theme/skin_system.dart';
import 'package:word_app/tokens/design_tokens.dart';
import 'package:word_app/widgets/box_reveal.dart';
import 'package:word_app/widgets/definition_view.dart';
import 'package:word_app/app/router/nav_utils.dart';
import 'package:word_app/widgets/word_root_tab.dart';

class WordDetailPage extends StatefulWidget {
  final bool fromLearn;
  const WordDetailPage({super.key, this.fromLearn = false});
  static const routeName = '/word_detail';

  @override
  State<WordDetailPage> createState() => _WordDetailPageState();
}

class _WordDetailPageState extends State<WordDetailPage> {
  DictionaryExtra? _extra; // 字典补充数据（派生词/近义词/真题）

  /// 解析要展示的单词：路由参数优先（从词书/收藏/列表点入时显示所点的词），
  /// 否则回退到当前学习词。修复此前所有入口都显示 currentWord 的问题。
  Word? _resolveTargetWord(LearningSessionReader? session) {
    final arg = ModalRoute.of(context)?.settings.arguments;
    if (arg is Word) return arg;
    // 尝试从会话中获取；深链场景若无参数且无会话则返回 null
    try {
      return session?.currentWord ?? context.read<LearningSessionReader>().currentWord;
    } catch (_) {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    // 延迟到首帧后执行，避免 initState 中调用 ModalRoute.of(context)（此时 element 尚未挂载）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadExtra();
      _ensureFullWord();
    });
  }

  /// 性能审计 P1：词书列表传入的 Word 为轻量对象（不含 example/phrase 等大字段）。
  /// 进入详情页后按需重查完整词，保证释义/例句/词根等内容完整展示。
  Word? _fullWord;

  Future<void> _ensureFullWord() async {
    final word = _resolveTargetWord(null);
    if (word == null || word.example.isNotEmpty) return; // 已是完整词
    try {
      final full = await context.read<WordRepository>().getWordByText(word.word);
      if (full != null && mounted) setState(() => _fullWord = full);
    } catch (e) {
      debugPrint('[WordDetail] 完整词重查失败: $e');
    }
  }

  Future<void> _loadExtra() async {
    final word = _resolveTargetWord(null);
    if (word == null) return;
    final extra = await DictionaryExtraStore.forWord(word.word);
    if (!mounted || extra == null || extra.isEmpty) return;
    setState(() => _extra = extra);
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final resp = context.responsive;
    final session = context.read<LearningSessionReader>();
    final sessionStarter = context.read<LearningSessionStarter>();
    context.watch<ReviewScheduleReader>();
    final word = _fullWord ?? _resolveTargetWord(session);

    if (word == null) {
      return Scaffold(
        backgroundColor: skin.colors.pageBg,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.search_off, size: 64, color: skin.colors.text3),
              SizedBox(height: 16),
              Text('未找到单词', style: MwTypography.heading5.copyWith(color: skin.colors.text1)),
              SizedBox(height: 8),
              Text('可能因参数缺失或数据异常', style: MwTypography.bodySm.copyWith(color: skin.colors.text3)),
              SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => NavUtils.safePop(context),
                icon: const Icon(Icons.arrow_back, size: 20),
                label: const Text('返回上一页'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: skin.colors.accent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final examples = ExampleParser.parse(word.example);
    final lines = word.hasStructuredDefinitions
        ? word.formattedDefinitions.split('\n').where((l) => l.trim().isNotEmpty).toList()
        : word.interpretLines;
    final confuseList = _parseConfuse(word.confuse);

    return PopScope(
      canPop: true,
      child: Scaffold(
        backgroundColor: skin.colors.pageBg,
        body: SafeArea(
          child: Column(
            children: [
              // 顶部导航
              Container(
                height: context.design.spacing.navH,
                padding: EdgeInsets.symmetric(horizontal: resp.horizontalPadding),
                decoration: BoxDecoration(
                  color: skin.colors.cardBg,
                  border: Border(bottom: BorderSide(color: skin.colors.divider, width: 0.5)),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                      color: skin.colors.text1,
                      tooltip: '返回',
                      onPressed: () => NavUtils.safePop(context),
                    ),
                    Text('单词详情', style: MwTypography.heading5.copyWith(color: skin.colors.text1)),
                  ],
                ),
              ),
              // 内容
              Expanded(
                child: resp.isDesktop
                    ? _buildDesktopLayout(word, skin, resp, examples, lines, confuseList)
                    : _buildMobileLayout(word, skin, resp, examples, lines, confuseList),
              ),
              // 底部操作栏：下一词按钮
              _buildBottomActionBar(context, skin, resp, sessionStarter),
            ],
          ),
        ),
      ),
    );
  }

  /// FSRS-6 记忆预测卡片（显示记忆状态、难度、下次复习时间）

  /// 底部操作栏：下一词按钮（推进学习进度）
  /// 仅从 LearnPage 进入时显示"下一词"，其他入口（收藏/搜索/字典）只显示"返回"
  Widget _buildBottomActionBar(
    BuildContext context,
    SkinSystem skin,
    AppResponsive resp,
    LearningSessionStarter session,
  ) {
    final fromLearnPage = widget.fromLearn;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: resp.horizontalPadding, vertical: 12),
      decoration: BoxDecoration(
        color: skin.colors.cardBg,
        border: Border(top: BorderSide(color: skin.colors.divider, width: 0.5)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: () {
              if (fromLearnPage) {
                // 从学习流程进入：记录评分并推进到下一个单词
                session.rate(FsrsRating.good);
                // 无论是否最后一词，均返回上一层（学习完成页 / 搜索列表等）；
                // goHome 仅在无上层路由时由 safePop 的 canPop 守卫自动降级
                NavUtils.safePop(context);
              } else {
                // 从其他入口进入：仅返回
                NavUtils.safePop(context);
              }
            },
            icon: Icon(fromLearnPage ? Icons.arrow_forward : Icons.arrow_back, size: 20),
            label: Text(fromLearnPage ? '下一词' : '返回'),
            style: ElevatedButton.styleFrom(
              backgroundColor: skin.colors.accent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopLayout(
    Word word,
    SkinSystem skin,
    AppResponsive resp,
    List<dynamic> examples,
    List<String> lines,
    List<String> confuseList,
  ) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(resp.pageMargin),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: resp.contentMaxWidth),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 左侧：单词 + 音标 + 发音
              Expanded(
                flex: 2,
                child: BoxReveal(
                  direction: BoxRevealDirection.top,
                  duration: const Duration(milliseconds: 400),
                  reveal: true,
                  child: _buildWordHeader(word, skin),
                ),
              ),
              SizedBox(width: resp.horizontalPadding),
              // 右侧：释义 + 例句 + 扩展
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 释义
                    if (lines.isNotEmpty) ...[
                      BoxReveal(
                        direction: BoxRevealDirection.left,
                        duration: const Duration(milliseconds: 350),
                        delay: const Duration(milliseconds: 100),
                        reveal: true,
                        child: Text('释义', style: MwTypography.heading5.copyWith(color: skin.colors.text2)),
                      ),
                      SizedBox(height: context.design.spacing.xs),
                      ...lines.map(
                        (line) => Padding(
                          padding: EdgeInsets.only(bottom: 6),
                          child: Text(line, style: MwTypography.bodyMd.copyWith(color: skin.colors.text1, height: 1.5)),
                        ),
                      ),
                    ],
                    // 例句
                    if (examples.isNotEmpty) ...[
                      SizedBox(height: context.design.spacing.lg),
                      BoxReveal(
                        direction: BoxRevealDirection.right,
                        duration: const Duration(milliseconds: 350),
                        delay: const Duration(milliseconds: 200),
                        reveal: true,
                        child: Text('例句', style: MwTypography.heading5.copyWith(color: skin.colors.text2)),
                      ),
                      SizedBox(height: context.design.spacing.xs),
                      ...examples.take(3).map((ex) => ExampleTile(ex, skin, word: word.word, wordId: word.id)),
                    ],
                    // FSRS-6 记忆预测卡片
                    SizedBox(height: context.design.spacing.lg),
                    FsrsPredictionCard(schedule: context.read<ReviewScheduleReader>(), word: word),
                    // 助记段落（按设置「助记顺序」重排；形近词/词根词缀受开关控制）
                    ..._buildMnemonicSections(word, skin, confuseList),
                    // 常见用法
                    SizedBox(height: context.design.spacing.lg),
                    Text('常见用法', style: MwTypography.heading5.copyWith(color: skin.colors.text2)),
                    SizedBox(height: context.design.spacing.xs),
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: skin.colors.pageBg,
                        borderRadius: BorderRadius.circular(context.design.radius.md),
                        border: Border.all(color: skin.colors.divider),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${word.word} — 详细用法', style: MwTypography.bodyMd.copyWith(color: skin.colors.text1)),
                          SizedBox(height: 4),
                          if (word.hasStructuredDefinitions)
                            DefinitionView(definitions: word.parsedDefinitions)
                          else
                            Text(
                              '释义: ${word.cleanInterpret}',
                              style: MwTypography.bodySm.copyWith(color: skin.colors.text3),
                            ),
                        ],
                      ),
                    ),
                    // 笔记区
                    SizedBox(height: context.design.spacing.lg),
                    WordNotesSection(word: word),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileLayout(
    Word word,
    SkinSystem skin,
    AppResponsive resp,
    List<dynamic> examples,
    List<String> lines,
    List<String> confuseList,
  ) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(resp.pageMargin),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 单词 + 音标 + 发音（BoxReveal 从上方揭示）
          BoxReveal(
            direction: BoxRevealDirection.top,
            duration: const Duration(milliseconds: 400),
            reveal: true,
            child: _buildWordHeader(word, skin),
          ),
          SizedBox(height: context.design.spacing.lg),
          // 释义（BoxReveal 从左侧揭示）
          if (lines.isNotEmpty) ...[
            BoxReveal(
              direction: BoxRevealDirection.left,
              duration: const Duration(milliseconds: 350),
              delay: const Duration(milliseconds: 100),
              reveal: true,
              child: Text('释义', style: MwTypography.heading5.copyWith(color: skin.colors.text2)),
            ),
            SizedBox(height: context.design.spacing.xs),
            ...lines.map(
              (line) => Padding(
                padding: EdgeInsets.only(bottom: 6),
                child: Text(line, style: MwTypography.bodyMd.copyWith(color: skin.colors.text1, height: 1.5)),
              ),
            ),
          ],
          // 例句（BoxReveal 从右侧揭示）
          if (examples.isNotEmpty) ...[
            SizedBox(height: context.design.spacing.lg),
            BoxReveal(
              direction: BoxRevealDirection.right,
              duration: const Duration(milliseconds: 350),
              delay: const Duration(milliseconds: 200),
              reveal: true,
              child: Text('例句', style: MwTypography.heading5.copyWith(color: skin.colors.text2)),
            ),
            SizedBox(height: context.design.spacing.xs),
            ...examples.take(3).map((ex) => ExampleTile(ex, skin, word: word.word, wordId: word.id)),
          ],
          // FSRS-6 记忆预测卡片
          SizedBox(height: context.design.spacing.lg),
          FsrsPredictionCard(schedule: context.read<ReviewScheduleReader>(), word: word),
          // 助记段落（按设置「助记顺序」重排；形近词/词根词缀受开关控制）
          ..._buildMnemonicSections(word, skin, confuseList),
          // 常见用法
          SizedBox(height: context.design.spacing.lg),
          Text('常见用法', style: MwTypography.heading5.copyWith(color: skin.colors.text2)),
          SizedBox(height: context.design.spacing.xs),
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: skin.colors.pageBg,
              borderRadius: BorderRadius.circular(context.design.radius.md),
              border: Border.all(color: skin.colors.divider),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${word.word} — 详细用法', style: MwTypography.bodyMd.copyWith(color: skin.colors.text1)),
                SizedBox(height: 4),
                Text(
                  '释义: ${word.hasStructuredDefinitions ? word.formattedDefinitions : word.cleanInterpret}',
                  style: MwTypography.bodySm.copyWith(color: skin.colors.text3),
                ),
              ],
            ),
          ),
          // 笔记区
          SizedBox(height: context.design.spacing.lg),
          WordNotesSection(word: word),
        ],
      ),
    );
  }

  // ===========================================================================
  // 助记段落：按设置页「助记顺序」重排；形近词(特殊变形)/词根词缀受开关控制
  // 段落名与 LearningPreferences.defaultMnemonicOrder 对应：
  // 派生词→拓展·派生词(含近义词/真题例句)、词组搭配→词组/搭配、
  // 特殊变形→形近词（showSimilarWords）、词根词缀→词根词缀（showRoots）。
  // ===========================================================================
  List<Widget> _buildMnemonicSections(Word word, SkinSystem skin, List<String> confuseList) {
    // 助记展示偏好：AppPreferences 单例直读（settings 与 dictionary 共享 key，
    // 键定义在 core 上提，避免跨功能 import；设置页修改后下次进入详情页生效）。
    final appPrefs = AppPreferences();
    final showSimilarWords = appPrefs.getBool(
      AppPreferences.showSimilarWordsKey,
      defaultValue: AppPreferences.defaultShowSimilarWords,
    );
    final showRoots = appPrefs.getBool(AppPreferences.showRootsKey, defaultValue: AppPreferences.defaultShowRoots);
    final segments = appPrefs
        .getString(AppPreferences.mnemonicOrderKey, defaultValue: AppPreferences.defaultMnemonicOrder)
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    final gap = SizedBox(height: context.design.spacing.lg);
    final gapSm = SizedBox(height: context.design.spacing.xs);

    final sections = <String, List<Widget>>{
      // 特殊变形（形近词）
      '特殊变形': [
        if (showSimilarWords && confuseList.isNotEmpty) ...[
          gap,
          Text('形近词', style: MwTypography.heading5.copyWith(color: skin.colors.text2)),
          gapSm,
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: confuseList
                .map(
                  (c) => Chip(
                    label: Text(c, style: MwTypography.bodySm.copyWith(color: skin.colors.text1)),
                    backgroundColor: skin.colors.pageBg,
                    side: BorderSide(color: skin.colors.divider),
                  ),
                )
                .toList(),
          ),
        ],
      ],
      // 派生词（拓展数据：派生词 + 近义词 + 真题例句）
      '派生词': [
        if (_extra != null) ...[
          gap,
          Text('拓展 · 派生词', style: MwTypography.heading5.copyWith(color: skin.colors.text2)),
          gapSm,
          ..._extra!.derivatives.map(
            (d) => Padding(
              padding: EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('· ', style: TextStyle(fontWeight: FontWeight.bold)),
                  Expanded(
                    child: Text(d, style: MwTypography.bodyMd.copyWith(color: skin.colors.text1, height: 1.5)),
                  ),
                ],
              ),
            ),
          ),
          gap,
          Text('近义词', style: MwTypography.heading5.copyWith(color: skin.colors.text2)),
          gapSm,
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _extra!.synonyms
                .map(
                  // v2.7.49：0.85 实色+白字 → 全 App 统一的 accent 0.12 淡底胶囊
                  (s) => Chip(
                    label: Text(s, style: MwTypography.bodySm.copyWith(color: skin.colors.accent)),
                    backgroundColor: skin.colors.accent.withValues(alpha: 0.12),
                    side: BorderSide.none,
                  ),
                )
                .toList(),
          ),
          if (_extra!.examSentences.isNotEmpty) ...[
            gap,
            Text('真题例句', style: MwTypography.heading5.copyWith(color: skin.colors.text2)),
            gapSm,
            ..._extra!.examSentences.map(
              // 单一事实来源（v2.7.49）：与词典页真题 tab 共用 ExamSentenceCard，
              // 收口此前两套真题卡样式（cardBgAlt/md 圆角/橙徽章在句上 → 统一卡）
              (e) => ExamSentenceCard(sentence: e.sentence, source: e.source),
            ),
          ],
        ],
      ],
      // 词组搭配
      '词组搭配': [
        if (PhraseParser.hasData(word.phrase)) ...[
          gap,
          Text('词组/搭配', style: MwTypography.heading5.copyWith(color: skin.colors.text2)),
          gapSm,
          PhraseGroupList(raw: word.phrase, skin: skin),
        ],
      ],
      // 词根词缀
      '词根词缀': [
        if (showRoots && word.wordRoot.isNotEmpty) ...[
          gap,
          Text('词根词缀', style: MwTypography.heading5.copyWith(color: skin.colors.text2)),
          gapSm,
          WordRootTab(wordRootJson: word.wordRoot),
        ],
      ],
    };

    // 按用户配置的助记顺序输出；未识别的段落名跳过。
    final out = <Widget>[];
    for (final segment in segments) {
      out.addAll(sections[segment] ?? const <Widget>[]);
    }
    return out;
  }

  // ===========================================================================
  // 笔记区
  // ===========================================================================

  Widget _buildWordHeader(dynamic word, SkinSystem skin) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: skin.colors.pageBg,
        borderRadius: BorderRadius.circular(context.design.radius.lg),
        border: Border.all(color: skin.colors.divider),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(word.word, style: MwTypography.heading1.copyWith(color: skin.colors.text1, fontSize: 40)),
              SizedBox(width: context.design.spacing.sm),
              Consumer<AudioPlaybackState>(
                builder: (context, player, _) {
                  if (player.isLoading && player.currentWord == word.word) {
                    return SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(strokeWidth: 2, color: skin.colors.accent),
                    );
                  }
                  return GestureDetector(
                    onTap: () async {
                      if (player.isLoading) return;
                      final messenger = ScaffoldMessenger.of(context);
                      try {
                        // 单词发音走有道 TTS；word.audioUrls 实为"例句音频 JSON 数组串"而非单词发音 URL，
                        // 传入会污染分支导致无声，故不传 audioUrl（回退到有道发音）。
                        await player.playWord(word.word);
                      } catch (e) {
                        if (mounted) {
                          messenger.showSnackBar(
                            const SnackBar(content: Text('发音加载失败，请检查网络'), duration: Duration(seconds: 2)),
                          );
                        }
                      }
                    },
                    child: Icon(Icons.volume_up_outlined, color: skin.colors.accent, size: 28),
                  );
                },
              ),
            ],
          ),
          if (word.usPron.isNotEmpty || word.ukPron.isNotEmpty) ...[
            SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (word.usPron.isNotEmpty)
                  Text('美 /${word.usPron}/  ', style: MwTypography.bodySm.copyWith(color: skin.colors.text3)),
                if (word.ukPron.isNotEmpty)
                  Text('英 /${word.ukPron}/', style: MwTypography.bodySm.copyWith(color: skin.colors.text3)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  List<String> _parseConfuse(String confuse) {
    final t = confuse.trim();
    if (t.isEmpty) return [];
    if (t.startsWith('[')) {
      return t
          .substring(1, t.length - 1)
          .split(',')
          .map((e) => e.trim().replaceAll('"', ''))
          .where((e) => e.isNotEmpty)
          .toList();
    }
    return [t];
  }

  @override
  void dispose() {
    super.dispose();
  }
}
