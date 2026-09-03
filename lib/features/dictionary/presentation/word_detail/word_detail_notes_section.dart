// 字典详情页 - 笔记区块（从 word_detail_page.dart 拆出）
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:word_app/features/word_browse/application/word_notes_store.dart';
import 'package:word_app/models/word.dart';
import 'package:word_app/models/word_note.dart';
import 'package:word_app/app/router/nav_utils.dart';
import 'package:word_app/theme/skin_system.dart';
import 'package:word_app/tokens/design_tokens.dart';

/// 笔记区块：列表 + 增删改（自管理加载状态，word 变化时自动重载）
class WordNotesSection extends StatefulWidget {
  final Word? word;
  const WordNotesSection({super.key, required this.word});

  @override
  State<WordNotesSection> createState() => _WordNotesSectionState();
}

class _WordNotesSectionState extends State<WordNotesSection> {
  List<WordNote> _notes = [];
  bool _notesLoaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadNotes());
  }

  @override
  void didUpdateWidget(covariant WordNotesSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.word?.word != widget.word?.word) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadNotes());
    }
  }

  Future<void> _loadNotes() async {
    final word = widget.word;
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
    final word = widget.word;
    if (word == null) return;

    final store = context.read<WordNotesStore>();
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => _NoteDialog(controller: controller, title: '添加笔记'),
    );
    controller.dispose();
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
    controller.dispose();
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('笔记', style: MistralTypography.heading5.copyWith(color: skin.colors.text2)),
            if (_notes.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(left: 8),
                child: Text('${_notes.length}', style: MistralTypography.micro.copyWith(color: skin.colors.text3)),
              ),
            const Spacer(),
            GestureDetector(
              onTap: _addNote,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: skin.colors.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(context.design.radius.pill),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add, size: 16, color: skin.colors.accent),
                    SizedBox(width: 4),
                    Text('添加笔记', style: MistralTypography.micro.copyWith(color: skin.colors.accent)),
                  ],
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 8),
        if (!_notesLoaded)
          const Center(
            child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator(strokeWidth: 2)),
          )
        else if (_notes.isEmpty)
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: skin.colors.cardBgAlt,
              borderRadius: BorderRadius.circular(context.design.radius.md),
              border: Border.all(color: skin.colors.divider),
            ),
            child: Column(
              children: [
                Icon(Icons.edit_note, size: 32, color: skin.colors.text3),
                SizedBox(height: 8),
                Text('暂无笔记', style: MistralTypography.bodySm.copyWith(color: skin.colors.text3)),
                SizedBox(height: 4),
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
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: skin.colors.cardBg,
        borderRadius: BorderRadius.circular(context.design.radius.md),
        border: Border.all(color: skin.colors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(note.content, style: MistralTypography.bodyMd.copyWith(color: skin.colors.text1, height: 1.5)),
          SizedBox(height: 8),
          Row(
            children: [
              Text(_formatDate(note.updatedAt), style: MistralTypography.micro.copyWith(color: skin.colors.text3)),
              const Spacer(),
              IconButton(
                onPressed: onEdit,
                icon: Icon(Icons.edit_outlined, size: 20, color: skin.colors.text3),
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                padding: EdgeInsets.all(12),
                splashRadius: 24,
                tooltip: '编辑',
              ),
              IconButton(
                onPressed: onDelete,
                icon: Icon(Icons.delete_outline, size: 20, color: skin.colors.danger),
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                padding: EdgeInsets.all(12),
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
            borderRadius: BorderRadius.circular(context.design.radius.md),
            borderSide: BorderSide(color: skin.divider),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(context.design.radius.md),
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
