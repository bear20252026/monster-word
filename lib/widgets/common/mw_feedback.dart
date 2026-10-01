// 由 Claude 团队生成 | Monster Word App

// 统一确认弹窗（审计 I4：删除/移除确认此前在 4 个页面手写 AlertDialog）。
// 危险操作传 danger: true，确认按钮走皮肤 danger 色。
import 'package:flutter/material.dart';

import 'package:word_app/theme/skin_system.dart';

/// 统一 SnackBar 出口（P1-D，审计 I4 收尾）。
///
/// 所有反馈提示经此展示：样式/去重/埋点的全局调整只需改这一处。
/// 本批只统一「出口」，不改任何调用点的 SnackBar 构造（样式统一属
/// 视觉设计任务，须逐页走查后另行推进）。
void showMwSnackBar(BuildContext context, SnackBar snackBar) {
  ScaffoldMessenger.of(context).showSnackBar(snackBar);
}

Future<bool> showMwConfirm(
  BuildContext context, {
  required String title,
  required String content,
  String confirmLabel = '确定',
  String cancelLabel = '取消',
  bool danger = false,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(content),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(cancelLabel)),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel, style: danger ? TextStyle(color: context.skin.colors.danger) : null),
        ),
      ],
    ),
  );
  return confirmed == true;
}
