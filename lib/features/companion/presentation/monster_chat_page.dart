// 学习伴侣 AI 化 · 小怪兽聊天页（companion/presentation）。
//
// 经 Provider 消费 MonsterChatState（装配注入 LLM/记忆/性格/学习上下文）。
// 未配置 LLM 时状态用规则兜底（回复来自模板），页面照常可用。
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:word_app/core/application/llm_client.dart';
import 'package:word_app/features/companion/application/monster_chat_port.dart';
import 'package:word_app/features/companion/presentation/monster_chat_state.dart';
import 'package:word_app/theme/skin_system.dart';
import 'package:word_app/tokens/design_tokens.dart';
import 'package:word_app/tokens/motion_tokens.dart';
import 'package:word_app/widgets/common/mw_feedback.dart';

class MonsterChatPage extends StatefulWidget {
  const MonsterChatPage({super.key});
  @override
  State<MonsterChatPage> createState() => _MonsterChatPageState();
}

class _MonsterChatPageState extends State<MonsterChatPage> {
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final state = context.read<MonsterChatState>();
    final text = _input.text;
    if (text.trim().isEmpty || state.busy) return;
    _input.clear();
    try {
      await state.send(text);
    } catch (_) {
      if (!mounted) return;
      showMwSnackBar(context, const SnackBar(content: Text('小怪兽走神了，稍后再试试~')));
    }
    if (!mounted) return;
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent, duration: MotionDurations.base, curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.skin.colors;
    final state = context.watch<MonsterChatState>();
    return Scaffold(
      backgroundColor: colors.pageBg,
      appBar: AppBar(
        backgroundColor: colors.cardBg,
        title: Text('和小怪兽聊天', style: TextStyle(color: colors.text1)),
        iconTheme: IconThemeData(color: colors.text1),
      ),
      body: Column(
        children: [
          Expanded(
            child: state.history.isEmpty
                ? Center(
                    child: Text('跟小怪兽说点什么吧~', style: TextStyle(color: colors.text3)),
                  )
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.all(AppSpacing.md),
                    itemCount: state.history.length,
                    itemBuilder: (_, i) => _Bubble(turn: state.history[i]),
                  ),
          ),
          if (state.busy)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xxs),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '小怪兽正在想…',
                  style: TextStyle(color: colors.text3, fontSize: AppFontSizes.caption),
                ),
              ),
            ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.sm, AppSpacing.xxs, AppSpacing.sm, AppSpacing.xs),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        hintText: '输入消息…',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xxs),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  IconButton.filled(onPressed: state.busy ? null : _send, icon: const Icon(Icons.send)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.turn});
  final ChatTurn turn;

  @override
  Widget build(BuildContext context) {
    final colors = context.skin.colors;
    final isUser = turn.role == LlmRole.user;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xxs),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isUser ? colors.accent : colors.cardBg,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Text(turn.text, style: TextStyle(color: isUser ? AppColors.white100 : colors.text1)),
      ),
    );
  }
}
