// 由 Claude 团队生成 | Monster Word App

// 单词列表基类：支持滑动删除、批量编辑、字母快速索引
// 归属：learning 功能域（仅被本域单词列表子页继承）

import 'package:flutter/material.dart';

import 'package:word_app/app/router/route_names.dart';
import 'package:word_app/theme/skin_system.dart';
import 'package:word_app/tokens/design_tokens.dart';
import 'package:word_app/models/word.dart';
import 'package:word_app/widgets/common/mw_empty_state.dart';
import 'package:word_app/widgets/common/mw_skeleton.dart';

/// 单词列表页基类，具体子类通过 [loadWordsForContext] 提供数据
abstract class ListWordsPage extends StatefulWidget {
  const ListWordsPage({super.key});
}

abstract class ListWordsPageState<T extends ListWordsPage> extends State<T> {
  List<Word> _words = [];
  bool _isLoading = true;
  bool _isBatchEditMode = false;
  final Set<int> _selectedIndices = {};

  /// 获取已加载的单词列表（子类可直接使用，避免重复加载）
  List<Word> get words => _words;

  /// 是否正在加载
  bool get isLoading => _isLoading;

  /// 刷新数据
  Future<void> refreshData() => _loadData();

  String get pageTitle;

  /// 从功能域读取边界加载词表。
  ///
  /// 子类必须显式选择词书、收藏、掌握、生词或队列分类的读取端口，避免通用页面
  /// 重新依赖遗留学习兼容外观。
  Future<List<Word>> loadWordsForContext(BuildContext context);

  /// 子类可覆盖以持久化移除当前词条；默认保持既有仅移除页面列表的行为。
  Future<bool> removeWord(Word word) async => true;

  /// 子类可提供的主操作按钮（如「开始学习」FAB）；默认无
  Widget? get learningFab => null;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final words = await loadWordsForContext(context);
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
      floatingActionButton: learningFab,
      body: SafeArea(
        child: Column(
          children: [
            _buildNavBar(skin),
            Container(height: 1, color: skin.colors.divider),
            Expanded(
              child: _isLoading
                  ? const MwSkeletonPage()
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
            tooltip: '返回',
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 4),
          Text(pageTitle, style: MwTypography.heading5.copyWith(color: skin.colors.text1)),
          if (!_isLoading && _words.isNotEmpty) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: skin.colors.accent.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '${_words.length}',
                style: MwTypography.micro.copyWith(
                  color: skin.colors.accent,
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
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
    return MwEmptyState(
      kind: MwEmptyKind.empty,
      title: '暂无单词',
      subtitle: '去学习或收藏一些单词，这里就会显示',
      actionLabel: '刷新',
      onAction: () => _loadData(),
    );
  }

  Widget _buildWordList(SkinSystem skin) {
    return ListView.builder(
      itemCount: _words.length,
      padding: const EdgeInsets.symmetric(vertical: 8),
      addAutomaticKeepAlives: false,
      addRepaintBoundaries: true,
      itemBuilder: (context, index) {
        final word = _words[index];
        final isSelected = _selectedIndices.contains(index);

        return Dismissible(
          key: ValueKey(word.id),
          direction: _isBatchEditMode ? DismissDirection.none : DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            color: context.skin.colors.danger,
            child: const Icon(Icons.delete, color: AppColors.white100),
          ),
          confirmDismiss: (direction) async {
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('确认删除'),
                content: Text('确定要删除 "${word.word}" 吗？'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
                  TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('删除')),
                ],
              ),
            );
            if (confirmed != true) return false;
            return removeWord(word);
          },
          onDismissed: (direction) {
            setState(() => _words.remove(word));
          },
          child: Material(
            color: skin.colors.pageBg,
            child: InkWell(
              onTap: _isBatchEditMode ? () => _toggleSelect(index) : () => _openWordDetail(word),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                    child: Row(
                      children: [
                        if (_isBatchEditMode) ...[
                          Checkbox(
                            value: isSelected,
                            onChanged: (_) => _toggleSelect(index),
                            activeColor: context.skin.colors.accent,
                          ),
                          const SizedBox(width: 4),
                        ],
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Flexible(
                                    child: Text(
                                      word.word,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: MwTypography.bodyMd.copyWith(
                                        color: skin.colors.text1,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  if (word.usPron.isNotEmpty) ...[
                                    const SizedBox(width: 8),
                                    Text(
                                      '/${word.usPron}/',
                                      style: MwTypography.micro.copyWith(color: skin.colors.text3),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ],
                              ),
                              if (word.firstInterpretLine.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  word.firstInterpretLine,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: MwTypography.bodySm.copyWith(color: skin.colors.text3, height: 1.4),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(Icons.chevron_right, size: 18, color: skin.colors.text3),
                      ],
                    ),
                  ),
                  Divider(height: 0.5, thickness: 0.5, indent: 16, color: skin.colors.divider),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _openWordDetail(Word word) {
    Navigator.pushNamed(context, RouteNames.wordDetail, arguments: word);
  }
}
