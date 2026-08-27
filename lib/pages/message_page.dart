// 由 Claude 团队生成 | Monster Word App

// 移植自 v3.2 MessageActivity
// 消息中心：显示系统通知、学习提醒等消息列表
import 'package:flutter/material.dart';

import '../theme/skin_system.dart';
import '../tokens/design_tokens.dart';

class MessageItem {
  final String id;
  final String title;
  final String content;
  final String time;
  final bool isRead;

  const MessageItem({
    required this.id,
    required this.title,
    required this.content,
    required this.time,
    this.isRead = false,
  });
}

class MessagePage extends StatefulWidget {
  const MessagePage({super.key});

  static const routeName = '/messages';

  @override
  State<MessagePage> createState() => _MessagePageState();
}

class _MessagePageState extends State<MessagePage> {
  List<MessageItem> _messages = [];
  bool _isLoading = true;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  Future<void> _loadMessages({bool refresh = false}) async {
    if (refresh) {
      _hasMore = true;
    }
    setState(() => _isLoading = true);
    // TODO: 调用 API 加载消息
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) {
      setState(() {
        _messages = [];
        _isLoading = false;
      });
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
            Expanded(
              child: _isLoading
                  ? Center(child: CircularProgressIndicator(color: MistralColors.primary))
                  : _messages.isEmpty
                  ? _buildEmptyView(skin)
                  : RefreshIndicator(
                      color: MistralColors.primary,
                      onRefresh: () => _loadMessages(refresh: true),
                      child: ListView.builder(
                        itemCount: _messages.length + (_hasMore ? 1 : 0),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemBuilder: (context, index) {
                          if (index == _messages.length) {
                            _loadMessages();
                            return Center(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: CircularProgressIndicator(color: MistralColors.primary, strokeWidth: 2),
                              ),
                            );
                          }
                          return _buildMessageItem(skin, _messages[index]);
                        },
                      ),
                    ),
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
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 4),
          Text('消息中心', style: MistralTypography.heading5.copyWith(color: skin.colors.text1)),
          const Spacer(),
          TextButton(
            onPressed: () {
              // TODO: 全部标记已读
            },
            child: Text('全部已读', style: TextStyle(color: MistralColors.primary)),
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
          const SizedBox(height: 16),
          Text('暂无消息', style: MistralTypography.body.copyWith(color: skin.colors.text3)),
        ],
      ),
    );
  }

  Widget _buildMessageItem(SkinSystem skin, MessageItem msg) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: msg.isRead ? skin.colors.cardBgAlt : skin.colors.cardBg,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: skin.colors.divider),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: msg.isRead ? MistralColors.hairline : MistralColors.cream,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.notifications_outlined,
            color: msg.isRead ? MistralColors.stone : MistralColors.primary,
            size: 20,
          ),
        ),
        title: Text(
          msg.title,
          style: MistralTypography.bodyBold.copyWith(
            color: skin.colors.text1,
            fontWeight: msg.isRead ? FontWeight.normal : FontWeight.w600,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              msg.content,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: MistralTypography.bodySm.copyWith(color: skin.colors.text3),
            ),
            const SizedBox(height: 4),
            Text(msg.time, style: MistralTypography.micro.copyWith(color: skin.colors.text3)),
          ],
        ),
      ),
    );
  }
}
