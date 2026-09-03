// 由 Claude 团队生成 | Monster Word App

// 消息中心入口图标（带未读角标）。
// 未读数来自 MessageStore（单一事实来源）；store 未加载时自动补载，
// 保证任意入口页冷启动也能显示真实未读数。
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:word_app/app/router/route_names.dart';
import 'package:word_app/features/account/application/message_store.dart';
import 'package:word_app/theme/skin_system.dart';

class MessageBadgeIcon extends StatefulWidget {
  const MessageBadgeIcon({super.key, this.iconSize = 22, this.color});

  final double iconSize;

  /// 图标颜色；为空时跟随当前皮肤主文本色。
  final Color? color;

  @override
  State<MessageBadgeIcon> createState() => _MessageBadgeIconState();
}

class _MessageBadgeIconState extends State<MessageBadgeIcon> {
  @override
  void initState() {
    super.initState();
    // 入口页可能先于消息页出现：补载一次（幂等），角标才有真实数据。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final store = context.read<MessageStore>();
      if (!store.loaded) store.load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.skin.colors;
    final unread = context.watch<MessageStore>().unreadCount;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          icon: Icon(Icons.mail_outline, size: widget.iconSize),
          color: widget.color ?? colors.text1,
          tooltip: '消息中心',
          onPressed: () => Navigator.pushNamed(context, RouteNames.messages),
        ),
        if (unread > 0)
          Positioned(
            right: 5,
            top: 5,
            child: Container(
              padding: unread > 9 ? const EdgeInsets.symmetric(horizontal: 4) : null,
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colors.danger,
                shape: unread > 9 ? BoxShape.rectangle : BoxShape.circle,
                borderRadius: unread > 9 ? BorderRadius.circular(8) : null,
                border: Border.all(color: colors.pageBg, width: 1.5),
              ),
              child: Text(
                unread > 99 ? '99+' : '$unread',
                style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700, height: 1),
              ),
            ),
          ),
      ],
    );
  }
}
