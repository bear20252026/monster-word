// 字典详情页：单词详解（释义+音标+例句+常见用法+词根+形近词+笔记）
// 从学习页答题后进入，看完后点击"下一词"返回学习
import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/example_parser.dart';
import '../data/dictionary_extra.dart';
import '../data/fav_sentence_dao.dart';
import '../data/note_database.dart';
import '../data/wordbook_database.dart' show Word;
import '../engine/fsrs6_engine.dart' show FsrsRating;
import '../hooks/responsive.dart';
import '../models/sentence_models.dart';
import '../models/word_note.dart';
import '../state/learning_state.dart';
import '../theme/skin_system.dart';
import '../tokens/design_tokens.dart';
import '../widgets/sb_card.dart';
import '../widgets/text_generate_effect.dart';
import '../widgets/box_reveal.dart';
import '../widgets/definition_view.dart';

class WordDetailPage extends StatefulWidget {
  const WordDetailPage({super.key});
  static const routeName = '/word_detail';

  @override
  State<WordDetailPage> createState() => _WordDetailPageState();
}

class _WordDetailPageState extends State<WordDetailPage> {
  List<WordNote> _notes = [];
  bool _notesLoaded = false;
  DictionaryExtra? _extra; // 字典补充数据（派生词/近义词/真题）
  StreamSubscription<void>? _audioSub; // 音频播放完成订阅

  /// 解析要展示的单词：路由参数优先（从词书/收藏/列表点入时显示所点的词），
  /// 否则回退到当前学习词。修复此前所有入口都显示 currentWord 的问题。
  Word? _resolveTargetWord(LearningState? state) {
    final arg = ModalRoute.of(context)?.settings.arguments;
    if (arg is Word) return arg;
    return state?.currentWord ?? context.read<LearningState>().currentWord;
  }

  @override
  void initState() {
    super.initState();
    _loadNotes();
    _loadExtra();
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
      await NoteDatabase.instance.initialize();
      final notes = await NoteDatabase.instance.getNotesByWordId(word.id);
      if (mounted) setState(() { _notes = notes; _notesLoaded = true; });
    } catch (e) {
      debugPrint('Notes loading error: $e');
      if (mounted) setState(() => _notesLoaded = true);
    }
  }

  Future<void> _addNote() async {
    final word = _resolveTargetWord(null);
    if (word == null) return;

    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => _NoteDialog(controller: controller, title: '添加笔记'),
    );
    if (result != null && result.trim().isNotEmpty) {
      final note = WordNote(
        wordId: word.id,
        word: word.word,
        content: result.trim(),
      );
      await NoteDatabase.instance.insertNote(note);
      await _loadNotes();
    }
  }

  Future<void> _editNote(WordNote note) async {
    final controller = TextEditingController(text: note.content);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => _NoteDialog(controller: controller, title: '编辑笔记'),
    );
    if (result != null && result.trim().isNotEmpty) {
      await NoteDatabase.instance.updateNote(
        note.copyWith(content: result.trim()),
      );
      await _loadNotes();
    }
  }

  Future<void> _deleteNote(WordNote note) async {
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
      await NoteDatabase.instance.deleteNote(note.id!);
      await _loadNotes();
    }
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final resp = context.responsive;
    final state = context.watch<LearningState>();
    final word = _resolveTargetWord(state);

    if (word == null) return const Scaffold(body: Center(child: Text('暂无单词')));

    final examples = ExampleParser.parse(word.example);
    final lines = word.interpretLines;
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
                    onPressed: () => Navigator.pop(context),
                  ),
                  Text('单词详情',
                    style: MistralTypography.heading5.copyWith(color: skin.colors.text1)),
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
            _buildBottomActionBar(context, skin, resp, state),
          ],
        ),
      ),
    ),
    );
  }

  /// FSRS-6 记忆预测卡片（显示记忆状态、难度、下次复习时间）
  Widget _buildFsrsPredictionCard(BuildContext context, LearningState state, Word word) {
    final skin = context.skin;
    final card = state.getCard(word.word);
    if (card == null || card.isNew) {
      return SbCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.psychology_outlined, color: skin.colors.accent, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text('新词 — 开始学习后将生成记忆预测',
                style: MistralTypography.bodyMd.copyWith(color: skin.colors.text2)),
            ),
          ],
        ),
      );
    }
    final prediction = state.getCard(word.word);
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
              Text('记忆预测',
                style: MistralTypography.heading5.copyWith(color: skin.colors.text1)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  r < 3 ? '即将遗忘' : r < 7 ? '模糊' : r < 14 ? '一般' : '牢固',
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
  Widget _buildBottomActionBar(BuildContext context, SkinSystem skin, AppResponsive resp, LearningState state) {
    final isLastWord = state.currentIndex >= state.queue.length - 1;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: resp.horizontalPadding,
        vertical: 12,
      ),
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
              // 记录评分并推进到下一个单词
              state.rate(FsrsRating.good);
              // 返回学习页面，自动显示下一个单词
              Navigator.pop(context);
            },
            icon: Icon(isLastWord ? Icons.check : Icons.arrow_forward, size: 20),
            label: Text(isLastWord ? '完成学习' : '下一词'),
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

  Widget _buildDesktopLayout(Word word, SkinSystem skin, AppResponsive resp, List<dynamic> examples, List<String> lines, List<String> confuseList) {
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
                        child: Text('释义',
                          style: MistralTypography.heading5.copyWith(color: skin.colors.text2)),
                      ),
                      SizedBox(height: AppleSpacing.xs),
                      ...lines.map((line) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(line,
                          style: MistralTypography.bodyMd.copyWith(color: skin.colors.text1, height: 1.5)),
                      )),
                    ],
                    // 例句
                    if (examples.isNotEmpty) ...[
                      SizedBox(height: AppleSpacing.lg),
                      BoxReveal(
                        direction: BoxRevealDirection.right,
                        duration: const Duration(milliseconds: 350),
                        delay: const Duration(milliseconds: 200),
                        reveal: true,
                        child: Text('例句',
                          style: MistralTypography.heading5.copyWith(color: skin.colors.text2)),
                      ),
                      SizedBox(height: AppleSpacing.xs),
                      ...examples.take(3).map((ex) => _ExampleTile(
                        ex,
                        skin,
                        word: word.word,
                        wordId: word.id,
                      )),
                    ],
                    // FSRS-6 记忆预测卡片
                    SizedBox(height: AppleSpacing.lg),
                    _buildFsrsPredictionCard(context, context.read<LearningState>(), word),
                    // 形近词
                    if (confuseList.isNotEmpty) ...[
                      SizedBox(height: AppleSpacing.lg),
                      Text('形近词',
                        style: MistralTypography.heading5.copyWith(color: skin.colors.text2)),
                      SizedBox(height: AppleSpacing.xs),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: confuseList.map((c) => Chip(
                          label: Text(c,
                            style: MistralTypography.bodySm.copyWith(color: skin.colors.text1)),
                          backgroundColor: skin.colors.pageBg,
                          side: BorderSide(color: skin.colors.divider),
                        )).toList(),
                      ),
                    ],
                    // 补充数据
                    if (_extra != null) ...[
                      SizedBox(height: AppleSpacing.lg),
                      Text('拓展 · 派生词',
                        style: MistralTypography.heading5.copyWith(color: skin.colors.text2)),
                      SizedBox(height: AppleSpacing.xs),
                      ..._extra!.derivatives.map((d) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('· ', style: TextStyle(fontWeight: FontWeight.bold)),
                            Expanded(
                              child: Text(d,
                                style: MistralTypography.bodyMd.copyWith(
                                  color: skin.colors.text1, height: 1.5)),
                            ),
                          ],
                        ),
                      )),
                      SizedBox(height: AppleSpacing.lg),
                      Text('近义词',
                        style: MistralTypography.heading5.copyWith(color: skin.colors.text2)),
                      SizedBox(height: AppleSpacing.xs),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _extra!.synonyms.map((s) => Chip(
                          label: Text(s,
                            style: MistralTypography.bodySm.copyWith(color: AppColors.white100)),
                          backgroundColor: skin.colors.accent.withValues(alpha: 0.85),
                          side: BorderSide.none,
                        )).toList(),
                      ),
                      if (_extra!.examSentences.isNotEmpty) ...[
                        SizedBox(height: AppleSpacing.lg),
                        Text('真题例句',
                          style: MistralTypography.heading5.copyWith(color: skin.colors.text2)),
                        SizedBox(height: AppleSpacing.xs),
                        ..._extra!.examSentences.map((e) => Container(
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
                                    child: Text(e.source,
                                      style: MistralTypography.caption.copyWith(
                                        color: AppColors.white100)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(e.sentence,
                                style: MistralTypography.bodyMd.copyWith(
                                  color: skin.colors.text1, height: 1.5)),
                            ],
                          ),
                        )),
                      ],
                    ],
                    // 常见用法
                    SizedBox(height: AppleSpacing.lg),
                    Text('常见用法',
                      style: MistralTypography.heading5.copyWith(color: skin.colors.text2)),
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
                          Text('${word.word} — 详细用法',
                            style: MistralTypography.bodyMd.copyWith(color: skin.colors.text1)),
                          const SizedBox(height: 4),
                          if (word.hasStructuredDefinitions)
                            DefinitionView(definitions: word.parsedDefinitions)
                          else
                            Text('释义: ${word.cleanInterpret}',
                              style: MistralTypography.bodySm.copyWith(color: skin.colors.text3)),
                          if (word.phrase.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text('词组: ${word.phrase}',
                              style: MistralTypography.bodySm.copyWith(color: skin.colors.text3)),
                          ],
                        ],
                      ),
                    ),
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

  Widget _buildMobileLayout(Word word, SkinSystem skin, AppResponsive resp, List<dynamic> examples, List<String> lines, List<String> confuseList) {
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
              child: Text('释义',
                style: MistralTypography.heading5.copyWith(color: skin.colors.text2)),
            ),
            SizedBox(height: AppleSpacing.xs),
            ...lines.map((line) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(line,
                style: MistralTypography.bodyMd.copyWith(color: skin.colors.text1, height: 1.5)),
            )),
          ],
          // 例句（BoxReveal 从右侧揭示）
          if (examples.isNotEmpty) ...[
            SizedBox(height: AppleSpacing.lg),
            BoxReveal(
              direction: BoxRevealDirection.right,
              duration: const Duration(milliseconds: 350),
              delay: const Duration(milliseconds: 200),
              reveal: true,
              child: Text('例句',
                style: MistralTypography.heading5.copyWith(color: skin.colors.text2)),
            ),
            SizedBox(height: AppleSpacing.xs),
            ...examples.take(3).map((ex) => _ExampleTile(
              ex,
              skin,
              word: word.word,
              wordId: word.id,
            )),
          ],
          // FSRS-6 记忆预测卡片
          SizedBox(height: AppleSpacing.lg),
          _buildFsrsPredictionCard(context, context.read<LearningState>(), word),
          // 形近词
          if (confuseList.isNotEmpty) ...[
            SizedBox(height: AppleSpacing.lg),
            Text('形近词',
              style: MistralTypography.heading5.copyWith(color: skin.colors.text2)),
            SizedBox(height: AppleSpacing.xs),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: confuseList.map((c) => Chip(
                label: Text(c,
                  style: MistralTypography.bodySm.copyWith(color: skin.colors.text1)),
                backgroundColor: skin.colors.pageBg,
                side: BorderSide(color: skin.colors.divider),
              )).toList(),
            ),
          ],
          // 补充数据
          if (_extra != null) ...[
            SizedBox(height: AppleSpacing.lg),
            Text('拓展 · 派生词',
              style: MistralTypography.heading5.copyWith(color: skin.colors.text2)),
            SizedBox(height: AppleSpacing.xs),
            ..._extra!.derivatives.map((d) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('· ', style: TextStyle(fontWeight: FontWeight.bold)),
                  Expanded(
                    child: Text(d,
                      style: MistralTypography.bodyMd.copyWith(
                        color: skin.colors.text1, height: 1.5)),
                  ),
                ],
              ),
            )),
            SizedBox(height: AppleSpacing.lg),
            Text('近义词',
              style: MistralTypography.heading5.copyWith(color: skin.colors.text2)),
            SizedBox(height: AppleSpacing.xs),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _extra!.synonyms.map((s) => Chip(
                label: Text(s,
                  style: MistralTypography.bodySm.copyWith(color: AppColors.white100)),
                backgroundColor: skin.colors.accent.withValues(alpha: 0.85),
                side: BorderSide.none,
              )).toList(),
            ),
            if (_extra!.examSentences.isNotEmpty) ...[
              SizedBox(height: AppleSpacing.lg),
              Text('真题例句',
                style: MistralTypography.heading5.copyWith(color: skin.colors.text2)),
              SizedBox(height: AppleSpacing.xs),
              ..._extra!.examSentences.map((e) => Container(
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
                          child: Text(e.source,
                            style: MistralTypography.caption.copyWith(
                              color: AppColors.white100)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(e.sentence,
                      style: MistralTypography.bodyMd.copyWith(
                        color: skin.colors.text1, height: 1.5)),
                  ],
                ),
              )),
            ],
          ],
          // 常见用法
          SizedBox(height: AppleSpacing.lg),
          Text('常见用法',
            style: MistralTypography.heading5.copyWith(color: skin.colors.text2)),
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
                Text('${word.word} — 详细用法',
                  style: MistralTypography.bodyMd.copyWith(color: skin.colors.text1)),
                const SizedBox(height: 4),
                Text('释义: ${word.cleanInterpret}',
                  style: MistralTypography.bodySm.copyWith(color: skin.colors.text3)),
                if (word.phrase.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text('词组: ${word.phrase}',
                    style: MistralTypography.bodySm.copyWith(color: skin.colors.text3)),
                ],
              ],
            ),
          ),
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
            Text('笔记',
              style: MistralTypography.heading5.copyWith(color: skin.colors.text2)),
            if (_notes.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text('${_notes.length}',
                  style: MistralTypography.micro.copyWith(color: skin.colors.text3)),
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
                    Text('添加笔记',
                      style: MistralTypography.micro.copyWith(color: skin.colors.accent)),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (!_notesLoaded)
          const Center(child: Padding(
            padding: EdgeInsets.all(16),
            child: CircularProgressIndicator(strokeWidth: 2),
          ))
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
                Text('暂无笔记',
                  style: MistralTypography.bodySm.copyWith(color: skin.colors.text3)),
                const SizedBox(height: 4),
                Text('点击上方"添加笔记"记录你的学习心得',
                  style: MistralTypography.micro.copyWith(color: skin.colors.text3)),
              ],
            ),
          )
        else
          ..._notes.map((note) => _NoteCard(
            note: note,
            skin: skin,
            onEdit: () => _editNote(note),
            onDelete: () => _deleteNote(note),
          )),
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
              Text(word.word,
                style: MistralTypography.heading1.copyWith(color: skin.colors.text1, fontSize: 40)),
              SizedBox(width: AppleSpacing.sm),
              GestureDetector(
                onTap: () async {
                  try {
                    // 取消上一次播放
                    await _audioSub?.cancel();
                    final player = AudioPlayer();
                    // 使用 HTTPS 避免网络安全策略拦截
                    final url = 'https://dict.youdao.com/dictvoice?audio=${Uri.encodeComponent(word.word)}&type=2';
                    await player.setSource(UrlSource(url));
                    await player.resume();
                    // 播放完成后释放资源
                    _audioSub = player.onPlayerComplete.listen((_) {
                      player.dispose();
                      _audioSub = null;
                    });
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('发音加载失败，请检查网络'), duration: Duration(seconds: 2)),
                      );
                    }
                  }
                },
                child: Icon(Icons.volume_up_outlined, color: skin.colors.accent, size: 28),
              ),
            ],
          ),
          if (word.usPron.isNotEmpty || word.ukPron.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (word.usPron.isNotEmpty)
                  Text('美 /${word.usPron}/  ',
                    style: MistralTypography.bodySm.copyWith(color: skin.colors.text3)),
                if (word.ukPron.isNotEmpty)
                  Text('英 /${word.ukPron}/',
                    style: MistralTypography.bodySm.copyWith(color: skin.colors.text3)),
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
      return t.substring(1, t.length - 1)
          .split(',').map((e) => e.trim().replaceAll('"', ''))
          .where((e) => e.isNotEmpty).toList();
    }
    return [t];
  }

  @override
  void dispose() {
    _audioSub?.cancel();
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

  const _NoteCard({
    required this.note,
    required this.skin,
    required this.onEdit,
    required this.onDelete,
  });

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
          Text(note.content,
            style: MistralTypography.bodyMd.copyWith(color: skin.colors.text1, height: 1.5)),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(_formatDate(note.updatedAt),
                style: MistralTypography.micro.copyWith(color: skin.colors.text3)),
              const Spacer(),
              IconButton(
                onPressed: onEdit,
                icon: Icon(Icons.edit_outlined, size: 18, color: skin.colors.text3),
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                padding: const EdgeInsets.all(6),
                splashRadius: 18,
                tooltip: '编辑',
              ),
              IconButton(
                onPressed: onDelete,
                icon: Icon(Icons.delete_outline, size: 18, color: skin.colors.danger),
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                padding: const EdgeInsets.all(6),
                splashRadius: 18,
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
      title: Text(title,
        style: MistralTypography.heading5.copyWith(color: skin.text1)),
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
          onPressed: () => Navigator.pop(context),
          child: Text('取消', style: TextStyle(color: skin.text3)),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, controller.text),
          style: FilledButton.styleFrom(backgroundColor: skin.accent),
          child: const Text('保存'),
        ),
      ],
    );
  }
}

/// 例句条目（带收藏按钮）
class _ExampleTile extends StatefulWidget {
  final ExampleSentence example;
  final SkinSystem skin;
  final String word;
  final int wordId;

  const _ExampleTile(
    this.example,
    this.skin, {
    required this.word,
    required this.wordId,
  });

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
    setState(() {
      _isFav = FavSentenceDao.instance.isFavSentence(widget.wordId, sentenceId);
    });
  }

  Future<void> _toggleFav() async {
    final sentenceId = widget.example.en.hashCode.toString();

    // 创建 SentenceData 对象
    final sentenceData = SentenceData(
      sid: sentenceId,
      e: widget.example.en,
      c: widget.example.cn,
      b: widget.example.source,
    );

    await FavSentenceDao.instance.toggleFavSentence(
      word: widget.word,
      wordId: widget.wordId,
      sentenceId: sentenceId,
      sentenceData: sentenceData,
    );

    if (mounted) {
      setState(() {
        _isFav = FavSentenceDao.instance.isFavSentence(widget.wordId, sentenceId);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isFav ? '已收藏到句库' : '已取消收藏'),
          duration: const Duration(seconds: 1),
        ),
      );
    }
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
                    style: MistralTypography.bodySm.copyWith(
                      color: widget.skin.colors.text1,
                      height: 1.4,
                    ),
                    children: widget.example.highlightedParts
                        .map((p) => TextSpan(
                              text: p.text,
                              style: p.highlight
                                  ? TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: widget.skin.colors.accent,
                                    )
                                  : null,
                            ))
                        .toList(),
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
        Text(label,
          style: MistralTypography.caption.copyWith(color: skin.colors.text3)),
        const SizedBox(height: 2),
        Text(value,
          style: MistralTypography.bodyMd.copyWith(
            color: skin.colors.text1, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
