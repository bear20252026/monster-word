// 配套真题词组功能
// 在词书详情页显示"配套真题词组"卡片，点击可添加/查看真题词组
import 'package:flutter/material.dart';

import '../theme/skin_system.dart';

/// 真题词组数据模型
class ExamPhraseGroup {
  final int id;
  final int bookId; // 关联的主词书 ID
  final String name; // 词组名称，如"CET4真题词组"
  final String examType; // 考试类型：CET4/CET6/高考/考研等
  final int phraseCount; // 词组数量
  final bool isAdded; // 是否已添加

  const ExamPhraseGroup({
    required this.id,
    required this.bookId,
    required this.name,
    required this.examType,
    this.phraseCount = 0,
    this.isAdded = false,
  });
}

/// 配套真题词组卡片（显示在词书详情页）
class ExamPhraseCard extends StatelessWidget {
  final int bookId;
  final String bookName;
  final List<ExamPhraseGroup> phraseGroups;
  final VoidCallback? onAdd;
  final ValueChanged<ExamPhraseGroup>? onTap;

  const ExamPhraseCard({
    super.key,
    required this.bookId,
    required this.bookName,
    this.phraseGroups = const [],
    this.onAdd,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final skin = context.skin.colors;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: skin.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: skin.divider, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题行
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                Icon(Icons.menu_book, size: 20, color: skin.accent),
                const SizedBox(width: 8),
                Text(
                  '配套真题词组',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: skin.text1,
                  ),
                ),
                const Spacer(),
                // 添加按钮
                GestureDetector(
                  onTap: onAdd,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: skin.accent,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.add, size: 16, color: Colors.white),
                        const SizedBox(width: 4),
                        Text(
                          '添加',
                          style: TextStyle(fontSize: 13, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // 词组列表
          if (phraseGroups.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(
                '暂无配套词组，点击"添加"获取真题词组',
                style: TextStyle(fontSize: 13, color: skin.text3),
              ),
            )
          else
            ...phraseGroups.map((group) => _PhraseGroupTile(
                  group: group,
                  onTap: () => onTap?.call(group),
                )),
        ],
      ),
    );
  }
}

/// 单个词组条目
class _PhraseGroupTile extends StatelessWidget {
  final ExamPhraseGroup group;
  final VoidCallback? onTap;

  const _PhraseGroupTile({required this.group, this.onTap});

  @override
  Widget build(BuildContext context) {
    final skin = context.skin.colors;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: skin.divider, width: 0.5)),
        ),
        child: Row(
          children: [
            // 考试类型标签
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: skin.accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                group.examType,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: skin.accent,
                ),
              ),
            ),
            const SizedBox(width: 10),
            // 名称
            Expanded(
              child: Text(
                group.name,
                style: TextStyle(fontSize: 14, color: skin.text1),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // 词组数量
            Text(
              '${group.phraseCount}组',
              style: TextStyle(fontSize: 12, color: skin.text3),
            ),
            const SizedBox(width: 8),
            // 状态图标
            Icon(
              group.isAdded ? Icons.check_circle : Icons.add_circle_outline,
              size: 20,
              color: group.isAdded ? skin.success : skin.text3,
            ),
          ],
        ),
      ),
    );
  }
}

/// 真题词组选择弹窗（点击"添加"后弹出）
class ExamPhraseSheet extends StatelessWidget {
  final String bookName;
  final List<ExamPhraseGroup> availableGroups;
  final ValueChanged<ExamPhraseGroup> onAdd;

  const ExamPhraseSheet({
    super.key,
    required this.bookName,
    required this.availableGroups,
    required this.onAdd,
  });

  /// 显示弹窗
  static Future<void> show(
    BuildContext context, {
    required String bookName,
    required List<ExamPhraseGroup> availableGroups,
    required ValueChanged<ExamPhraseGroup> onAdd,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => ExamPhraseSheet(
        bookName: bookName,
        availableGroups: availableGroups,
        onAdd: onAdd,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin.colors;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 拖拽条
          Center(
            child: Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '添加配套真题词组',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: skin.text1),
          ),
          const SizedBox(height: 4),
          Text(
            '为"$bookName"添加配套的真题词组',
            style: TextStyle(fontSize: 13, color: skin.text3),
          ),
          const SizedBox(height: 16),
          // 可选词组列表
          if (availableGroups.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  '暂无可添加的真题词组',
                  style: TextStyle(fontSize: 14, color: skin.text3),
                ),
              ),
            )
          else
            ...availableGroups.map((group) => _AddableTile(
                  group: group,
                  onAdd: () {
                    onAdd(group);
                    Navigator.pop(context);
                  },
                )),
        ],
      ),
    );
  }
}

/// 可添加的词组条目
class _AddableTile extends StatelessWidget {
  final ExamPhraseGroup group;
  final VoidCallback onAdd;

  const _AddableTile({required this.group, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final skin = context.skin.colors;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          // 考试类型标签
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: skin.accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              group.examType,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: skin.accent),
            ),
          ),
          const SizedBox(width: 10),
          // 名称 + 数量
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(group.name, style: TextStyle(fontSize: 14, color: skin.text1)),
                Text('${group.phraseCount}组', style: TextStyle(fontSize: 12, color: skin.text3)),
              ],
            ),
          ),
          // 添加按钮
          GestureDetector(
            onTap: onAdd,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                border: Border.all(color: skin.accent),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                '+ 添加',
                style: TextStyle(fontSize: 13, color: skin.accent, fontWeight: FontWeight.w500),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
