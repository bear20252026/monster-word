// 由 Claude 团队生成 | Monster Word App
// 句库页面：显示用户收藏的所有例句
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:word_app/features/word_browse/application/sentence_favorites_store.dart';
import 'package:word_app/features/content/presentation/sentence_learning_page.dart';
import 'package:word_app/app/router/route_names.dart';
import 'package:word_app/models/sentence_models.dart';
import 'package:word_app/theme/skin_system.dart';
import 'package:word_app/tokens/design_tokens.dart';
import 'package:word_app/utils/date_format_utils.dart';
import 'package:word_app/widgets/flow_in.dart';
import 'package:word_app/widgets/mw_card.dart';
import 'package:word_app/widgets/scale_down_on_press.dart';
import 'package:word_app/widgets/mw_nav_bar.dart';
import 'package:word_app/widgets/common/mw_feedback.dart';

class MyFavSentencePage extends StatefulWidget {
  const MyFavSentencePage({super.key});

  static const routeName = RouteNames.myFavSentence;

  @override
  State<MyFavSentencePage> createState() => _MyFavSentencePageState();
}

class _MyFavSentencePageState extends State<MyFavSentencePage> {
  static const int _pageSize = 50;

  List<FavSentenceData> _sentences = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = false;
  int _total = 0;
  bool _isEditMode = false;
  Set<int> _selectedIndices = {};

  /// 页面会话内已入场过的例句 key（wordId-sentenceId）：滚动往返/勾选等
  /// 重建不重放入场波次（同 book_words_page，perf 2026-09-29）。
  final Set<String> _enteredSentenceKeys = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  /// MEM/U3+分页：总量走 COUNT 口径，列表只加载首页窗口。
  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final store = context.read<SentenceFavoritesStore>();
      final total = await store.count();
      final sentences = await store.listPage(limit: _pageSize);
      if (mounted) {
        setState(() {
          _total = total;
          _sentences = sentences;
          _hasMore = sentences.length < total;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _sentences = [];
          _total = 0;
          _hasMore = false;
          _isLoading = false;
        });
      }
    }
  }

  /// MEM/U3+分页：临近窗口末尾预取下一页（幂等，可安全重复触发）。
  Future<void> _loadMore() async {
    if (!_hasMore || _isLoadingMore || _isLoading) return;
    _isLoadingMore = true;
    try {
      final more = await context.read<SentenceFavoritesStore>().listPage(limit: _pageSize, offset: _sentences.length);
      if (mounted) {
        setState(() {
          _sentences = [..._sentences, ...more];
          _hasMore = more.length >= _pageSize;
        });
      }
    } catch (_) {
      // 保持当前窗口，下次滚动重试
    } finally {
      _isLoadingMore = false;
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
                  ? Center(child: CircularProgressIndicator(color: context.skin.colors.accent))
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
    // 审计 I1：实现收敛至 MwNavBar 单一真相
    return MwNavBar(
      title: '句库',
      onBack: () => Navigator.pop(context),
      trailing: _sentences.isNotEmpty
          ? TextButton(
              onPressed: () {
                setState(() {
                  _isEditMode = !_isEditMode;
                  _selectedIndices.clear();
                });
              },
              child: Text(
                _isEditMode ? '完成' : '编辑',
                style: MwTypography.bodySm.copyWith(color: context.skin.colors.accent),
              ),
            )
          : null,
    );
  }

  Widget _buildStatsBar(SkinSystem skin) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      child: Row(
        children: [
          Icon(Icons.format_quote, size: 18, color: skin.colors.text3),
          const SizedBox(width: 8),
          Text('共 $_total 个例句', style: MwTypography.bodySm.copyWith(color: skin.colors.text2)),
          const Spacer(),
          // 学习按钮
          if (_sentences.isNotEmpty && !_isEditMode)
            ScaleDownOnPress(
              onTap: _startLearning,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: context.skin.colors.accent,
                  borderRadius: BorderRadius.circular(context.design.radius.pill),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.play_arrow, size: 16, color: AppColors.white100),
                    const SizedBox(width: 4),
                    Text('开始学习', style: MwTypography.micro.copyWith(color: AppColors.white100)),
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
          Text('暂无收藏例句', style: MwTypography.body.copyWith(color: skin.colors.text3)),
          const SizedBox(height: 8),
          Text('在单词详情页点击心形图标收藏例句', style: MwTypography.bodySm.copyWith(color: skin.colors.text3)),
        ],
      ),
    );
  }

  Widget _buildList(SkinSystem skin) {
    return ListView.builder(
      // MEM/U3+分页：+1 为未到底时的底部加载指示项
      itemCount: _sentences.length + (_hasMore ? 1 : 0),
      padding: const EdgeInsets.all(AppSpacing.md),
      itemBuilder: (context, index) {
        if (index >= _sentences.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        // 临近窗口末尾预取下一页（_loadMore 自幂等）
        if (_hasMore && index >= _sentences.length - 10) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _loadMore();
          });
        }
        final favSentence = _sentences[index];
        final sentenceData = favSentence.sentenceData;
        if (sentenceData == null) return const SizedBox.shrink();

        final isSelected = _selectedIndices.contains(index);

        // MwCard（v2.7.48）：24px 圆角 + 双层阴影 + ScaleDownOnPress 按压反馈，
        // 与词典详情页卡片风格统一。编辑态选中视觉改为 primary 淡底色 +
        // 行首 check_circle 图标（原 2px 描边废弃，图标本身已明确传达选中态）。
        // 有序流动入场（与词书网格/单词浏览页同一动效语言）：首屏十张走完整
        // 波次；翻页新卡单列相位 0 入场，近乎立即不排队。key 绑词+例句 id；
        // 入场一次后（_enteredSentenceKeys）同卡重建走静终态，不再重放。
        final favKey = '${favSentence.wordId}-${favSentence.sentenceId}';
        final firstTime = _enteredSentenceKeys.add(favKey);
        final waveIndex = index < 10 ? index : 0;
        final card = MwCard(
          onTap: () {
            if (_isEditMode) {
              setState(() {
                if (isSelected) {
                  _selectedIndices.remove(index);
                } else {
                  _selectedIndices.add(index);
                }
              });
            } else {
              // 非编辑态：进入例句详情页（batch5 接通孤儿页）。
              Navigator.pushNamed(
                context,
                RouteNames.sentenceDetail,
                arguments: <String, dynamic>{
                  'word': favSentence.word,
                  'sentence': sentenceData.e,
                  'translation': sentenceData.c,
                  'source': sentenceData.b,
                },
              );
            }
          },
          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
          color: isSelected ? context.skin.colors.accent.withValues(alpha: AppAlphas.o06) : skin.colors.cardBgAlt,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
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
                        color: isSelected ? context.skin.colors.accent : skin.colors.text3,
                      ),
                      const SizedBox(width: 8),
                    ],
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: context.skin.colors.accent.withValues(alpha: AppAlphas.o10),
                        borderRadius: BorderRadius.circular(context.design.radius.sm),
                      ),
                      child: Text(
                        favSentence.word,
                        style: MwTypography.bodySm.copyWith(
                          color: context.skin.colors.accent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      // L2 收口：共享 formatMonthDay（v2.7.51），不再手写 substring 解析
                      formatMonthDay(favSentence.updateTime),
                      style: MwTypography.micro.copyWith(color: skin.colors.text3),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // 英文例句
                Text(sentenceData.e, style: MwTypography.body.copyWith(color: skin.colors.text1, height: 1.5)),
                // 中文翻译
                if (sentenceData.c.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(sentenceData.c, style: MwTypography.bodySm.copyWith(color: skin.colors.text3)),
                ],
                // 来源
                if (sentenceData.b.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    '— ${sentenceData.b}',
                    style: MwTypography.micro.copyWith(color: skin.colors.text3, fontStyle: FontStyle.italic),
                  ),
                ],
              ],
            ),
          ),
        );
        return firstTime
            ? FlowIn(key: ValueKey('fav-sentence-flow-$favKey'), index: waveIndex, child: card)
            : KeyedSubtree(key: ValueKey('fav-sentence-flow-$favKey'), child: card);
      },
    );
  }

  Widget _buildEditModeBar(SkinSystem skin) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
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
              style: MwTypography.bodySm.copyWith(color: skin.colors.text2),
            ),
          ),
          const Spacer(),
          // 删除选中
          ElevatedButton(
            onPressed: _selectedIndices.isEmpty ? null : _deleteSelected,
            style: ElevatedButton.styleFrom(
              backgroundColor: context.skin.colors.danger,
              foregroundColor: AppColors.white100,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(context.design.radius.md)),
            ),
            child: Text('删除 (${_selectedIndices.length})'),
          ),
        ],
      ),
    );
  }

  Future<void> _startLearning() async {
    // MEM/U3+分页：学习动作需要全量，点击时一次性拉取（瞬时使用，不常驻内存）
    final all = await context.read<SentenceFavoritesStore>().list();
    final learnable = all.where((s) => (s.sentenceData?.e ?? '').isNotEmpty).toList();
    if (!mounted) return;
    if (learnable.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('暂无可学习的例句')));
      return;
    }
    await startSentenceLearning(context, learnable);
  }

  Future<void> _deleteSelected() async {
    final favStore = context.read<SentenceFavoritesStore>();
    // 审计 I4：统一确认弹窗（危险操作 danger 色）
    final confirmed = await showMwConfirm(
      context,
      title: '确认删除',
      content: '确定要删除选中的 ${_selectedIndices.length} 个例句吗？',
      confirmLabel: '删除',
      danger: true,
    );
    if (!mounted) return;

    if (confirmed != true) return;

    // 审计 I19：批量删除走单事务（此前 N 次独立事务往返且中途失败留半删状态）
    final items = _selectedIndices
        .map((index) => (wordId: _sentences[index].wordId, sentenceId: _sentences[index].sentenceId))
        .toList();
    await favStore.removeBatch(items: items);

    // 内存审计 P2：批量删除耗时较长，await 后页面可能已出栈
    if (!mounted) return;
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
