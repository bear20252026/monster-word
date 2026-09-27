// 由 Claude 团队生成 | Monster Word App

// 统一确认弹窗（审计 I4：删除/移除确认此前在 4 个页面手写 AlertDialog）。
// 危险操作传 danger: true，确认按钮走皮肤 danger 色。
import 'package:flutter/material.dart';

import 'package:word_app/theme/skin_system.dart';

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
