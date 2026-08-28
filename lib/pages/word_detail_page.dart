// 字典详情页：单词详解（释义+音标+例句+常见用法+词根+形近词+笔记）
// 从学习页答题后进入，看完后点击"下一词"返回学习
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/dictionary_extra.dart';
import '../data/example_parser.dart';
import '../data/phrase_parser.dart';
import '../hooks/responsive.dart';
import '../engine/fsrs6_engine.dart' show FsrsRating;
import '../features/learning/application/review_schedule_reader.dart';
import '../features/learning/presentation/learning_session_state.dart';
import '../core/audio/audio_playback_state.dart';
import '../features/word_browse/application/sentence_favorites_store.dart';
import '../features/word_browse/application/word_notes_store.dart';
import '../models/word.dart';
import '../models/word_note.dart';
import '../theme/skin_system.dart';
import '../tokens/design_tokens.dart';
import '../widgets/sb_card.dart';
import '../widgets/text_generate_effect.dart';
import '../widgets/box_reveal.dart';
import '../widgets/definition_view.dart';
import '../core/router/nav_utils.dart';
import '../widgets/word_root_tab.dart';

class WordDetailPage extends StatefulWidget {
  final bool fromLearn;
  const WordDetailPage({super.key, this.fromLearn = false});
  static const routeName = '/word_detail';

  @override
  State<WordDetailPage> createState() => _WordDetailPageState();
}

class _WordDetailPageState extends State<WordDetailPage> {
  List<WordNote> _notes = [];
  bool _notesLoaded = false;
  DictionaryExtra? _extra; // 字典补充数据（派生词/近义词/真题）

  /// 解析要展示的单词：路由参数优先（从词书/收藏/列表点入时显示所点的词），
  /// 否则回退到当前学习词。修复此前所有入口都显示 currentWord 的问题。
  Word? _resolveTargetWord(LearningSessionState? session) {
    final arg = ModalRoute.of(context)?.settings.arguments;
    if (arg is Word) return arg;
    // 尝试从会话中获取；深链场景若无参数且无会话则返回 null
    try {
      return session?.currentWord ?? context.read<LearningSessionState>().currentWord;
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
      _loadNotes();
      _loadExtra();
    });
  }

  Future<void> _loadExtra() async {
    final word = _resolveTargetWord(null);
    if (word == null) return;
    final extra = await DictionaryExtraStore.forWord(word.word);
    if (!mounted || extra == null || extra.isEmpty) return;
    setState(() => _extra = extra);
  }

  Future<void> _loadNotes() async {
    final word = _resolveTargetWord(null);
    if (word == null) return;

    try {
      final notes = await context.read<WordNotesStore>().listForWord(word.id);
      if (mounted) {
        setState(() {
          _notes = notes;
          _notesLoaded = true;
        });
      }
    } catch (e) {
      debugPrint('Notes loading error: $e');
      if (mounted) setState(() => _notesLoaded = true);
    }
  }

  Future<void> _addNote() async {
    final word = _resolveTargetWord(null);
    if (word == null) return;

    final store = context.read<WordNotesStore>();
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => _NoteDialog(controller: controller, title: '添加笔记'),
    );
    if (result != null && result.trim().isNotEmpty) {
      final note = WordNote(wordId: word.id, word: word.word, content: result.trim());
      await store.add(note);
      await _loadNotes();
    }
  }

  Future<void> _editNote(WordNote note) async {
    final store = context.read<WordNotesStore>();
    final controller = TextEditingController(text: note.content);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => _NoteDialog(controller: controller, title: '编辑笔记'),
    );
    if (result != null && result.trim().isNotEmpty) {
      await store.update(note.copyWith(content: result.trim()));
      await _loadNotes();
    }
  }

  Future<void> _deleteNote(WordNote note) async {
    final store = context.read<WordNotesStore>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除笔记'),
        content: const Text('确定要删除这条笔记吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('删除')),
        ],
      ),
    );
    if (confirmed == true) {
      await store.deleteById(note.id!);
      await _loadNotes();
    }
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final resp = context.responsive;
    final session = context.watch<LearningSessionState>();
    context.watch<ReviewScheduleReader>();
    final word = _resolveTargetWord(session);

    if (word == null) {
      return Scaffold(
        backgroundColor: skin.colors.pageBg,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.search_off, size: 64, color: skin.colors.text3),
              const SizedBox(height: 16),
              Text('未找到单词', style: MistralTypography.heading5.copyWith(color: skin.colors.text1)),
              const SizedBox(height: 8),
              Text('可能因参数缺失或数据异常', style: MistralTypography.bodySm.copyWith(color: skin.colors.text3)),
              const SizedBox(height: 24),
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
                height: AppSpacing.navH,
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
                    Text('单词详情', style: MistralTypography.heading5.copyWith(color: skin.colors.text1)),
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
              _buildBottomActionBar(context, skin, resp, session),
            ],
          ),
        ),
      ),
    );
  }

  /// FSRS-6 记忆预测卡片（显示记忆状态、难度、下次复习时间）
  Widget _buildFsrsPredictionCard(BuildContext context, ReviewScheduleReader schedule, Word word) {
    final skin = context.skin;
    final card = schedule.cardFor(word.word);
    if (card == null || card.isNew) {
      return SbCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.psychology_outlined, color: skin.colors.accent, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text('新词 — 开始学习后将生成记忆预测', style: MistralTypography.bodyMd.copyWith(color: skin.colors.text2)),
            ),
          ],
        ),
      );
    }
    final prediction = schedule.cardFor(word.word);
    if (prediction == null) return const SizedBox.shrink();
    final r = prediction.stability;
    final statusColor = r < 3
        ? Colors.red
        : r < 7
        ? Colors.orange
        : r < 14
        ? Colors.blue
        : Colors.green;
    return SbCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.psychology_outlined, color: skin.colors.accent, size: 20),
              const SizedBox(width: 8),
              Text('记忆预测', style: MistralTypography.heading5.copyWith(color: skin.colors.text1)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  r < 3
                      ? '即将遗忘'
                      : r < 7
                      ? '模糊'
                      : r < 14
                      ? '一般'
                      : '牢固',
                  style: MistralTypography.caption.copyWith(color: statusColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _FsrsStat(label: '难度', value: prediction.difficulty.toStringAsFixed(1)),
              const SizedBox(width: 16),
              _FsrsStat(label: '稳定性', value: '${prediction.stability.toStringAsFixed(1)} 天'),
              const SizedBox(width: 16),
              _FsrsStat(label: '复习次数', value: '${prediction.reviewCount}'),
            ],
          ),
        ],
      ),
    );
  }

  /// 底部操作栏：下一词按钮（推进学习进度）
  /// 仅从 LearnPage 进入时显示"下一词"，其他入口（收藏/搜索/字典）只显示"返回"
  Widget _buildBottomActionBar(
    BuildContext context,
    SkinSystem skin,
    AppResponsive resp,
    LearningSessionState session,
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
                        child: Text('释义', style: MistralTypography.heading5.copyWith(color: skin.colors.text2)),
                      ),
                      SizedBox(height: AppleSpacing.xs),
                      ...lines.map(
                        (line) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text(
                            line,
                            style: MistralTypography.bodyMd.copyWith(color: skin.colors.text1, height: 1.5),
                          ),
                        ),
                      ),
                    ],
                    // 例句
                    if (examples.isNotEmpty) ...[
                      SizedBox(height: AppleSpacing.lg),
                      BoxReveal(
                        direction: BoxRevealDirection.right,
                        duration: const Duration(milliseconds: 350),
                        delay: const Duration(milliseconds: 200),
                        reveal: true,
                        child: Text('例句', style: MistralTypography.heading5.copyWith(color: skin.colors.text2)),
                      ),
                      SizedBox(height: AppleSpacing.xs),
                      ...examples.take(3).map((ex) => _ExampleTile(ex, skin, word: word.word, wordId: word.id)),
                    ],
                    // FSRS-6 记忆预测卡片
                    SizedBox(height: AppleSpacing.lg),
                    _buildFsrsPredictionCard(context, context.read<ReviewScheduleReader>(), word),
                    // 形近词
                    if (confuseList.isNotEmpty) ...[
                      SizedBox(height: AppleSpacing.lg),
                      Text('形近词', style: MistralTypography.heading5.copyWith(color: skin.colors.text2)),
                      SizedBox(height: AppleSpacing.xs),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: confuseList
                            .map(
                              (c) => Chip(
                                label: Text(c, style: MistralTypography.bodySm.copyWith(color: skin.colors.text1)),
                                backgroundColor: skin.colors.pageBg,
                                side: BorderSide(color: skin.colors.divider),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                    // 补充数据
                    if (_extra != null) ...[
                      SizedBox(height: AppleSpacing.lg),
                      Text('拓展 · 派生词', style: MistralTypography.heading5.copyWith(color: skin.colors.text2)),
                      SizedBox(height: AppleSpacing.xs),
                      ..._extra!.derivatives.map(
                        (d) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('· ', style: TextStyle(fontWeight: FontWeight.bold)),
                              Expanded(
                                child: Text(
                                  d,
                                  style: MistralTypography.bodyMd.copyWith(color: skin.colors.text1, height: 1.5),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: AppleSpacing.lg),
                      Text('近义词', style: MistralTypography.heading5.copyWith(color: skin.colors.text2)),
                      SizedBox(height: AppleSpacing.xs),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _extra!.synonyms
                            .map(
                              (s) => Chip(
                                label: Text(s, style: MistralTypography.bodySm.copyWith(color: AppColors.white100)),
                                backgroundColor: skin.colors.accent.withValues(alpha: 0.85),
                                side: BorderSide.none,
                              ),
                            )
                            .toList(),
                      ),
                      if (_extra!.examSentences.isNotEmpty) ...[
                        SizedBox(height: AppleSpacing.lg),
                        Text('真题例句', style: MistralTypography.heading5.copyWith(color: skin.colors.text2)),
                        SizedBox(height: AppleSpacing.xs),
                        ..._extra!.examSentences.map(
                          (e) => Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: skin.colors.cardBgAlt,
                              borderRadius: BorderRadius.circular(AppRadius.md),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: AppColors.highlightOrange,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        e.source,
                                        style: MistralTypography.caption.copyWith(color: AppColors.white100),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  e.sentence,
                                  style: MistralTypography.bodyMd.copyWith(color: skin.colors.text1, height: 1.5),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                    // 常见用法
                    SizedBox(height: AppleSpacing.lg),
                    Text('常见用法', style: MistralTypography.heading5.copyWith(color: skin.colors.text2)),
                    SizedBox(height: AppleSpacing.xs),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: skin.colors.pageBg,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(color: skin.colors.divider),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${word.word} — 详细用法',
                            style: MistralTypography.bodyMd.copyWith(color: skin.colors.text1),
                          ),
                          const SizedBox(height: 4),
                          if (word.hasStructuredDefinitions)
                            DefinitionView(definitions: word.parsedDefinitions)
                          else
                            Text(
                              '释义: ${word.cleanInterpret}',
                              style: MistralTypography.bodySm.copyWith(color: skin.colors.text3),
                            ),
                        ],
                      ),
                    ),
                    // 词组/搭配（结构化展示）
                    if (PhraseParser.hasData(word.phrase)) ...[
                      SizedBox(height: AppleSpacing.lg),
                      Text('词组/搭配', style: MistralTypography.heading5.copyWith(color: skin.colors.text2)),
                      SizedBox(height: AppleSpacing.xs),
                      _PhraseGroupList(raw: word.phrase, skin: skin),
                    ],
                    // 词根词缀
                    if (word.wordRoot.isNotEmpty) ...[
                      SizedBox(height: AppleSpacing.lg),
                      Text('词根词缀', style: MistralTypography.heading5.copyWith(color: skin.colors.text2)),
                      SizedBox(height: AppleSpacing.xs),
                      WordRootTab(wordRootJson: word.wordRoot),
                    ],
                    // 笔记区
                    SizedBox(height: AppleSpacing.lg),
                    _buildNotesSection(skin),
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
          SizedBox(height: AppleSpacing.lg),
          // 释义（BoxReveal 从左侧揭示）
          if (lines.isNotEmpty) ...[
            BoxReveal(
              direction: BoxRevealDirection.left,
              duration: const Duration(milliseconds: 350),
              delay: const Duration(milliseconds: 100),
              reveal: true,
              child: Text('释义', style: MistralTypography.heading5.copyWith(color: skin.colors.text2)),
            ),
            SizedBox(height: AppleSpacing.xs),
            ...lines.map(
              (line) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(line, style: MistralTypography.bodyMd.copyWith(color: skin.colors.text1, height: 1.5)),
              ),
            ),
          ],
          // 例句（BoxReveal 从右侧揭示）
          if (examples.isNotEmpty) ...[
            SizedBox(height: AppleSpacing.lg),
            BoxReveal(
              direction: BoxRevealDirection.right,
              duration: const Duration(milliseconds: 350),
              delay: const Duration(milliseconds: 200),
              reveal: true,
              child: Text('例句', style: MistralTypography.heading5.copyWith(color: skin.colors.text2)),
            ),
            SizedBox(height: AppleSpacing.xs),
            ...examples.take(3).map((ex) => _ExampleTile(ex, skin, word: word.word, wordId: word.id)),
          ],
          // FSRS-6 记忆预测卡片
          SizedBox(height: AppleSpacing.lg),
          _buildFsrsPredictionCard(context, context.read<ReviewScheduleReader>(), word),
          // 形近词
          if (confuseList.isNotEmpty) ...[
            SizedBox(height: AppleSpacing.lg),
            Text('形近词', style: MistralTypography.heading5.copyWith(color: skin.colors.text2)),
            SizedBox(height: AppleSpacing.xs),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: confuseList
                  .map(
                    (c) => Chip(
                      label: Text(c, style: MistralTypography.bodySm.copyWith(color: skin.colors.text1)),
                      backgroundColor: skin.colors.pageBg,
                      side: BorderSide(color: skin.colors.divider),
                    ),
                  )
                  .toList(),
            ),
          ],
          // 补充数据
          if (_extra != null) ...[
            SizedBox(height: AppleSpacing.lg),
            Text('拓展 · 派生词', style: MistralTypography.heading5.copyWith(color: skin.colors.text2)),
            SizedBox(height: AppleSpacing.xs),
            ..._extra!.derivatives.map(
              (d) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('· ', style: TextStyle(fontWeight: FontWeight.bold)),
                    Expanded(
                      child: Text(d, style: MistralTypography.bodyMd.copyWith(color: skin.colors.text1, height: 1.5)),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: AppleSpacing.lg),
            Text('近义词', style: MistralTypography.heading5.copyWith(color: skin.colors.text2)),
            SizedBox(height: AppleSpacing.xs),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _extra!.synonyms
                  .map(
                    (s) => Chip(
                      label: Text(s, style: MistralTypography.bodySm.copyWith(color: AppColors.white100)),
                      backgroundColor: skin.colors.accent.withValues(alpha: 0.85),
                      side: BorderSide.none,
                    ),
                  )
                  .toList(),
            ),
            if (_extra!.examSentences.isNotEmpty) ...[
              SizedBox(height: AppleSpacing.lg),
              Text('真题例句', style: MistralTypography.heading5.copyWith(color: skin.colors.text2)),
              SizedBox(height: AppleSpacing.xs),
              ..._extra!.examSentences.map(
                (e) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: skin.colors.cardBgAlt,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppColors.highlightOrange,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(e.source, style: MistralTypography.caption.copyWith(color: AppColors.white100)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(e.sentence, style: MistralTypography.bodyMd.copyWith(color: skin.colors.text1, height: 1.5)),
                    ],
                  ),
                ),
              ),
            ],
          ],
          // 常见用法
          SizedBox(height: AppleSpacing.lg),
          Text('常见用法', style: MistralTypography.heading5.copyWith(color: skin.colors.text2)),
          SizedBox(height: AppleSpacing.xs),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: skin.colors.pageBg,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: skin.colors.divider),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${word.word} — 详细用法', style: MistralTypography.bodyMd.copyWith(color: skin.colors.text1)),
                const SizedBox(height: 4),
                Text(
                  '释义: ${word.hasStructuredDefinitions ? word.formattedDefinitions : word.cleanInterpret}',
                  style: MistralTypography.bodySm.copyWith(color: skin.colors.text3),
                ),
              ],
            ),
          ),
          // 词组/搭配（结构化展示）
          if (PhraseParser.hasData(word.phrase)) ...[
            SizedBox(height: AppleSpacing.lg),
            Text('词组/搭配', style: MistralTypography.heading5.copyWith(color: skin.colors.text2)),
            SizedBox(height: AppleSpacing.xs),
            _PhraseGroupList(raw: word.phrase, skin: skin),
          ],
          // 词根词缀
          if (word.wordRoot.isNotEmpty) ...[
            SizedBox(height: AppleSpacing.lg),
            Text('词根词缀', style: MistralTypography.heading5.copyWith(color: skin.colors.text2)),
            SizedBox(height: AppleSpacing.xs),
            WordRootTab(wordRootJson: word.wordRoot),
          ],
          // 笔记区
          SizedBox(height: AppleSpacing.lg),
          _buildNotesSection(skin),
        ],
      ),
    );
  }

  // ===========================================================================
  // 笔记区
  // ===========================================================================

  Widget _buildNotesSection(SkinSystem skin) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('笔记', style: MistralTypography.heading5.copyWith(color: skin.colors.text2)),
            if (_notes.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text('${_notes.length}', style: MistralTypography.micro.copyWith(color: skin.colors.text3)),
              ),
            const Spacer(),
            GestureDetector(
              onTap: _addNote,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: skin.colors.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add, size: 16, color: skin.colors.accent),
                    const SizedBox(width: 4),
                    Text('添加笔记', style: MistralTypography.micro.copyWith(color: skin.colors.accent)),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (!_notesLoaded)
          const Center(
            child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator(strokeWidth: 2)),
          )
        else if (_notes.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: skin.colors.cardBgAlt,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: skin.colors.divider),
            ),
            child: Column(
              children: [
                Icon(Icons.edit_note, size: 32, color: skin.colors.text3),
                const SizedBox(height: 8),
                Text('暂无笔记', style: MistralTypography.bodySm.copyWith(color: skin.colors.text3)),
                const SizedBox(height: 4),
                Text('点击上方"添加笔记"记录你的学习心得', style: MistralTypography.micro.copyWith(color: skin.colors.text3)),
              ],
            ),
          )
        else
          ..._notes.map(
            (note) =>
                _NoteCard(note: note, skin: skin, onEdit: () => _editNote(note), onDelete: () => _deleteNote(note)),
          ),
      ],
    );
  }

  // ===========================================================================
  // 其他组件
  // ===========================================================================

  Widget _buildWordHeader(dynamic word, SkinSystem skin) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: skin.colors.pageBg,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: skin.colors.divider),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(word.word, style: MistralTypography.heading1.copyWith(color: skin.colors.text1, fontSize: 40)),
              SizedBox(width: AppleSpacing.sm),
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
                          messenger.showSnackBar(const SnackBar(content: Text('发音加载失败，请检查网络'), duration: Duration(seconds: 2)));
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
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (word.usPron.isNotEmpty)
                  Text('美 /${word.usPron}/  ', style: MistralTypography.bodySm.copyWith(color: skin.colors.text3)),
                if (word.ukPron.isNotEmpty)
                  Text('英 /${word.ukPron}/', style: MistralTypography.bodySm.copyWith(color: skin.colors.text3)),
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

// ===========================================================================
// 笔记卡片
// ===========================================================================

class _NoteCard extends StatelessWidget {
  final WordNote note;
  final SkinSystem skin;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _NoteCard({required this.note, required this.skin, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: skin.colors.cardBg,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: skin.colors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(note.content, style: MistralTypography.bodyMd.copyWith(color: skin.colors.text1, height: 1.5)),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(_formatDate(note.updatedAt), style: MistralTypography.micro.copyWith(color: skin.colors.text3)),
              const Spacer(),
              IconButton(
                onPressed: onEdit,
                icon: Icon(Icons.edit_outlined, size: 20, color: skin.colors.text3),
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                padding: const EdgeInsets.all(12),
                splashRadius: 24,
                tooltip: '编辑',
              ),
              IconButton(
                onPressed: onDelete,
                icon: Icon(Icons.delete_outline, size: 20, color: skin.colors.danger),
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                padding: const EdgeInsets.all(12),
                splashRadius: 24,
                tooltip: '删除',
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(String dateStr) {
    if (dateStr.length < 14) return dateStr;
    return '${dateStr.substring(0, 4)}-${dateStr.substring(4, 6)}-${dateStr.substring(6, 8)} '
        '${dateStr.substring(8, 10)}:${dateStr.substring(10, 12)}';
  }
}

// ===========================================================================
// 笔记编辑弹窗
// ===========================================================================

class _NoteDialog extends StatelessWidget {
  final TextEditingController controller;
  final String title;

  const _NoteDialog({required this.controller, required this.title});

  @override
  Widget build(BuildContext context) {
    final skin = context.skin.colors;
    return AlertDialog(
      backgroundColor: skin.cardBg,
      title: Text(title, style: MistralTypography.heading5.copyWith(color: skin.text1)),
      content: TextField(
        controller: controller,
        maxLines: 5,
        autofocus: true,
        decoration: InputDecoration(
          hintText: '输入笔记内容...',
          hintStyle: MistralTypography.bodySm.copyWith(color: skin.text3),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            borderSide: BorderSide(color: skin.divider),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            borderSide: BorderSide(color: skin.accent),
          ),
        ),
        style: MistralTypography.bodyMd.copyWith(color: skin.text1),
      ),
      actions: [
        TextButton(
          onPressed: () => NavUtils.safePop(context),
          child: Text('取消', style: TextStyle(color: skin.text3)),
        ),
        FilledButton(
          onPressed: () => NavUtils.safePop(context, controller.text),
          style: FilledButton.styleFrom(backgroundColor: skin.accent),
          child: const Text('保存'),
        ),
      ],
    );
  }
}

/// 词组/搭配分组列表（结构化展示）
class _PhraseGroupList extends StatelessWidget {
  final String raw;
  final SkinSystem skin;
  const _PhraseGroupList({required this.raw, required this.skin});

  @override
  Widget build(BuildContext context) {
    final groups = PhraseParser.parse(raw);
    if (groups.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: groups.map((g) => _PhraseGroupCard(group: g, skin: skin)).toList(),
    );
  }
}

/// 单个词组分组卡片
class _PhraseGroupCard extends StatelessWidget {
  final PhraseGroup group;
  final SkinSystem skin;
  const _PhraseGroupCard({required this.group, required this.skin});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: skin.colors.pageBg,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: skin.colors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 分组类型标签
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: skin.colors.accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Text(
              group.type == 0 ? '固定搭配' : '常用词组',
              style: MistralTypography.caption.copyWith(color: skin.colors.accent),
            ),
          ),
          const SizedBox(height: 8),
          // 词组列表
          ...group.items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          item.en,
                          style: MistralTypography.bodyMd.copyWith(
                            color: skin.colors.text1,
                            height: 1.4,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      // 发音按钮
                      GestureDetector(
                        onTap: () {
                          if (item.en.isNotEmpty) {
                            context.read<AudioPlaybackState>().playWord(item.en);
                          }
                        },
                        child: Padding(
                          padding: const EdgeInsets.only(left: 6, top: 2),
                          child: Icon(Icons.volume_up_outlined, size: 16, color: skin.colors.accent),
                        ),
                      ),
                    ],
                  ),
                  if (item.cn.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        item.cn,
                        style: MistralTypography.bodySm.copyWith(color: skin.colors.text3),
                      ),
                    ),
                  if (item.exams.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: item.exams
                            .map(
                              (e) => Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: skin.colors.cardBgAlt,
                                  borderRadius: BorderRadius.circular(AppRadius.sm),
                                ),
                                child: Text(
                                  e,
                                  style: MistralTypography.micro.copyWith(color: skin.colors.text2),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 例句条目（带收藏按钮）
class _ExampleTile extends StatefulWidget {
  final ExampleSentence example;
  final SkinSystem skin;
  final String word;
  final int wordId;

  const _ExampleTile(this.example, this.skin, {required this.word, required this.wordId});

  @override
  State<_ExampleTile> createState() => _ExampleTileState();
}

class _ExampleTileState extends State<_ExampleTile> {
  bool _isFav = false;

  @override
  void initState() {
    super.initState();
    _checkFavStatus();
  }

  void _checkFavStatus() {
    // 使用句子的唯一标识（英文内容的hash）作为sentenceId
    final sentenceId = widget.example.en.hashCode.toString();
    final favStore = context.read<SentenceFavoritesStore>();
    favStore.isFavorite(wordId: widget.wordId, sentenceId: sentenceId).then((v) {
      if (mounted) setState(() => _isFav = v);
    });
  }

  Future<void> _toggleFav() async {
    final sentenceId = widget.example.en.hashCode.toString();
    final store = context.read<SentenceFavoritesStore>();
    final messenger = ScaffoldMessenger.of(context);

    await store.toggle(
      wordId: widget.wordId,
      sentenceId: sentenceId,
      english: widget.example.en,
      chinese: widget.example.cn,
      source: widget.example.source,
    );

    if (mounted) {
      // 直接获取新状态，不设中间值避免闪烁
      final newStatus = await store.isFavorite(wordId: widget.wordId, sentenceId: sentenceId);
      if (mounted) setState(() => _isFav = newStatus);

      messenger.showSnackBar(SnackBar(content: Text(_isFav ? '已收藏到句库' : '已取消收藏'), duration: const Duration(seconds: 1)));
    }
  }

  /// 播放例句音频（audio.beingfine.cn 的完整 URL）。
  void _playExampleAudio() {
    final url = widget.example.audioUrl;
    if (url == null || url.isEmpty) return;
    context.read<AudioPlaybackState>().playSentence(url);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: widget.skin.colors.pageBg,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: widget.skin.colors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: MistralTypography.bodySm.copyWith(color: widget.skin.colors.text1, height: 1.4),
                    children: widget.example.highlightedParts
                        .map(
                          (p) => TextSpan(
                            text: p.text,
                            style: p.highlight
                                ? TextStyle(fontWeight: FontWeight.bold, color: widget.skin.colors.accent)
                                : null,
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
              // 例句发音按钮（音频可用时显示）
              if (widget.example.audioUrl != null && widget.example.audioUrl!.isNotEmpty)
                GestureDetector(
                  onTap: _playExampleAudio,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 6, top: 2),
                    child: Icon(
                      Icons.volume_up_outlined,
                      size: 18,
                      color: widget.skin.colors.accent,
                    ),
                  ),
                ),
              // 收藏按钮
              GestureDetector(
                onTap: _toggleFav,
                child: Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Icon(
                    _isFav ? Icons.favorite : Icons.favorite_border,
                    size: 18,
                    color: _isFav ? widget.skin.colors.danger : widget.skin.colors.text3,
                  ),
                ),
              ),
            ],
          ),
          if (widget.example.cn.isNotEmpty) ...[
            const SizedBox(height: 4),
            TextGenerateEffect(
              text: widget.example.cn,
              style: MistralTypography.micro.copyWith(color: widget.skin.colors.text3),
              duration: const Duration(milliseconds: 600),
              delay: const Duration(milliseconds: 300),
            ),
          ],
          if (widget.example.source.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                widget.example.source,
                style: MistralTypography.micro.copyWith(color: widget.skin.colors.text3),
              ),
            ),
        ],
      ),
    );
  }
}

/// FSRS 记忆统计小部件
class _FsrsStat extends StatelessWidget {
  final String label;
  final String value;
  const _FsrsStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: MistralTypography.caption.copyWith(color: skin.colors.text3)),
        const SizedBox(height: 2),
        Text(
          value,
          style: MistralTypography.bodyMd.copyWith(color: skin.colors.text1, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
