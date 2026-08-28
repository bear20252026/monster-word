// 由 Claude 团队生成 | Monster Word App

// 适配器层：翻译自 adapter/（v3.2 源码 22 个类）
// 本文件包含所有列表/分页适配器的 Flutter 实现
// 原始类：IndexPath, PopFilterListItemAdapter, IconListItemAdapter,
//         PlayOrderListAdapter, ListWordActionAdapter, ViewPagerAdapter,
//         LearnReviewResultWordAdapter, LearnCardViewPagerAdapter,
//         BaseSentenceCardPagerAdapter, LearnCardSentencePagerAdapter,
//         NewWordRecycleViewAdapter, RootSuffixGroupAdapter,
//         SelectLibraryAdapter, MessageListAdapter, WordListenAdapter,
//         CandidateAdapter, ListWordAdapter, ListWordResultModel,
//         SentenceSortResultModel, FavSentenceViewPagerAdapter,
//         FavCardSentencePagerAdapter, FavSentenceRecycleViewAdapter

import 'dart:convert';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

// ============================================================================
// IndexPath - 索引路径（section + row）
// ============================================================================

/// 索引路径（翻译自 IndexPath.java）
class IndexPath {
  final int section;
  final int row;

  const IndexPath(this.section, this.row);

  @override
  String toString() => 'IndexPath ($section,$row)';
}

// ============================================================================
// PopFilterListItemAdapter - 弹出筛选列表
// ============================================================================

/// 弹出筛选列表项数据（翻译自 BaseItemTypeInfo）
class PopFilterItemInfo {
  final String title;
  final String subtitle;
  final IconData? icon;
  final bool isSelected;

  const PopFilterItemInfo({this.title = '', this.subtitle = '', this.icon, this.isSelected = false});
}

/// 弹出筛选列表适配器（翻译自 PopFilterListItemAdapter.java）
class PopFilterListView extends StatelessWidget {
  final List<PopFilterItemInfo> items;
  final int selectedIndex;
  final ValueChanged<int>? onItemSelected;

  const PopFilterListView({super.key, required this.items, this.selectedIndex = -1, this.onItemSelected});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final isSelected = index == selectedIndex;
        return _PopFilterCellView(item: item, isSelected: isSelected, onTap: () => onItemSelected?.call(index));
      },
    );
  }
}

/// 兼容颜色常量
const Color _accent = AppColors.primary;
const Color _accentGreen = AppColors.successGreen;
const Color _accentRed = AppColors.errorRed;
const Color _black54 = AppColors.black54;
const Color _black87 = AppColors.black87;
const Color _black12 = AppColors.black12;

class _PopFilterCellView extends StatelessWidget {
  final PopFilterItemInfo item;
  final bool isSelected;
  final VoidCallback? onTap;

  const _PopFilterCellView({required this.item, this.isSelected = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            if (item.icon != null) ...[Icon(item.icon, size: 24, color: _black54), const SizedBox(width: 12)],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title, style: TextStyle(fontSize: 16, color: isSelected ? _accent : _black87)),
                  if (item.subtitle.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(item.subtitle, style: const TextStyle(fontSize: 13, color: _black54)),
                  ],
                ],
              ),
            ),
            if (isSelected) Icon(Icons.check, size: 20, color: _accent),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// IconListItemAdapter - 带图标的列表项
// ============================================================================

/// 图标列表项数据（翻译自 BaseItemInfo）
class IconListItemInfo {
  final String title;
  final String subtitle;
  final IconData? icon;
  final dynamic tag;

  const IconListItemInfo({this.title = '', this.subtitle = '', this.icon, this.tag});
}

/// 带图标的列表适配器（翻译自 IconListItemAdapter.java）
class IconListView extends StatelessWidget {
  final List<IconListItemInfo> items;
  final ValueChanged<int>? onItemTap;
  final ValueChanged<int>? onIconTap;

  const IconListView({super.key, required this.items, this.onItemTap, this.onIconTap});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return GestureDetector(
          onTap: () => onItemTap?.call(index),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                if (item.icon != null)
                  GestureDetector(
                    onTap: () => onIconTap?.call(index),
                    child: Icon(item.icon, size: 24, color: _black54),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.title, style: const TextStyle(fontSize: 16)),
                      if (item.subtitle.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(item.subtitle, style: const TextStyle(fontSize: 13, color: _black54)),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ============================================================================
// PlayOrderListAdapter - 播放顺序列表
// ============================================================================

/// 播放顺序列表适配器（翻译自 PlayOrderListAdapter.java）
class PlayOrderListView extends StatelessWidget {
  final List<String> words;
  final String? currentPlayWord;

  const PlayOrderListView({super.key, required this.words, this.currentPlayWord});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: words.length,
      itemBuilder: (context, index) {
        final word = words[index];
        final isPlaying = word == currentPlayWord;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  word,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: isPlaying ? FontWeight.bold : FontWeight.normal,
                    color: isPlaying ? _accent : _black87,
                  ),
                ),
              ),
              if (isPlaying) Icon(Icons.volume_up, size: 20, color: _accent),
            ],
          ),
        );
      },
    );
  }
}

// ============================================================================
// ListWordActionAdapter - 单词操作列表
// ============================================================================

/// 单词操作类型常量（翻译自 ListWordActionAdapter.java）
class ListWordActionType {
  static const int batchEdit = 1;
  static const int listen = 2;
  static const int spell = 3;
  static const int share = 4;
}

/// 单词操作列表适配器（翻译自 ListWordActionAdapter.java）
class ListWordActionView extends StatelessWidget {
  final List<int> actionTypes;
  final ValueChanged<int>? onActionTap;

  const ListWordActionView({super.key, required this.actionTypes, this.onActionTap});

  String _getDisplayName(int actionType) {
    switch (actionType) {
      case ListWordActionType.batchEdit:
        return '批量编辑';
      case ListWordActionType.listen:
        return '听写';
      case ListWordActionType.spell:
        return '拼写';
      case ListWordActionType.share:
        return '分享';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: actionTypes.length,
      itemBuilder: (context, index) {
        final actionType = actionTypes[index];
        return GestureDetector(
          onTap: () => onActionTap?.call(actionType),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Text(_getDisplayName(actionType), style: const TextStyle(fontSize: 16)),
          ),
        );
      },
    );
  }
}

// ============================================================================
// SelectLibraryAdapter - 词书选择列表
// ============================================================================

/// 词书数据（翻译自 LibBook 相关字段）
class LibBookInfo {
  final int bookId;
  final String name;
  final String desc;
  final int count;
  final String? coverUrl;
  final bool isHistoryLib;
  final bool isOnlyHistoryLib;
  final bool isForSale;
  final bool hasBought;

  const LibBookInfo({
    this.bookId = 0,
    this.name = '',
    this.desc = '',
    this.count = 0,
    this.coverUrl,
    this.isHistoryLib = false,
    this.isOnlyHistoryLib = false,
    this.isForSale = false,
    this.hasBought = false,
  });
}

/// 词书选择列表适配器（翻译自 SelectLibraryAdapter.java）
class SelectLibraryView extends StatelessWidget {
  final List<LibBookInfo> books;
  final int? currentBookId;
  final bool showHistoryTag;
  final ValueChanged<int>? onBookTap;
  final ValueChanged<int>? onRemoveBook;

  const SelectLibraryView({
    super.key,
    required this.books,
    this.currentBookId,
    this.showHistoryTag = false,
    this.onBookTap,
    this.onRemoveBook,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: books.length,
      itemBuilder: (context, index) {
        final book = books[index];
        final isCurrentBook = book.bookId == currentBookId;
        return GestureDetector(
          onTap: () => onBookTap?.call(index),
          child: Container(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // 封面图
                Container(
                  width: 60,
                  height: 80,
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(4), color: _black12),
                  child: book.coverUrl != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Image.network(
                            book.coverUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Icon(Icons.book, color: _black54),
                          ),
                        )
                      : Icon(Icons.book, color: _black54),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(book.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 4),
                      Text(
                        book.desc,
                        style: const TextStyle(fontSize: 13, color: _black54),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text('${book.count}词', style: const TextStyle(fontSize: 12, color: _black54)),
                    ],
                  ),
                ),
                if (isCurrentBook) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: _accent, borderRadius: BorderRadius.circular(4)),
                    child: const Text('当前', style: TextStyle(fontSize: 11, color: AppColors.white100)),
                  ),
                ],
                if (book.isHistoryLib && showHistoryTag && !isCurrentBook) ...[
                  GestureDetector(
                    onTap: () => onRemoveBook?.call(index),
                    child: const Icon(Icons.close, size: 20, color: _black54),
                  ),
                ],
                if (book.isForSale) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: book.hasBought ? _accent : _black12,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      book.hasBought ? '已购' : '付费',
                      style: TextStyle(fontSize: 11, color: book.hasBought ? AppColors.white100 : _black87),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

// ============================================================================
// CandidateAdapter - 候选单词列表
// ============================================================================

/// 候选单词数据
class CandidateWordInfo {
  final String word;
  final String interpret;

  const CandidateWordInfo({this.word = '', this.interpret = ''});

  /// 是否有结构化释义
  bool get hasStructuredDefinitions => _cachedDefs?.isNotEmpty ?? false;

  /// 格式化结构化释义（用于显示）
  String get formattedDefinitions {
    final defs = _cachedDefs;
    if (defs == null || defs.isEmpty) return interpret;
    final lines = <String>[];
    for (final def in defs) {
      final cn = def['cn'] ?? '';
      final en = def['en'] ?? '';
      if (cn.isNotEmpty) {
        lines.add(cn);
      } else if (en.isNotEmpty) {
        lines.add(en);
      }
    }
    return lines.join('\n');
  }

  List<Map<String, String>>? get _cachedDefs {
    if (interpret.isEmpty) return null; // 提前返回，避免对空字符串做无意义的 jsonDecode
    try {
      final decoded = jsonDecode(interpret);
      if (decoded is List) {
        final result = <Map<String, String>>[];
        for (final item in decoded) {
          if (item is Map && item['def'] is List) {
            for (final def in item['def']) {
              if (def is Map) {
                result.add({
                  'cn': (def['cn'] ?? def['cndef'] ?? '').toString(),
                  'en': (def['en'] ?? def['endef'] ?? '').toString(),
                });
              }
            }
          }
        }
        return result;
      }
    } catch (_) {}
    return null;
  }
}

/// 候选单词列表适配器（翻译自 CandidateAdapter.java）
class CandidateListView extends StatelessWidget {
  final List<CandidateWordInfo> words;
  final ValueChanged<int>? onWordTap;

  const CandidateListView({super.key, required this.words, this.onWordTap});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: words.length,
      itemBuilder: (context, index) {
        final wordInfo = words[index];
        final meaningText = wordInfo.hasStructuredDefinitions ? wordInfo.formattedDefinitions : wordInfo.interpret;
        return GestureDetector(
          onTap: () => onWordTap?.call(index),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(wordInfo.word, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                if (meaningText.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    meaningText,
                    style: const TextStyle(fontSize: 13, color: _black54),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

// ============================================================================
// NewWordRecycleViewAdapter - 新词列表（横向滚动）
// ============================================================================

/// 新词列表适配器（翻译自 NewWordRecycleViewAdapter.java）
/// 用于横向滚动的单词列表
class NewWordHorizontalList extends StatelessWidget {
  final List<String> words;
  final bool hasMore;
  final bool isEnd;
  final ValueChanged<int>? onItemTap;
  final VoidCallback? onMoreTap;

  const NewWordHorizontalList({
    super.key,
    required this.words,
    this.hasMore = false,
    this.isEnd = false,
    this.onItemTap,
    this.onMoreTap,
  });

  @override
  Widget build(BuildContext context) {
    final itemCount = words.length + (hasMore ? 1 : 0);
    return SizedBox(
      height: 50,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: itemCount,
        itemBuilder: (context, index) {
          if (index == words.length) {
            // "查看更多" / "查看全部"
            return GestureDetector(
              onTap: onMoreTap,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  isEnd ? '查看全部' : '查看更多',
                  style: TextStyle(fontSize: 14, color: _accent, fontWeight: FontWeight.w500),
                ),
              ),
            );
          }
          return GestureDetector(
            onTap: () => onItemTap?.call(index),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(color: _black12, borderRadius: BorderRadius.circular(AppDimens.radiusNormal)),
              child: Text(words[index], style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
            ),
          );
        },
      ),
    );
  }
}

// ============================================================================
// MessageListAdapter - 消息列表
// ============================================================================

/// 消息数据（翻译自 MessageData 相关字段）
class MessageInfo {
  final int newsId;
  final String title;
  final String content;
  final String label;
  final int time;
  final bool hasRead;
  final String? imageUrl;
  final int actionType;
  final String actionData;

  const MessageInfo({
    this.newsId = 0,
    this.title = '',
    this.content = '',
    this.label = '',
    this.time = 0,
    this.hasRead = false,
    this.imageUrl,
    this.actionType = 0,
    this.actionData = '',
  });
}

/// 消息列表适配器（翻译自 MessageListAdapter.java）
class MessageListView extends StatelessWidget {
  final List<MessageInfo> messages;
  final bool hasMore;
  final ValueChanged<int>? onMessageTap;
  final VoidCallback? onLoadMore;

  const MessageListView({super.key, required this.messages, this.hasMore = false, this.onMessageTap, this.onLoadMore});

  String _getTimeLabel(int timestamp) {
    if (timestamp == 0) return '';
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    if (now.year > date.year) {
      return '${date.year}年${date.month}月${date.day}日   ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    }
    if (now.day > date.day) {
      return '${date.month}月${date.day}日   ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    }
    return '${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final itemCount = messages.length + (hasMore ? 1 : 0);
    return ListView.builder(
      itemCount: itemCount,
      itemBuilder: (context, index) {
        if (index == messages.length) {
          return GestureDetector(
            onTap: onLoadMore,
            child: Container(
              padding: const EdgeInsets.all(16),
              alignment: Alignment.center,
              child: const Text('加载更多', style: TextStyle(color: _black54)),
            ),
          );
        }
        final message = messages[index];
        return GestureDetector(
          onTap: () => onMessageTap?.call(index),
          child: Container(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 未读标记
                if (!message.hasRead)
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(top: 6, right: 8),
                    decoration: const BoxDecoration(color: AppColors.errorRed, shape: BoxShape.circle),
                  ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              message.title,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: message.hasRead ? _black54 : _black87,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            message.label.isNotEmpty ? '#${message.label}' : '#系统消息',
                            style: const TextStyle(fontSize: 12, color: _black54),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        message.content,
                        style: TextStyle(fontSize: 13, color: message.hasRead ? _black54 : _black87),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(_getTimeLabel(message.time), style: const TextStyle(fontSize: 12, color: _black54)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ============================================================================
// LearnReviewResultWordAdapter - 学习/复习结果单词列表
// ============================================================================

/// 学习/复习结果类型
class LearnReviewType {
  static const int learn = 1;
  static const int review = 2;
}

/// 学习结果数据
class LearnResultInfo {
  final String word;
  final int wordMark; // 0=未标记, 1=用户标记, 2=系统标记
  final int failedCount;
  final int duration; // 复习间隔天数
  final int familiarLevel;
  final List<String> interprets;
  bool isSelected;

  LearnResultInfo({
    this.word = '',
    this.wordMark = 0,
    this.failedCount = 0,
    this.duration = 0,
    this.familiarLevel = 0,
    this.interprets = const [],
    this.isSelected = false,
  });
}

/// 学习/复习结果单词列表（翻译自 LearnReviewResultWordAdapter.java）
class LearnReviewResultListView extends StatefulWidget {
  final List<LearnResultInfo> results;
  final int type; // LearnReviewType.learn 或 LearnReviewType.review

  const LearnReviewResultListView({super.key, required this.results, this.type = LearnReviewType.learn});

  @override
  State<LearnReviewResultListView> createState() => _LearnReviewResultListViewState();
}

class _LearnReviewResultListViewState extends State<LearnReviewResultListView> {
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: widget.results.length,
      itemBuilder: (context, index) {
        final result = widget.results[index];
        return GestureDetector(
          onTap: () {
            setState(() {
              result.isSelected = !result.isSelected;
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // 熟悉度标记（仅复习模式显示）
                    if (widget.type == LearnReviewType.review) ...[
                      _buildFamiliarFlag(result.familiarLevel),
                      const SizedBox(width: 8),
                    ],
                    // 单词
                    Expanded(
                      child: Text(result.word, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                    ),
                    // 状态
                    _buildStatusWidget(result),
                  ],
                ),
                // 释义（展开/收起）
                if (result.isSelected && result.interprets.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ...result.interprets.map(
                    (interpret) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(interpret, style: const TextStyle(fontSize: 14, color: _black54)),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFamiliarFlag(int level) {
    // 垂直等级指示器
    return Container(
      width: 4,
      height: 24,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(2), color: level > 0 ? _accent : _black12),
    );
  }

  Widget _buildStatusWidget(LearnResultInfo result) {
    if (widget.type == LearnReviewType.learn) {
      if (result.wordMark == 1) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, size: 16, color: _accent),
            const SizedBox(width: 4),
            const Text('已掌握', style: TextStyle(fontSize: 13, color: _accentGreen)),
          ],
        );
      }
      return Text('答错${result.failedCount}次', style: const TextStyle(fontSize: 13, color: _accentRed));
    }
    // 复习模式
    switch (result.wordMark) {
      case 2:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, size: 16, color: _accentGreen),
            const SizedBox(width: 4),
            const Text('已掌握', style: TextStyle(fontSize: 13, color: _accentGreen)),
          ],
        );
      case 1:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, size: 16, color: _accentGreen),
            const SizedBox(width: 4),
            const Text('已掌握', style: TextStyle(fontSize: 13, color: _accentGreen)),
          ],
        );
      case 3:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.refresh, size: 16, color: _accentRed),
            const SizedBox(width: 4),
            const Text('需重学', style: TextStyle(fontSize: 13, color: _accentRed)),
          ],
        );
      default:
        return Text('${result.duration}天后', style: const TextStyle(fontSize: 13, color: _black54));
    }
  }
}

// ============================================================================
// ViewPagerAdapter - 通用页面视图
// ============================================================================

/// 通用页面视图适配器（翻译自 ViewPagerAdapter.java）
/// 在 Flutter 中直接使用 PageView
class SimplePageView extends StatelessWidget {
  final List<Widget> pages;
  final PageController? controller;
  final ValueChanged<int>? onPageChanged;

  const SimplePageView({super.key, required this.pages, this.controller, this.onPageChanged});

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      controller: controller,
      onPageChanged: onPageChanged,
      itemCount: pages.length,
      itemBuilder: (context, index) => pages[index],
    );
  }
}

// ============================================================================
// LearnCardViewPagerAdapter - 学习卡片页面视图
// ============================================================================

/// 学习卡片数据（翻译自 LearnCardData）
class LearnCardData {
  final String word;
  final int wordId;
  final List<dynamic> cardItems; // RootSuffixData 或 AcceptationSentence

  const LearnCardData({this.word = '', this.wordId = 0, this.cardItems = const []});
}

/// 学习卡片页面视图（翻译自 LearnCardViewPagerAdapter.java）
class LearnCardPageView extends StatelessWidget {
  final LearnCardData? data;
  final PageController? controller;
  final ValueChanged<int>? onPageChanged;

  const LearnCardPageView({super.key, this.data, this.controller, this.onPageChanged});

  @override
  Widget build(BuildContext context) {
    if (data == null || data!.cardItems.isEmpty) {
      return const SizedBox.shrink();
    }
    return PageView.builder(
      controller: controller,
      onPageChanged: onPageChanged,
      itemCount: data!.cardItems.length,
      itemBuilder: (context, index) {
        // 根据数据类型构建不同的卡片
        return Center(child: Text('Card: ${data!.word} ($index)', style: const TextStyle(fontSize: 16)));
      },
    );
  }
}

// ============================================================================
// BaseSentenceCardPagerAdapter - 句子卡片基类
// ============================================================================

/// 句子数据（翻译自 SentenceData 相关字段）
class SentenceData {
  final String sentenceId;
  final String english;
  final String chinese;
  final String title;
  final String audio;
  final String image;
  final bool showChinese;

  const SentenceData({
    this.sentenceId = '',
    this.english = '',
    this.chinese = '',
    this.title = '',
    this.audio = '',
    this.image = '',
    this.showChinese = true,
  });
}

/// 句子卡片页面视图（翻译自 BaseSentenceCardPagerAdapter.java）
class SentenceCardPageView extends StatefulWidget {
  final List<SentenceData> sentences;
  final bool showChinese;
  final VoidCallback? onMoreTap;
  final VoidCallback? onSentenceTap;

  const SentenceCardPageView({
    super.key,
    required this.sentences,
    this.showChinese = true,
    this.onMoreTap,
    this.onSentenceTap,
  });

  @override
  State<SentenceCardPageView> createState() => _SentenceCardPageViewState();
}

class _SentenceCardPageViewState extends State<SentenceCardPageView> {
  bool _showOptions = false;

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      itemCount: widget.sentences.length,
      itemBuilder: (context, index) {
        final sentence = widget.sentences[index];
        return _buildSentenceCard(sentence);
      },
    );
  }

  Widget _buildSentenceCard(SentenceData sentence) {
    return GestureDetector(
      onTap: widget.onSentenceTap,
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.white100,
          borderRadius: BorderRadius.circular(AppleRadius.lg),
          boxShadow: [BoxShadow(color: AppColors.black12, blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题
            GestureDetector(
              onTap: widget.onMoreTap,
              child: Text(
                sentence.title,
                style: const TextStyle(fontSize: 12, color: _black54),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 12),
            // 英文句子
            Expanded(child: Text(sentence.english, style: const TextStyle(fontSize: 18, height: 1.5))),
            // 中文翻译
            if (widget.showChinese) ...[
              const SizedBox(height: 8),
              Text(
                sentence.chinese,
                style: const TextStyle(fontSize: 14, color: _black54),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            // 操作按钮
            if (_showOptions) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  GestureDetector(
                    onTap: () {
                      setState(() => _showOptions = false);
                    },
                    child: const Icon(Icons.close, size: 20, color: _black54),
                  ),
                  const SizedBox(width: 16),
                  GestureDetector(
                    onTap: widget.onMoreTap,
                    child: const Icon(Icons.headphones, size: 20, color: _black54),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// LearnCardSentencePagerAdapter - 学习卡片句子页面
// ============================================================================

/// 学习卡片句子页面（翻译自 LearnCardSentencePagerAdapter.java）
class LearnCardSentencePageView extends StatelessWidget {
  final List<SentenceData> sentences;
  final int wordId;
  final bool showChinese;

  const LearnCardSentencePageView({super.key, required this.sentences, this.wordId = 0, this.showChinese = true});

  @override
  Widget build(BuildContext context) {
    return SentenceCardPageView(sentences: sentences, showChinese: showChinese);
  }
}

// ============================================================================
// FavSentenceViewPagerAdapter - 收藏句子页面视图
// ============================================================================

/// 收藏句子数据
class FavSentenceInfo {
  final int wordId;
  final String sentenceId;
  final SentenceData sentenceData;

  const FavSentenceInfo({this.wordId = 0, this.sentenceId = '', required this.sentenceData});
}

/// 收藏句子页面视图（翻译自 FavSentenceViewPagerAdapter.java）
class FavSentencePageView extends StatelessWidget {
  final List<FavSentenceInfo> favSentences;
  final bool hasMore;
  final bool isEnd;
  final ValueChanged<int>? onItemTap;
  final VoidCallback? onMoreTap;

  const FavSentencePageView({
    super.key,
    required this.favSentences,
    this.hasMore = false,
    this.isEnd = false,
    this.onItemTap,
    this.onMoreTap,
  });

  @override
  Widget build(BuildContext context) {
    final itemCount = favSentences.length + (hasMore ? 1 : 0);
    return PageView.builder(
      itemCount: itemCount,
      itemBuilder: (context, index) {
        if (index == favSentences.length) {
          return GestureDetector(
            onTap: onMoreTap,
            child: Container(
              margin: const EdgeInsets.all(16),
              alignment: Alignment.center,
              child: Text(
                isEnd ? '查看全部' : '查看更多',
                style: TextStyle(fontSize: 16, color: _accent, fontWeight: FontWeight.w500),
              ),
            ),
          );
        }
        final favSentence = favSentences[index];
        final sentence = favSentence.sentenceData;
        return GestureDetector(
          onTap: () => onItemTap?.call(index),
          child: Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(AppleRadius.lg), color: AppColors.white100),
            child: Column(
              children: [
                // 封面图
                Expanded(
                  flex: 3,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(AppleRadius.lg)),
                      color: _black12,
                    ),
                    child: sentence.image.isNotEmpty
                        ? ClipRRect(
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(AppleRadius.lg)),
                            child: Image.network(
                              'https://img.beingfine.cn/${sentence.image}',
                              fit: BoxFit.cover,
                              width: double.infinity,
                              errorBuilder: (_, _, _) => Icon(Icons.image, size: 48, color: _black54),
                            ),
                          )
                        : Center(child: Icon(Icons.image, size: 48, color: _black54)),
                  ),
                ),
                // 句子内容
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          sentence.title,
                          style: const TextStyle(fontSize: 12, color: _black54),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Expanded(
                          child: Text(
                            sentence.english,
                            style: const TextStyle(fontSize: 15, height: 1.4),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ============================================================================
// FavCardSentencePagerAdapter - 收藏卡片句子页面
// ============================================================================

/// 收藏卡片句子页面（翻译自 FavCardSentencePagerAdapter.java）
class FavCardSentencePageView extends StatelessWidget {
  final List<FavSentenceInfo> favSentences;

  const FavCardSentencePageView({super.key, required this.favSentences});

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      itemCount: favSentences.length,
      itemBuilder: (context, index) {
        final sentence = favSentences[index].sentenceData;
        return SentenceCardPageView(sentences: [sentence]);
      },
    );
  }
}

// ============================================================================
// ListWordResultModel - 单词列表分组模型
// ============================================================================

/// 单词列表分组排序类型
class ListWordSortType {
  static const int time = 0;
  static const int prefix = 1;
  static const int alphabet = 2;
  static const int none = 3;
}

/// 单词列表分组模型（翻译自 ListWordResultModel.java）
class ListWordResultModel {
  final List<SectionClass> _sectionList = [];

  List<SectionClass> get sections => _sectionList;
  int get sectionCount => _sectionList.length;

  /// 解析单词列表，按指定类型分组
  void parse(List<dynamic> words, int sortType) {
    _sectionList.clear();
    String lastIndicator = '';

    for (final word in words) {
      String indicator;
      if (sortType == ListWordSortType.prefix) {
        indicator = word.word.substring(0, 1).toUpperCase();
      } else if (sortType == ListWordSortType.time) {
        indicator = word.updateTime;
      } else if (sortType == ListWordSortType.none) {
        indicator = '';
      } else {
        indicator = word.updateTime;
      }

      if (indicator != lastIndicator) {
        _sectionList.add(SectionClass(indicator: indicator));
      }
      _sectionList.last.rowList.add(word);
      lastIndicator = indicator;
    }
  }

  String sectionIndicatorAtIndex(IndexPath indexPath) {
    return _sectionList[indexPath.section].indicator;
  }

  String sectionListSizeTitleAtIndex(int section) {
    return '${_sectionList[section].rowList.length}词';
  }

  int rowCountForSection(int section) {
    return _sectionList[section].rowList.length;
  }

  dynamic listWordAtIndexPath(IndexPath indexPath) {
    return _sectionList[indexPath.section].rowList[indexPath.row];
  }

  void removeDataAtIndexPath(IndexPath indexPath) {
    final section = _sectionList[indexPath.section];
    section.rowList.removeAt(indexPath.row);
    if (section.rowList.isEmpty) {
      _sectionList.remove(section);
    }
  }

  void removeDataAtIndexPathList(List<IndexPath> indexPaths) {
    for (int i = indexPaths.length - 1; i >= 0; i--) {
      removeDataAtIndexPath(indexPaths[i]);
    }
  }
}

class SectionClass {
  String indicator;
  List<dynamic> rowList = [];

  SectionClass({this.indicator = ''});
}

// ============================================================================
// SentenceSortResultModel - 句子列表分组模型
// ============================================================================

/// 句子列表分组模型（翻译自 SentenceSortResultModel.java）
class SentenceSortResultModel {
  final List<SentenceSectionClass> _sectionList = [];

  List<SentenceSectionClass> get sections => _sectionList;
  int get sectionCount => _sectionList.length;

  /// 解析句子列表，按日期分组
  void parse(List<dynamic> sentences) {
    _sectionList.clear();
    String lastIndicator = '';

    for (final sentence in sentences) {
      final indicator = sentence.updateDate ?? '';

      if (indicator != lastIndicator) {
        _sectionList.add(SentenceSectionClass(indicator: indicator));
      }
      _sectionList.last.rowList.add(sentence);
      lastIndicator = indicator;
    }
  }

  String sectionFirstTitleAtIndex(int section) {
    return _sectionList[section].indicator;
  }

  String sectionSecondTitleAtIndex(int section) {
    return '${_sectionList[section].rowList.length}句';
  }

  int rowCountForSection(int section) {
    return _sectionList[section].rowList.length;
  }

  dynamic listSentenceAtIndexPath(IndexPath indexPath) {
    return _sectionList[indexPath.section].rowList[indexPath.row];
  }

  void removeDataAtIndexPath(IndexPath indexPath) {
    final section = _sectionList[indexPath.section];
    section.rowList.removeAt(indexPath.row);
    if (section.rowList.isEmpty) {
      _sectionList.remove(section);
    }
  }

  void removeDataAtIndexPathList(List<IndexPath> indexPaths) {
    for (int i = indexPaths.length - 1; i >= 0; i--) {
      removeDataAtIndexPath(indexPaths[i]);
    }
  }
}

class SentenceSectionClass {
  String indicator;
  List<dynamic> rowList = [];

  SentenceSectionClass({this.indicator = ''});
}

// ============================================================================
// ListWordAdapter - 单词列表适配器（带分组头部）
// ============================================================================

/// 单词列表项类型
class ListItemType {
  static const int item = 84; // 'T'
  static const int section = 89; // 'Y'
}

/// 单词列表项
class WordListItem {
  final int type;
  final IndexPath indexPath;

  const WordListItem(this.type, this.indexPath);
}

/// 单词列表适配器（翻译自 ListWordAdapter.java）
class SectionedWordListView extends StatefulWidget {
  final List<dynamic> words;
  final int sortType;
  final int? currentWordId;
  final bool isEditMode;
  final ValueChanged<int>? onItemTap;
  final ValueChanged<String>? onPlayAudio;

  const SectionedWordListView({
    super.key,
    required this.words,
    this.sortType = ListWordSortType.time,
    this.currentWordId,
    this.isEditMode = false,
    this.onItemTap,
    this.onPlayAudio,
  });

  @override
  State<SectionedWordListView> createState() => _SectionedWordListViewState();
}

class _SectionedWordListViewState extends State<SectionedWordListView> {
  final ListWordResultModel _resultModel = ListWordResultModel();
  final List<WordListItem> _itemList = [];

  @override
  void initState() {
    super.initState();
    _parseData();
  }

  @override
  void didUpdateWidget(SectionedWordListView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.words != widget.words || oldWidget.sortType != widget.sortType) {
      _parseData();
    }
  }

  void _parseData() {
    _resultModel.parse(widget.words, widget.sortType);
    _itemList.clear();
    for (int s = 0; s < _resultModel.sectionCount; s++) {
      _itemList.add(WordListItem(ListItemType.section, IndexPath(s, -1)));
      for (int r = 0; r < _resultModel.rowCountForSection(s); r++) {
        _itemList.add(WordListItem(ListItemType.item, IndexPath(s, r)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: _itemList.length,
      itemBuilder: (context, index) {
        final listItem = _itemList[index];
        if (listItem.type == ListItemType.section) {
          return _buildSectionHeader(listItem.indexPath);
        }
        return _buildWordItem(listItem.indexPath, index);
      },
    );
  }

  Widget _buildSectionHeader(IndexPath indexPath) {
    final indicator = _resultModel.sectionIndicatorAtIndex(indexPath);
    final sizeTitle = _resultModel.sectionListSizeTitleAtIndex(indexPath.section);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: _black12,
      child: Row(
        children: [
          if (indicator.isNotEmpty) ...[
            Text(
              indicator,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _black87),
            ),
            const SizedBox(width: 8),
          ],
          Text(sizeTitle, style: const TextStyle(fontSize: 13, color: _black54)),
        ],
      ),
    );
  }

  Widget _buildWordItem(IndexPath indexPath, int index) {
    final word = _resultModel.listWordAtIndexPath(indexPath);
    final isCurrentWord = widget.currentWordId != null && word.wordId == widget.currentWordId;

    return GestureDetector(
      onTap: () => widget.onItemTap?.call(index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            if (widget.isEditMode) ...[
              Icon(
                word.isSelected == true ? Icons.check_circle : Icons.radio_button_unchecked,
                size: 20,
                color: word.isSelected == true ? _accent : _black54,
              ),
              const SizedBox(width: 8),
            ],
            if (isCurrentWord && !widget.isEditMode) ...[
              Container(
                width: 4,
                height: 20,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(color: _accent, borderRadius: BorderRadius.circular(2)),
              ),
            ],
            Expanded(
              child: Text(
                word.word ?? '',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: isCurrentWord ? FontWeight.bold : FontWeight.normal,
                  color: isCurrentWord ? _accent : _black87,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// FavSentenceRecycleViewAdapter - 收藏句子列表（带分组）
// ============================================================================

/// 收藏句子列表适配器（翻译自 FavSentenceRecycleViewAdapter.java）
class FavSentenceSectionedListView extends StatefulWidget {
  final List<FavSentenceInfo> favSentences;
  final bool isEditMode;
  final int? currentWordId;
  final String? currentSentenceId;
  final ValueChanged<int>? onItemTap;

  const FavSentenceSectionedListView({
    super.key,
    required this.favSentences,
    this.isEditMode = false,
    this.currentWordId,
    this.currentSentenceId,
    this.onItemTap,
  });

  @override
  State<FavSentenceSectionedListView> createState() => _FavSentenceSectionedListViewState();
}

class _FavSentenceSectionedListViewState extends State<FavSentenceSectionedListView> {
  final SentenceSortResultModel _resultModel = SentenceSortResultModel();
  final List<WordListItem> _itemList = [];

  @override
  void initState() {
    super.initState();
    _parseData();
  }

  @override
  void didUpdateWidget(FavSentenceSectionedListView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.favSentences != widget.favSentences) {
      _parseData();
    }
  }

  void _parseData() {
    _resultModel.parse(widget.favSentences);
    _itemList.clear();
    for (int s = 0; s < _resultModel.sectionCount; s++) {
      _itemList.add(WordListItem(ListItemType.section, IndexPath(s, -1)));
      for (int r = 0; r < _resultModel.rowCountForSection(s); r++) {
        _itemList.add(WordListItem(ListItemType.item, IndexPath(s, r)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: _itemList.length,
      itemBuilder: (context, index) {
        final listItem = _itemList[index];
        if (listItem.type == ListItemType.section) {
          return _buildSectionHeader(listItem.indexPath);
        }
        return _buildSentenceItem(listItem.indexPath, index);
      },
    );
  }

  Widget _buildSectionHeader(IndexPath indexPath) {
    final title = _resultModel.sectionFirstTitleAtIndex(indexPath.section);
    final count = _resultModel.sectionSecondTitleAtIndex(indexPath.section);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: _black12,
      child: Row(
        children: [
          if (title.isNotEmpty) ...[
            Text(
              title,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _black87),
            ),
            const SizedBox(width: 8),
          ],
          Text(count, style: const TextStyle(fontSize: 13, color: _black54)),
        ],
      ),
    );
  }

  Widget _buildSentenceItem(IndexPath indexPath, int index) {
    final favSentence = _resultModel.listSentenceAtIndexPath(indexPath);
    if (favSentence == null) return const SizedBox.shrink();

    final sentence = favSentence.sentenceData;
    final isCurrent =
        widget.currentWordId != null &&
        widget.currentSentenceId != null &&
        favSentence.isSame(widget.currentWordId!, widget.currentSentenceId!);

    return GestureDetector(
      onTap: () => widget.onItemTap?.call(index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            if (widget.isEditMode) ...[
              Icon(
                favSentence.isSelected == true ? Icons.check_circle : Icons.radio_button_unchecked,
                size: 20,
                color: favSentence.isSelected == true ? _accent : _black54,
              ),
              const SizedBox(width: 8),
            ],
            // 封面图
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(4), color: _black12),
              child: sentence.image.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Image.network(
                        'https://img.beingfine.cn/${sentence.image}',
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Icon(Icons.image, size: 24, color: _black54),
                      ),
                    )
                  : Icon(Icons.image, size: 24, color: _black54),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    sentence.title,
                    style: const TextStyle(fontSize: 12, color: _black54),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    sentence.english,
                    style: TextStyle(
                      fontSize: 14,
                      color: isCurrent ? _accent : _black87,
                      fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (isCurrent && !widget.isEditMode) ...[
              Container(
                width: 4,
                height: 20,
                margin: const EdgeInsets.only(left: 8),
                decoration: BoxDecoration(color: _accent, borderRadius: BorderRadius.circular(2)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// WordListenAdapter - 单词听写页面视图
// ============================================================================

/// 单词听写数据
class WordListenData {
  final String word;
  final String? usPron;
  final String? ukPron;
  final String? interpret;
  final SentenceData? firstSentence;

  const WordListenData({this.word = '', this.usPron, this.ukPron, this.interpret, this.firstSentence});

  /// 是否有结构化释义
  bool get hasStructuredDefinitions => _cachedDefs?.isNotEmpty ?? false;

  /// 格式化结构化释义（用于显示）
  String get formattedDefinitions {
    final defs = _cachedDefs;
    if (defs == null || defs.isEmpty) return interpret ?? '';
    final lines = <String>[];
    for (final def in defs) {
      final cn = def['cn'] ?? '';
      final en = def['en'] ?? '';
      if (cn.isNotEmpty) {
        lines.add(cn);
      } else if (en.isNotEmpty) {
        lines.add(en);
      }
    }
    return lines.join('\n');
  }

  List<Map<String, String>>? get _cachedDefs {
    if (interpret == null) return null;
    try {
      final decoded = jsonDecode(interpret!);
      if (decoded is List) {
        final result = <Map<String, String>>[];
        for (final item in decoded) {
          if (item is Map && item['def'] is List) {
            for (final def in item['def']) {
              if (def is Map) {
                result.add({
                  'cn': (def['cn'] ?? def['cndef'] ?? '').toString(),
                  'en': (def['en'] ?? def['endef'] ?? '').toString(),
                });
              }
            }
          }
        }
        return result;
      }
    } catch (_) {}
    return null;
  }
}

/// 单词听写页面视图（翻译自 WordListenAdapter.java）
class WordListenPageView extends StatelessWidget {
  final List<WordListenData> words;
  final ValueChanged<String>? onPhoneticTap;
  final ValueChanged<String>? onSentencePlay;
  final ValueChanged<int>? onWordTap;

  const WordListenPageView({super.key, required this.words, this.onPhoneticTap, this.onSentencePlay, this.onWordTap});

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      itemCount: words.length,
      itemBuilder: (context, index) {
        final wordData = words[index];
        return _buildWordListenCard(wordData);
      },
    );
  }

  Widget _buildWordListenCard(WordListenData wordData) {
    final meaningText = wordData.hasStructuredDefinitions ? wordData.formattedDefinitions : wordData.interpret;
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: AppColors.white100, borderRadius: BorderRadius.circular(AppleRadius.lg)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 单词
          Text(wordData.word, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          // 音标
          if (wordData.usPron != null || wordData.ukPron != null) ...[
            Row(
              children: [
                if (wordData.usPron != null) ...[
                  GestureDetector(
                    onTap: () => onPhoneticTap?.call(wordData.usPron!),
                    child: Text('美 ${wordData.usPron}', style: const TextStyle(fontSize: 14, color: _black54)),
                  ),
                  const SizedBox(width: 16),
                ],
                if (wordData.ukPron != null) ...[
                  GestureDetector(
                    onTap: () => onPhoneticTap?.call(wordData.ukPron!),
                    child: Text('英 ${wordData.ukPron}', style: const TextStyle(fontSize: 14, color: _black54)),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),
          ],
          // 释义（优先结构化释义）
          if (meaningText != null && meaningText.isNotEmpty) ...[
            Text(meaningText, style: const TextStyle(fontSize: 16, height: 1.5)),
            const SizedBox(height: 16),
          ],
          // 例句
          if (wordData.firstSentence != null) ...[
            const Divider(),
            const SizedBox(height: 8),
            Text(wordData.firstSentence!.english, style: const TextStyle(fontSize: 15, height: 1.4)),
            const SizedBox(height: 8),
            Text(wordData.firstSentence!.chinese, style: const TextStyle(fontSize: 14, color: _black54)),
            const SizedBox(height: 8),
            Text('来自 ${wordData.firstSentence!.title}', style: const TextStyle(fontSize: 12, color: _black54)),
          ],
        ],
      ),
    );
  }
}

// ============================================================================
// RootSuffixGroupAdapter - 词根词缀分组列表
// ============================================================================

/// 词根词缀数据
class RootSuffixData {
  final String word;
  final String wordGrade;
  final String? highlight;
  final String? example;
  final List<String> rootSuffixList;
  final bool isNewWord;
  bool isFold;

  RootSuffixData({
    this.word = '',
    this.wordGrade = '',
    this.highlight,
    this.example,
    this.rootSuffixList = const [],
    this.isNewWord = false,
    this.isFold = true,
  });
}

/// 词根词缀分组数据
class RootSuffixGroupData {
  final List<RootSuffixData> items;
  bool isAllUnFold;

  RootSuffixGroupData({required this.items, this.isAllUnFold = false});

  int get count => items.length;

  RootSuffixData getData(int index) => items[index];

  void setAllFold() {
    for (final item in items) {
      item.isFold = true;
    }
    isAllUnFold = false;
  }

  void setAllUnFold() {
    for (final item in items) {
      item.isFold = false;
    }
    isAllUnFold = true;
  }
}

/// 词根词缀分组列表（翻译自 RootSuffixGroupAdapter.java）
class RootSuffixGroupListView extends StatefulWidget {
  final List<RootSuffixGroupData> groups;
  final String originalWord;
  final ValueChanged<String>? onWordTap;
  final ValueChanged<String>? onAddNewWord;

  const RootSuffixGroupListView({
    super.key,
    required this.groups,
    this.originalWord = '',
    this.onWordTap,
    this.onAddNewWord,
  });

  @override
  State<RootSuffixGroupListView> createState() => _RootSuffixGroupListViewState();
}

class _RootSuffixGroupListViewState extends State<RootSuffixGroupListView> {
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: widget.groups.length,
      itemBuilder: (context, groupIndex) {
        final group = widget.groups[groupIndex];
        return _buildGroup(groupIndex, group);
      },
    );
  }

  Widget _buildGroup(int groupIndex, RootSuffixGroupData group) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 分组头部
        if (groupIndex > 0) const Divider(height: 1),
        // 子项
        ...List.generate(group.count, (itemIndex) {
          final item = group.getData(itemIndex);
          return _buildItem(groupIndex, itemIndex, item, group);
        }),
      ],
    );
  }

  Widget _buildItem(int groupIndex, int itemIndex, RootSuffixData item, RootSuffixGroupData group) {
    final isOriginalWord = item.word == widget.originalWord;
    return GestureDetector(
      onTap: () {
        setState(() {
          if (item.isFold) {
            item.isFold = false;
            // 延迟播放音频
            Future.delayed(const Duration(milliseconds: 150), () {
              widget.onWordTap?.call(item.word);
            });
          } else {
            item.isFold = true;
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // 展开/折叠指示器
                if (itemIndex == 0)
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        if (group.isAllUnFold) {
                          group.setAllFold();
                        } else {
                          group.setAllUnFold();
                        }
                      });
                    },
                    child: Icon(
                      group.isAllUnFold ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                      size: 20,
                      color: _black54,
                    ),
                  )
                else
                  const Icon(Icons.circle, size: 8, color: _black54),
                const SizedBox(width: 8),
                // 单词
                Expanded(
                  child: Text(
                    item.highlight != null ? _stripHtml(item.highlight!) : item.word,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: isOriginalWord ? _accent : _black87,
                    ),
                  ),
                ),
                // 等级
                Text(item.wordGrade, style: const TextStyle(fontSize: 13, color: _black54)),
                const SizedBox(width: 8),
                // 添加生词按钮
                GestureDetector(
                  onTap: () => widget.onAddNewWord?.call(item.word),
                  child: Icon(
                    item.isNewWord ? Icons.star : Icons.star_border,
                    size: 20,
                    color: item.isNewWord ? _accent : _black54,
                  ),
                ),
              ],
            ),
            // 展开内容
            if (!item.isFold) ...[
              const SizedBox(height: 8),
              // 词根词缀
              if (item.rootSuffixList.isNotEmpty)
                Wrap(
                  spacing: 8,
                  children: item.rootSuffixList
                      .map(
                        (root) => Chip(
                          label: Text(root, style: const TextStyle(fontSize: 12)),
                          backgroundColor: _black12,
                        ),
                      )
                      .toList(),
                ),
              // 例句
              if (item.example != null && item.example!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(item.example!, style: const TextStyle(fontSize: 14, color: _black54)),
              ],
            ],
          ],
        ),
      ),
    );
  }

  String _stripHtml(String html) {
    return html.replaceAll(RegExp(r'<[^>]*>'), '');
  }
}
