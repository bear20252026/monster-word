// 由 Claude 团队生成 | Monster Word App

// 移植自 v3.2 ListWordsActviity（抽象基类）
// 单词列表基类：支持滑动删除、批量编辑、字母快速索引
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/learning_state.dart';
import '../theme/skin_system.dart';
import '../tokens/design_tokens.dart';
import '../models/word.dart';

/// 单词列表页基类，具体子类通过 [loadWords] 提供数据
abstract class ListWordsPage extends StatefulWidget {
  const ListWordsPage({super.key});
}

abstract class ListWordsPageState<T extends ListWordsPage> extends State<T> {
  List<Word> _words = [];
  bool _isLoading = true;
  bool _isBatchEditMode = false;
  final Set<int> _selectedIndices = {};

  String get pageTitle;
  Future<List<Word>> loadWords(LearningState state);

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final state = context.read<LearningState>();
    final words = await loadWords(state);
    if (mounted) {
      setState(() {
        _words = words;
        _isLoading = false;
      });
    }
  }

  void _toggleBatchEdit() {
    setState(() {
      _isBatchEditMode = !_isBatchEditMode;
      if (!_isBatchEditMode) _selectedIndices.clear();
    });
  }

  void _toggleSelect(int index) {
    setState(() {
      if (_selectedIndices.contains(index)) {
        _selectedIndices.remove(index);
      } else {
        _selectedIndices.add(index);
      }
    });
  }

  void _selectAll() {
    setState(() {
      if (_selectedIndices.length == _words.length) {
        _selectedIndices.clear();
      } else {
        _selectedIndices.addAll(List.generate(_words.length, (i) => i));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;

    return Scaffold(
      backgroundColor: skin.colors.pageBg,
      body: SafeArea(
        child: Column(
          children: [
            _buildNavBar(skin),
            Container(height: 1, color: skin.colors.divider),
            Expanded(
              child: _isLoading
                  ? Center(
                      child: CircularProgressIndicator(
                        color: MistralColors.primary,
                      ),
                    )
                  : _words.isEmpty
                      ? _buildEmptyView(skin)
                      : _buildWordList(skin),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavBar(SkinSystem skin) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
            color: skin.colors.text1,
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 4),
          Text(
            pageTitle,
            style: MistralTypography.heading5.copyWith(
              color: skin.colors.text1,
            ),
          ),
          const Spacer(),
          if (_isBatchEditMode) ...[
            TextButton(
              onPressed: _selectAll,
              child: Text(
                _selectedIndices.length == _words.length ? '取消全选' : '全选',
                style: TextStyle(color: MistralColors.primary),
              ),
            ),
            TextButton(
              onPressed: _toggleBatchEdit,
              child: Text('取消', style: TextStyle(color: skin.colors.text3)),
            ),
          ] else
            IconButton(
              icon: Icon(Icons.checklist, color: skin.colors.text1, size: 22),
              onPressed: _toggleBatchEdit,
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyView(SkinSystem skin) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_outlined, size: 64, color: skin.colors.text3),
          const SizedBox(height: 16),
          Text(
            '暂无单词',
            style: MistralTypography.body.copyWith(color: skin.colors.text3),
          ),
        ],
      ),
    );
  }

  Widget _buildWordList(SkinSystem skin) {
    return ListView.builder(
      itemCount: _words.length,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemBuilder: (context, index) {
        final word = _words[index];
        final isSelected = _selectedIndices.contains(index);

        return Dismissible(
          key: ValueKey(word.id),
          direction: _isBatchEditMode
              ? DismissDirection.none
              : DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            color: MistralColors.danger,
            child: const Icon(Icons.delete, color: AppColors.white100),
          ),
          confirmDismiss: (direction) async {
            return await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('确认删除'),
                content: Text('确定要删除 "${word.word}" 吗？'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('取消'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('删除'),
                  ),
                ],
              ),
            );
          },
          onDismissed: (direction) {
            setState(() => _words.removeAt(index));
            // TODO: 从数据库删除
          },
          child: ListTile(
            onTap: _isBatchEditMode
                ? () => _toggleSelect(index)
                : () => _openWordDetail(word),
            leading: _isBatchEditMode
                ? Checkbox(
                    value: isSelected,
                    onChanged: (_) => _toggleSelect(index),
                    activeColor: MistralColors.primary,
                  )
                : null,
            title: Text(
              word.word,
              style: MistralTypography.heading5.copyWith(
                color: skin.colors.text1,
              ),
            ),
            subtitle: word.usPron.isNotEmpty
                ? Text(
                    '/${word.usPron}/',
                    style: MistralTypography.bodySm.copyWith(
                      color: skin.colors.text3,
                    ),
                  )
                : null,
            trailing: _isBatchEditMode
                ? null
                : Icon(Icons.chevron_right, color: skin.colors.text3),
          ),
        );
      },
    );
  }

  void _openWordDetail(Word word) {
    Navigator.pushNamed(context, '/word_detail', arguments: word);
  }
}
