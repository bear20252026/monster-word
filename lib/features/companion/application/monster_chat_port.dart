// 学习伴侣 AI 化 · 小怪兽聊天端口（companion/application）。
//
// 对话不消耗每日主动预算（预算只约束「主动弹」，用户主动聊天不受限，与点击台词同口径）。
// 实现 MonsterChatState 注入 LlmClient + 记忆端口 + 性格 + 学习上下文，组装 prompt。
import 'package:word_app/core/application/llm_client.dart';

/// 一条聊天记录（UI 展示用）。
class ChatTurn {
  const ChatTurn({required this.role, required this.text});
  final LlmRole role;
  final String text;
}

/// 小怪兽聊天端口。
abstract interface class MonsterChatPort {
  /// 发送一句用户消息，返回怪兽回复。失败抛 [LlmException]（UI 据此提示）。
  Future<String> send(String userText);

  /// 当前对话历史（只读）。
  List<ChatTurn> get history;

  /// 清空对话历史。
  void clear();
}
