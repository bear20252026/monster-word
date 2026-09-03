// 由 Claude 团队生成 | Monster Word App

// 消息中心：显示本地消息（欢迎/打卡提醒/连续打卡里程碑等），
// 数据源为 MessageStore（单一事实来源），支持全部已读与单条已读。
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:word_app/features/account/application/message_store.dart';
import 'package:word_app/features/account/domain/message_item.dart';
import 'package:word_app/theme/skin_system.dart';
import 'package:word_app/tokens/design_tokens.dart';

class MessagePage extends StatefulWidget {
  const MessagePage({super.key});

  static const routeName = '/messages';

  @override
  State<MessagePage> createState() => _MessagePageState();
}

class _MessagePageState extends State<MessagePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<MessageStore>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final store = context.watch<MessageStore>();

    return Scaffold(
      backgroundColor: skin.colors.pageBg,
      body: SafeArea(
        child: Column(
          children: [
            _buildNavBar(skin, store),
            Container(height: 1, color: skin.colors.divider),
            Expanded(
              child: !store.loaded
                  ? Center(child: CircularProgressIndicator(color: MwColors.primary))
                  : store.messages.isEmpty
                  ? _buildEmptyView(skin)
                  : RefreshIndicator(
                      color: MwColors.primary,
                      onRefresh: () => store.load(),
                      child: ListView.builder(
                        itemCount: store.messages.length,
                        padding: EdgeInsets.symmetric(vertical: 8),
                        itemBuilder: (context, index) => _buildMessageItem(skin, store, store.messages[index]),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavBar(SkinSystem skin, MessageStore store) {
    return Container(
      height: 48,
      padding: EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
            color: skin.colors.text1,
            tooltip: '返回',
            onPressed: () => Navigator.pop(context),
          ),
          SizedBox(width: 4),
          Text('消息中心', style: MwTypography.heading5.copyWith(color: skin.colors.text1)),
          const Spacer(),
          if (store.unreadCount > 0)
            TextButton(
              onPressed: () => store.markAllRead(),
              child: Text('全部已读(${store.unreadCount})', style: TextStyle(color: MwColors.primary)),
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
          Icon(Icons.mail_outline, size: 64, color: skin.colors.text3),
          SizedBox(height: 16),
          Text('暂无消息', style: MwTypography.body.copyWith(color: skin.colors.text3)),
        ],
      ),
    );
  }

  Widget _buildMessageItem(SkinSystem skin, MessageStore store, MessageItem msg) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: msg.isRead ? skin.colors.cardBgAlt : skin.colors.cardBg,
        borderRadius: BorderRadius.circular(context.design.radius.lg),
        border: Border.all(color: skin.colors.divider),
      ),
      // ListTile 背景与水波纹画在最近的 Material 上；透明 Material 保证
      // 卡片背景色与点击涟漪可见（否则触发框架断言）。
      child: Material(
        type: MaterialType.transparency,
        child: ListTile(
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(context.design.radius.lg)),
          onTap: () => store.markRead(msg.id),
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: msg.isRead ? MwColors.hairline : MwColors.cream, shape: BoxShape.circle),
            child: Icon(Icons.notifications_outlined, color: msg.isRead ? MwColors.stone : MwColors.primary, size: 20),
          ),
          title: Text(
            msg.title,
            style: MwTypography.bodyBold.copyWith(
              color: skin.colors.text1,
              fontWeight: msg.isRead ? FontWeight.normal : FontWeight.w600,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 4),
              Text(
                msg.content,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: MwTypography.bodySm.copyWith(color: skin.colors.text3),
              ),
              SizedBox(height: 4),
              Text(msg.time, style: MwTypography.micro.copyWith(color: skin.colors.text3)),
            ],
          ),
        ),
      ),
    );
  }
}
