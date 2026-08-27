import 'package:flutter/material.dart';

/// 正式复习“更多”操作的展示面板。
///
/// 面板不读取会话或路由状态，只向页面发出播放发音和查看详情的意图。
class FormalReviewMoreOptionsSheet extends StatelessWidget {
  const FormalReviewMoreOptionsSheet({super.key, required this.onPlayAudio, required this.onShowDetails});

  final VoidCallback onPlayAudio;
  final VoidCallback onShowDetails;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(leading: const Icon(Icons.volume_up), title: const Text('播放发音'), onTap: onPlayAudio),
          ListTile(leading: const Icon(Icons.info_outline), title: const Text('查看详情'), onTap: onShowDetails),
        ],
      ),
    );
  }
}
