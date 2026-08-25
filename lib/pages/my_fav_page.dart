// 移植自 v3.2 MyFavActivity
// 单词本：收藏列表 + 学习入口 + 批量操作
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../screens/learn_session.dart';
import '../state/learning_state.dart';
import '../theme/skin_system.dart';
import '../tokens/design_tokens.dart';
import '../models/word.dart';

class MyFavPage extends StatefulWidget {
  const MyFavPage({super.key});
  static const routeName = '/my_fav';

  @override
  State<MyFavPage> createState() => _MyFavPageState();
}

class _MyFavPageState extends State<MyFavPage> {
  List<Word> _words = [];
  bool _isLoading = true;
  bool _isBatchEditMode = false;
  final Set<int> _selectedIndices = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final state = context.read<LearningState>();
    final words = await state.getFavoriteWords();
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

  /// 批量取消收藏
  Future<void> _batchRemoveFavorites() async {
    if (_selectedIndices.isEmpty) return;
    final state = context.read<LearningState>();
    final toRemove = _selectedIndices.map((i) => _words[i].word).toList();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要从单词本移除 ${toRemove.length} 个单词吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('确定')),
        ],
      ),
    );

    if (confirmed == true) {
      for (final word in toRemove) {
        await state.toggleFavorite(word);
      }
      _toggleBatchEdit();
      await _loadData();
    }
  }

  /// 开始学习收藏单词
  Future<void> _startLearning() async {
    final state = context.read<LearningState>();
    await state.loadFavoritesForLearning(limit: 50);
    if (mounted) {
      Navigator.pushNamed(context, LearnSession.routeName);
    }
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final state = context.watch<LearningState>();

    return Scaffold(
      backgroundColor: skin.colors.pageBg,
      body: SafeArea(
        child: Column(
          children: [
            // 导航栏
            _buildNavBar(skin, state),
            Container(height: 1, color: skin.colors.divider),
            // 内容区
            Expanded(
              child: _isLoading
                  ? Center(child: CircularProgressIndicator(color: MistralColors.primary))
                  : _words.isEmpty
                      ? _buildEmptyView(skin)
                      : _buildWordList(skin),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavBar(SkinSystem skin, LearningState state) {
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
            '单词本',
            style: MistralTypography.heading5.copyWith(color: skin.colors.text1),
          ),
          const SizedBox(width: 8),
          // 收藏数量徽章
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: MistralColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${state.favoriteCount}',
              style: MistralTypography.captionBold.copyWith(color: MistralColors.primary),
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
              onPressed: _batchRemoveFavorites,
              child: const Text('删除', style: TextStyle(color: Colors.red)),
            ),
            TextButton(
              onPressed: _toggleBatchEdit,
              child: Text('取消', style: TextStyle(color: skin.colors.text3)),
            ),
          ] else ...[
            IconButton(
              icon: Icon(Icons.checklist, color: skin.colors.text1, size: 22),
              onPressed: _words.isNotEmpty ? _toggleBatchEdit : null,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyView(SkinSystem skin) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.book_outlined, size: 64, color: skin.colors.text3),
          const SizedBox(height: 16),
          Text(
            '单词本为空',
            style: MistralTypography.heading5.copyWith(color: skin.colors.text1),
          ),
          const SizedBox(height: 8),
          Text(
            '学习时点击 ❤️ 收藏单词',
            style: MistralTypography.body.copyWith(color: skin.colors.text3),
          ),
        ],
      ),
    );
  }

  Widget _buildWordList(SkinSystem skin) {
    return Column(
      children: [
        // 学习入口按钮
        if (!_isBatchEditMode && _words.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _startLearning,
                icon: const Icon(Icons.play_arrow, size: 22),
                label: Text('学习单词本 (${_words.length} 词)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: MistralColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppleRadius.lg),
                  ),
                  elevation: 0,
                ),
              ),
            ),
          ),
        // 单词列表
        Expanded(
          child: ListView.builder(
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
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                confirmDismiss: (direction) async {
                  return await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('确认移除'),
                      content: Text('确定要将 "${word.word}" 从单词本移除吗？'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('取消'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('移除'),
                        ),
                      ],
                    ),
                  );
                },
                onDismissed: (direction) async {
                  final state = context.read<LearningState>();
                  await state.toggleFavorite(word.word);
                  setState(() => _words.removeAt(index));
                },
                child: ListTile(
                  onTap: _isBatchEditMode
                      ? () => _toggleSelect(index)
                      : () => Navigator.pushNamed(context, '/word_detail', arguments: word),
                  leading: _isBatchEditMode
                      ? Checkbox(
                          value: isSelected,
                          onChanged: (_) => _toggleSelect(index),
                          activeColor: MistralColors.primary,
                        )
                      : null,
                  title: Text(
                    word.word,
                    style: MistralTypography.heading5.copyWith(color: skin.colors.text1),
                  ),
                  subtitle: word.firstInterpretLine.isNotEmpty
                      ? Text(
                          word.firstInterpretLine,
                          style: MistralTypography.bodySm.copyWith(color: skin.colors.text3),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        )
                      : (word.usPron.isNotEmpty
                          ? Text(
                              '/${word.usPron}/',
                              style: MistralTypography.bodySm.copyWith(color: skin.colors.text3),
                            )
                          : null),
                  trailing: _isBatchEditMode
                      ? null
                      : Icon(Icons.chevron_right, color: skin.colors.text3),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
