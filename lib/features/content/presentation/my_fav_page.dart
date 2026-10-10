// 单词本：收藏列表 + 学习入口 + 批量操作
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:word_app/core/application/presentation_prefs.dart';
import 'package:word_app/core/utils/swallowed_error_report.dart';

import 'package:word_app/features/learning/application/learning_favorites_store.dart';
import 'package:word_app/features/learning/application/learning_session_reader.dart';
import 'package:word_app/features/learning/application/learning_session_starter.dart';
import 'package:word_app/app/router/route_names.dart';
import 'package:word_app/theme/skin_system.dart';
import 'package:word_app/tokens/design_tokens.dart';
import 'package:word_app/models/word.dart';
import 'package:word_app/widgets/common/mw_feedback.dart';

class MyFavPage extends StatefulWidget {
  const MyFavPage({super.key});
  static const routeName = RouteNames.myFav;

  @override
  State<MyFavPage> createState() => _MyFavPageState();
}

class _MyFavPageState extends State<MyFavPage> {
  List<Word> _words = [];
  bool _isLoading = true;

  /// 加载失败态（提供重试入口，不再永久转圈）。
  bool _loadError = false;
  bool _isBatchEditMode = false;
  final Set<int> _selectedIndices = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _loadError = false;
    });
    final favorites = context.read<LearningFavoritesStore>();
    try {
      final words = await favorites.loadFavoriteWords(currentQueue: context.read<LearningSessionReader>().queue);
      if (mounted) {
        setState(() {
          _words = words.cast<Word>();
          _isLoading = false;
        });
      }
    } catch (e, s) {
      // 读取异常时此前 _isLoading 永久为 true（页面永久转圈）。
      reportSwallowedError('收藏页加载失败', e, s);
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadError = true;
        });
      }
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
    final favorites = context.read<LearningFavoritesStore>();
    final toRemove = _selectedIndices.map((i) => _words[i].word).toList();

    // 审计 I4：统一确认弹窗
    final confirmed = await showMwConfirm(context, title: '确认删除', content: '确定要从单词本移除 ${toRemove.length} 个单词吗？');

    if (confirmed == true) {
      for (final word in toRemove) {
        await favorites.toggle(word);
      }
      // 确认弹窗与逐词 toggle 都是 async gap：期间页面可能已被移出树，
      // 再走 setState/context.read 会触发 use-after-dispose（单条删除
      // 路径已有同款守卫，这里对齐口径）。
      if (!mounted) return;
      _toggleBatchEdit();
      await _loadData();
    }
  }

  /// 开始学习收藏单词
  Future<void> _startLearning() async {
    await context.read<LearningSessionStarter>().startFavoritesSession(
      limit: context.read<PresentationPrefs>().dailyGoal,
    );
    if (mounted) {
      Navigator.pushNamed(context, RouteNames.learnSession);
    }
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final favorites = context.watch<LearningFavoritesStore>();

    return Scaffold(
      backgroundColor: skin.colors.pageBg,
      body: SafeArea(
        child: Column(
          children: [
            // 导航栏
            _buildNavBar(skin, favorites),
            Container(height: 1, color: skin.colors.divider),
            // 内容区
            Expanded(
              child: _isLoading
                  ? Center(child: CircularProgressIndicator(color: context.skin.colors.accent))
                  : _loadError
                  ? _buildErrorView(skin)
                  : _words.isEmpty
                  ? _buildEmptyView(skin)
                  : _buildWordList(skin),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavBar(SkinSystem skin, LearningFavoritesStore favorites) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxs),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
            color: skin.colors.text1,
            tooltip: '返回',
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 4),
          Text('单词本', style: MwTypography.heading5.copyWith(color: skin.colors.text1)),
          const SizedBox(width: 8),
          // 收藏数量徽章
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: context.skin.colors.accent.withValues(alpha: AppAlphas.o10),
              borderRadius: BorderRadius.circular(context.design.radius.sm),
            ),
            child: Text(
              '${favorites.favoriteCount}',
              style: MwTypography.captionBold.copyWith(color: context.skin.colors.accent),
            ),
          ),
          const Spacer(),
          if (_isBatchEditMode) ...[
            TextButton(
              onPressed: _selectAll,
              child: Text(
                _selectedIndices.length == _words.length ? '取消全选' : '全选',
                style: TextStyle(color: context.skin.colors.accent),
              ),
            ),
            TextButton(
              onPressed: _batchRemoveFavorites,
              child: Text('删除', style: TextStyle(color: context.skin.colors.danger)),
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

/// 加载失败态：重试入口（不再永久转圈）。
  Widget _buildErrorView(SkinSystem skin) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_off_rounded, size: 48, color: skin.colors.text3),
          const SizedBox(height: AppSpacing.md),
          Text('收藏加载失败，请稍后重试', style: MwTypography.bodyMd.copyWith(color: skin.colors.text2)),
          const SizedBox(height: AppSpacing.md),
          FilledButton(
            onPressed: _loadData,
            style: FilledButton.styleFrom(backgroundColor: skin.colors.accent),
            child: const Text('重试'),
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
          Icon(Icons.book_outlined, size: 64, color: skin.colors.text3),
          const SizedBox(height: 16),
          Text('单词本为空', style: MwTypography.heading5.copyWith(color: skin.colors.text1)),
          const SizedBox(height: 8),
          Text('学习时点击心形图标收藏单词', style: MwTypography.body.copyWith(color: skin.colors.text3)),
          const SizedBox(height: 16),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, RouteNames.libSelect);
                },
                icon: const Icon(Icons.explore_outlined, size: 18),
                label: const Text('去选词书'),
              ),
              const SizedBox(width: 12),
              TextButton.icon(onPressed: _loadData, icon: const Icon(Icons.refresh, size: 18), label: const Text('刷新')),
            ],
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
            padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.xxs),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _startLearning,
                icon: const Icon(Icons.play_arrow, size: 22),
                label: Text('学习单词本 (${_words.length} 词)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.skin.colors.accent,
                  foregroundColor: AppColors.white100,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(context.design.radius.lg)),
                  elevation: 0,
                ),
              ),
            ),
          ),
        // 单词列表
        Expanded(
          child: ListView.builder(
            itemCount: _words.length,
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            itemBuilder: (context, index) {
              final word = _words[index];
              final isSelected = _selectedIndices.contains(index);

              return Dismissible(
                key: ValueKey(word.id),
                direction: _isBatchEditMode ? DismissDirection.none : DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: AppSpacing.lg),
                  color: context.skin.colors.danger,
                  child: const Icon(Icons.delete, color: AppColors.white100),
                ),
                confirmDismiss: (direction) async {
                  // 审计 I4：统一确认弹窗
                  return await showMwConfirm(
                    context,
                    title: '确认移除',
                    content: '确定要将 "${word.word}" 从单词本移除吗？',
                    confirmLabel: '移除',
                  );
                },
                onDismissed: (direction) async {
                  final favorites = context.read<LearningFavoritesStore>();
                  await favorites.toggle(word.word);
                  // 内存审计 P2：await 后页面可能已出栈，setState 需存活检查
                  if (!mounted) return;
                  setState(() => _words.removeAt(index));
                },
                child: ListTile(
                  onTap: _isBatchEditMode
                      ? () => _toggleSelect(index)
                      : () => Navigator.pushNamed(context, RouteNames.wordDetail, arguments: word),
                  leading: _isBatchEditMode
                      ? Checkbox(
                          value: isSelected,
                          onChanged: (_) => _toggleSelect(index),
                          activeColor: context.skin.colors.accent,
                        )
                      : null,
                  title: Text(word.word, style: MwTypography.heading5.copyWith(color: skin.colors.text1)),
                  subtitle: word.firstInterpretLine.isNotEmpty
                      ? Text(
                          word.firstInterpretLine,
                          style: MwTypography.bodySm.copyWith(color: skin.colors.text3),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        )
                      : (word.usPron.isNotEmpty
                            ? Text('/${word.usPron}/', style: MwTypography.bodySm.copyWith(color: skin.colors.text3))
                            : null),
                  trailing: _isBatchEditMode ? null : Icon(Icons.chevron_right, color: skin.colors.text3),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
