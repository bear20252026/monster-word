// 由 Claude 团队生成 | Monster Word App
// 句库页面：显示用户收藏的所有例句
// 移植自 v3.2 MyFavSentenceActivity
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../features/word_browse/application/sentence_favorites_store.dart';
import '../../../models/sentence_models.dart';
import '../../../theme/skin_system.dart';
import '../../../tokens/design_tokens.dart';

class MyFavSentencePage extends StatefulWidget {
  const MyFavSentencePage({super.key});

  static const routeName = '/my_fav_sentence';

  @override
  State<MyFavSentencePage> createState() => _MyFavSentencePageState();
}

class _MyFavSentencePageState extends State<MyFavSentencePage> {
  List<FavSentenceData> _sentences = [];
  bool _isLoading = true;
  bool _isEditMode = false;
  Set<int> _selectedIndices = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final sentences = await context.read<SentenceFavoritesStore>().list();
      if (mounted) {
        setState(() {
          _sentences = sentences;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _sentences = [];
          _isLoading = false;
        });
      }
    }
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
            _buildStatsBar(skin),
            Container(height: 1, color: skin.colors.divider),
            Expanded(
              child: _isLoading
                  ? Center(child: CircularProgressIndicator(color: MistralColors.primary))
                  : _sentences.isEmpty
                  ? _buildEmptyView(skin)
                  : _buildList(skin),
            ),
            if (_isEditMode) _buildEditModeBar(skin),
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
          Text('句库', style: MistralTypography.heading5.copyWith(color: skin.colors.text1)),
          const Spacer(),
          // 编辑按钮
          if (_sentences.isNotEmpty)
            TextButton(
              onPressed: () {
                setState(() {
                  _isEditMode = !_isEditMode;
                  _selectedIndices.clear();
                });
              },
              child: Text(
                _isEditMode ? '完成' : '编辑',
                style: MistralTypography.bodySm.copyWith(color: MistralColors.primary),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatsBar(SkinSystem skin) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(Icons.format_quote, size: 18, color: skin.colors.text3),
          const SizedBox(width: 8),
          Text('共 ${_sentences.length} 个例句', style: MistralTypography.bodySm.copyWith(color: skin.colors.text2)),
          const Spacer(),
          // 学习按钮
          if (_sentences.isNotEmpty && !_isEditMode)
            GestureDetector(
              onTap: _startLearning,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: MistralColors.primary,
                  borderRadius: BorderRadius.circular(context.design.radius.pill),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.play_arrow, size: 16, color: Colors.white),
                    const SizedBox(width: 4),
                    Text('开始学习', style: MistralTypography.micro.copyWith(color: Colors.white)),
                  ],
                ),
              ),
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
          Icon(Icons.format_quote, size: 64, color: skin.colors.text3),
          const SizedBox(height: 16),
          Text('暂无收藏例句', style: MistralTypography.body.copyWith(color: skin.colors.text3)),
          const SizedBox(height: 8),
          Text('在单词详情页点击 ♡ 收藏例句', style: MistralTypography.bodySm.copyWith(color: skin.colors.text3)),
        ],
      ),
    );
  }

  Widget _buildList(SkinSystem skin) {
    return ListView.builder(
      itemCount: _sentences.length,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        final favSentence = _sentences[index];
        final sentenceData = favSentence.sentenceData;
        if (sentenceData == null) return const SizedBox.shrink();

        final isSelected = _selectedIndices.contains(index);

        return GestureDetector(
          onTap: () {
            if (_isEditMode) {
              setState(() {
                if (isSelected) {
                  _selectedIndices.remove(index);
                } else {
                  _selectedIndices.add(index);
                }
              });
            }
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: skin.colors.cardBgAlt,
              borderRadius: BorderRadius.circular(context.design.radius.lg),
              border: Border.all(
                color: isSelected ? MistralColors.primary : skin.colors.divider,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 单词标签
                Row(
                  children: [
                    if (_isEditMode) ...[
                      Icon(
                        isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                        size: 20,
                        color: isSelected ? MistralColors.primary : skin.colors.text3,
                      ),
                      const SizedBox(width: 8),
                    ],
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: MistralColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(context.design.radius.sm),
                      ),
                      child: Text(
                        favSentence.word,
                        style: MistralTypography.bodySm.copyWith(
                          color: MistralColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _formatDate(favSentence.updateTime),
                      style: MistralTypography.micro.copyWith(color: skin.colors.text3),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // 英文例句
                Text(sentenceData.e, style: MistralTypography.body.copyWith(color: skin.colors.text1, height: 1.5)),
                // 中文翻译
                if (sentenceData.c.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(sentenceData.c, style: MistralTypography.bodySm.copyWith(color: skin.colors.text3)),
                ],
                // 来源
                if (sentenceData.b.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    '— ${sentenceData.b}',
                    style: MistralTypography.micro.copyWith(color: skin.colors.text3, fontStyle: FontStyle.italic),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEditModeBar(SkinSystem skin) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: skin.colors.cardBg,
        border: Border(top: BorderSide(color: skin.colors.divider)),
      ),
      child: Row(
        children: [
          // 全选/取消全选
          TextButton(
            onPressed: () {
              setState(() {
                if (_selectedIndices.length == _sentences.length) {
                  _selectedIndices.clear();
                } else {
                  _selectedIndices = Set.from(List.generate(_sentences.length, (i) => i));
                }
              });
            },
            child: Text(
              _selectedIndices.length == _sentences.length ? '取消全选' : '全选',
              style: MistralTypography.bodySm.copyWith(color: skin.colors.text2),
            ),
          ),
          const Spacer(),
          // 删除选中
          ElevatedButton(
            onPressed: _selectedIndices.isEmpty ? null : _deleteSelected,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(context.design.radius.md)),
            ),
            child: Text('删除 (${_selectedIndices.length})'),
          ),
        ],
      ),
    );
  }

  String _formatDate(String updateTime) {
    if (updateTime.length < 8) return '';
    try {
      final month = updateTime.substring(4, 6);
      final day = updateTime.substring(6, 8);
      return '$month/$day';
    } catch (e) {
      return '';
    }
  }

  void _startLearning() {
    // TODO: 实现从句库学习功能
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('句库学习功能开发中...')));
  }

  Future<void> _deleteSelected() async {
    final favStore = context.read<SentenceFavoritesStore>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除选中的 ${_selectedIndices.length} 个例句吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (!mounted) return;

    if (confirmed != true) return;

    // 按倒序删除，避免索引问题
    final sortedIndices = _selectedIndices.toList()..sort((a, b) => b.compareTo(a));
    for (final index in sortedIndices) {
      final favSentence = _sentences[index];
      await favStore.remove(
        wordId: favSentence.wordId,
        sentenceId: favSentence.sentenceId,
      );
    }

    setState(() {
      _selectedIndices.clear();
      _isEditMode = false;
    });

    await _loadData();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已删除选中的例句')));
    }
  }
}

