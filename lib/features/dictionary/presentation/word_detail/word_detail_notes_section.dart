// 字典详情页 - 笔记区块（从 word_detail_page.dart 拆出）
import 'package:word_app/core/utils/debug_log.dart';
import 'package:word_app/core/utils/swallowed_error_report.dart';
import 'package:word_app/widgets/common/mw_feedback.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:word_app/features/word_browse/application/word_notes_store.dart';
import 'package:word_app/models/word.dart';
import 'package:word_app/models/word_note.dart';
import 'package:word_app/app/router/nav_utils.dart';
import 'package:word_app/theme/skin_system.dart';
import 'package:word_app/tokens/design_tokens.dart';
import 'package:word_app/utils/date_format_utils.dart';

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
      debugLog('Notes loading error: $e');
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
      // MW-41：add 返回持久化层生成的真实 ID（AUTOINCREMENT）——此前
      // 本地实体 id 为 null，删除走 `note.id!` 直接运行时崩溃。
      // R2-07：SQLite 写失败会外抛（不再静默改落 SP），此处必须接住并明确
      // 提示，否则用户看到的是「弹窗关了、像保存成功、重载后没了」。
      final int id;
      try {
        id = await store.add(note);
      } catch (e, s) {
        reportSwallowedError('笔记保存失败（UI 提示）', e, s);
        if (mounted) {
          showMwSnackBar(context, const SnackBar(content: Text('笔记保存失败，请稍后重试')));
        }
        return;
      }
      assert(id > 0, 'persisted note id must be positive');
      // 弹窗 await 期间详情页可能已被关闭：_loadNotes 入口的 context.read
      // 会在元素失效时抛错（审计：async gap 后无存活检查）。
      if (!mounted) return;
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
      // R2-07：写失败会外抛（不再静默改落 SP），此处接住并提示。
      try {
        await store.update(note.copyWith(content: result.trim()));
      } catch (e, s) {
        reportSwallowedError('笔记更新失败（UI 提示）', e, s);
        if (mounted) {
          showMwSnackBar(context, const SnackBar(content: Text('笔记更新失败，请稍后重试')));
        }
        return;
      }
      if (!mounted) return;
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
      // MW-41：无 id 的存量实体（迁移前的 null-id 笔记已随迁移获得真实
      // 主键；此处防御性兜底）不得触发 null! 崩溃。
      final id = note.id;
      if (id == null) {
        await _loadNotes();
        return;
      }
      // R2-07：删除失败会外抛——删除方向尤其不能静默：SP 里删了而 SQLite
      // 仍在时，读路径会把「已删除」的笔记再显示出来。
      try {
        await store.deleteById(id);
      } catch (e, s) {
        reportSwallowedError('笔记删除失败（UI 提示）', e, s);
        if (mounted) {
          showMwSnackBar(context, const SnackBar(content: Text('笔记删除失败，请稍后重试')));
        }
        return;
      }
      if (!mounted) return;
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
            Text('笔记', style: MwTypography.heading5.copyWith(color: skin.colors.text2)),
            if (_notes.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(left: AppSpacing.xs),
                child: Text('${_notes.length}', style: MwTypography.micro.copyWith(color: skin.colors.text3)),
              ),
            const Spacer(),
            GestureDetector(
              onTap: _addNote,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: skin.colors.accent.withValues(alpha: AppAlphas.o10),
                  borderRadius: BorderRadius.circular(context.design.radius.pill),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add, size: 16, color: skin.colors.accent),
                    SizedBox(width: 4),
                    Text('添加笔记', style: MwTypography.micro.copyWith(color: skin.colors.accent)),
                  ],
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 8),
        if (!_notesLoaded)
          const Center(
            child: Padding(padding: EdgeInsets.all(AppSpacing.md), child: CircularProgressIndicator(strokeWidth: 2)),
          )
        else if (_notes.isEmpty)
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: skin.colors.cardBgAlt,
              borderRadius: BorderRadius.circular(context.design.radius.md),
              border: Border.all(color: skin.colors.divider),
            ),
            child: Column(
              children: [
                Icon(Icons.edit_note, size: 32, color: skin.colors.text3),
                SizedBox(height: 8),
                Text('暂无笔记', style: MwTypography.bodySm.copyWith(color: skin.colors.text3)),
                SizedBox(height: 4),
                Text('点击上方"添加笔记"记录你的学习心得', style: MwTypography.micro.copyWith(color: skin.colors.text3)),
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
      margin: EdgeInsets.only(bottom: AppSpacing.xs),
      padding: EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: skin.colors.cardBg,
        borderRadius: BorderRadius.circular(context.design.radius.md),
        border: Border.all(color: skin.colors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(note.content, style: MwTypography.bodyMd.copyWith(color: skin.colors.text1, height: 1.5)),
          SizedBox(height: 8),
          Row(
            children: [
              Text(formatCompactDateTime(note.updatedAt), style: MwTypography.micro.copyWith(color: skin.colors.text3)),
              const Spacer(),
              IconButton(
                onPressed: onEdit,
                icon: Icon(Icons.edit_outlined, size: 20, color: skin.colors.text3),
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                padding: EdgeInsets.all(AppSpacing.sm),
                splashRadius: 24,
                tooltip: '编辑',
              ),
              IconButton(
                onPressed: onDelete,
                icon: Icon(Icons.delete_outline, size: 20, color: skin.colors.danger),
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                padding: EdgeInsets.all(AppSpacing.sm),
                splashRadius: 24,
                tooltip: '删除',
              ),
            ],
          ),
        ],
      ),
    );
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
      title: Text(title, style: MwTypography.heading5.copyWith(color: skin.text1)),
      content: TextField(
        controller: controller,
        maxLines: 5,
        // 安全审计：笔记按 wordId 整键 JSON 落 SP，无上限的单键可无限膨胀。
        maxLength: 2000,
        autofocus: true,
        decoration: InputDecoration(
          hintText: '输入笔记内容...',
          hintStyle: MwTypography.bodySm.copyWith(color: skin.text3),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(context.design.radius.md),
            borderSide: BorderSide(color: skin.divider),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(context.design.radius.md),
            borderSide: BorderSide(color: skin.accent),
          ),
        ),
        style: MwTypography.bodyMd.copyWith(color: skin.text1),
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
