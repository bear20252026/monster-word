// 字典详情页：单词详解（释义+音标+例句+常见用法+词根+形近词+笔记）
// 从学习页答题后进入，看完后点击"下一词"返回学习
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/example_parser.dart';
import '../data/fav_sentence_dao.dart';
import '../data/note_database.dart';
import '../models/sentence_models.dart';
import '../models/word_note.dart';
import '../state/learning_state.dart';
import '../theme/skin_system.dart';
import '../tokens/design_tokens.dart';

class WordDetailPage extends StatefulWidget {
  const WordDetailPage({super.key});
  static const routeName = '/word_detail';

  @override
  State<WordDetailPage> createState() => _WordDetailPageState();
}

class _WordDetailPageState extends State<WordDetailPage> {
  List<WordNote> _notes = [];
  bool _notesLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  Future<void> _loadNotes() async {
    final state = context.read<LearningState>();
    final word = state.currentWord;
    if (word == null) return;

    try {
      await NoteDatabase.instance.initialize();
      final notes = await NoteDatabase.instance.getNotesByWordId(word.id);
      if (mounted) setState(() { _notes = notes; _notesLoaded = true; });
    } catch (_) {
      if (mounted) setState(() => _notesLoaded = true);
    }
  }

  Future<void> _addNote() async {
    final state = context.read<LearningState>();
    final word = state.currentWord;
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
    final state = context.watch<LearningState>();
    final word = state.currentWord;

    if (word == null) return const Scaffold(body: Center(child: Text('暂无单词')));

    final examples = ExampleParser.parse(word.example);
    final lines = word.interpretLines;
    final confuseList = _parseConfuse(word.confuse);

    return Scaffold(
      backgroundColor: skin.colors.pageBg,
      body: SafeArea(
        child: Column(
          children: [
            // 顶部导航
            Container(
              height: AppSpacing.navH,
              padding: const EdgeInsets.symmetric(horizontal: 8),
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
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 单词 + 音标 + 发音
                    _buildWordHeader(word, skin),
                    const SizedBox(height: 20),
                    // 释义
                    if (lines.isNotEmpty) ...[
                      Text('释义',
                        style: MistralTypography.heading5.copyWith(color: skin.colors.text2)),
                      const SizedBox(height: 8),
                      ...lines.map((line) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(line,
                          style: MistralTypography.bodyMd.copyWith(color: skin.colors.text1, height: 1.5)),
                      )),
                    ],
                    // 例句
                    if (examples.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      Text('例句',
                        style: MistralTypography.heading5.copyWith(color: skin.colors.text2)),
                      const SizedBox(height: 8),
                      ...examples.take(3).map((ex) => _ExampleTile(
                        ex,
                        skin,
                        word: word.word,
                        wordId: word.id,
                      )),
                    ],
                    // 形近词
                    if (confuseList.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      Text('形近词',
                        style: MistralTypography.heading5.copyWith(color: skin.colors.text2)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: confuseList.map((c) => Chip(
                          label: Text(c,
                            style: MistralTypography.bodySm.copyWith(color: skin.colors.text1)),
                          backgroundColor: MistralColors.cream,
                          side: BorderSide(color: MistralColors.beigeDeep),
                        )).toList(),
                      ),
                    ],
                    // 常见用法
                    const SizedBox(height: 20),
                    Text('常见用法',
                      style: MistralTypography.heading5.copyWith(color: skin.colors.text2)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: MistralColors.creamLight,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(color: MistralColors.beigeDeep),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${word.word} — 详细用法',
                            style: MistralTypography.bodyMd.copyWith(color: skin.colors.text1)),
                          const SizedBox(height: 4),
                          Text('释义: ${word.interpret}',
                            style: MistralTypography.bodySm.copyWith(color: skin.colors.text3)),
                          if (word.phrase.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text('词组: ${word.phrase}',
                              style: MistralTypography.bodySm.copyWith(color: skin.colors.text3)),
                          ],
                        ],
                      ),
                    ),
                    // ===== 笔记区 =====
                    const SizedBox(height: 20),
                    _buildNotesSection(skin),
                  ],
                ),
              ),
            ),
            // 底部：下一词按钮
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: skin.colors.cardBg,
                border: Border(top: BorderSide(color: skin.colors.divider, width: 0.5)),
              ),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: () {
                    state.next();
                    Navigator.pop(context);
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: skin.colors.accent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md)),
                  ),
                  child: Text('下一词',
                    style: MistralTypography.buttonMd.copyWith(color: Colors.white)),
                ),
              ),
            ),
          ],
        ),
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
        gradient: const LinearGradient(
          colors: [MistralColors.cream, MistralColors.creamLight]),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: MistralColors.beigeDeep),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(word.word,
                style: MistralTypography.heading1.copyWith(color: skin.colors.text1, fontSize: 40)),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () async {
                  try {
                    final player = AudioPlayer();
                    await player.play(UrlSource(
                      'http://dict.youdao.com/dictvoice?audio=${Uri.encodeComponent(word.word)}&type=2'));
                  } catch (_) {}
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
              GestureDetector(
                onTap: onEdit,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(Icons.edit_outlined, size: 16, color: skin.colors.text3),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onDelete,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(Icons.delete_outline, size: 16, color: skin.colors.danger),
                ),
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
        color: MistralColors.creamLight,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: MistralColors.beigeDeep),
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
                    color: _isFav ? Colors.red : widget.skin.colors.text3,
                  ),
                ),
              ),
            ],
          ),
          if (widget.example.cn.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              widget.example.cn,
              style: MistralTypography.micro.copyWith(color: widget.skin.colors.text3),
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
