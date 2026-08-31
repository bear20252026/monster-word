// Monster Word — 空状态组件（无数据/无结果/无网络 一等公民）
//
// 商业产品惯例：空态不是白屏，而是「图标 + 一句话 + 行动指引」。
// 颜色/圆角/间距全部走 A 档 + B 档，跟随品牌换肤。
import 'package:flutter/material.dart';

import 'package:word_app/theme/skin_system.dart';

/// 预置空态场景，避免各页图标/文案各写各的。
enum MwEmptyKind {
  /// 无数据（列表为空）
  empty,

  /// 搜索无结果
  search,

  /// 无网络
  offline,

  /// 加载失败
  error,
}

extension _MwEmptyKindX on MwEmptyKind {
  IconData get icon => switch (this) {
    MwEmptyKind.empty => Icons.inbox_outlined,
    MwEmptyKind.search => Icons.search_off_rounded,
    MwEmptyKind.offline => Icons.wifi_off_rounded,
    MwEmptyKind.error => Icons.error_outline_rounded,
  };

  String get defaultTitle => switch (this) {
    MwEmptyKind.empty => '这里还空空如也',
    MwEmptyKind.search => '没有找到相关内容',
    MwEmptyKind.offline => '网络连接不可用',
    MwEmptyKind.error => '加载失败了',
  };

  String get defaultSubtitle => switch (this) {
    MwEmptyKind.empty => '从下面开始，添加第一批内容吧',
    MwEmptyKind.search => '换个关键词，或检查一下拼写',
    MwEmptyKind.offline => '检查网络后重试',
    MwEmptyKind.error => '稍后再试一次',
  };
}

class MwEmptyState extends StatelessWidget {
  final MwEmptyKind kind;
  final String? title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const MwEmptyState({
    super.key,
    this.kind = MwEmptyKind.empty,
    this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final design = context.design;
    final c = skin.colors;

    return Center(
      child: Padding(
        padding: EdgeInsets.all(design.spacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 图标：低饱和描边圆底，避免大红大绿
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: c.cardBgAlt,
                shape: BoxShape.circle,
                border: Border.all(color: c.divider),
              ),
              child: Icon(kind.icon, size: 30, color: c.text3),
            ),
            SizedBox(height: design.spacing.lg),
            Text(
              title ?? kind.defaultTitle,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: c.text1),
            ),
            SizedBox(height: design.spacing.xs),
            Text(
              subtitle ?? kind.defaultSubtitle,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: c.text2),
            ),
            if (actionLabel != null && onAction != null) ...[
              SizedBox(height: design.spacing.lg),
              TextButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
