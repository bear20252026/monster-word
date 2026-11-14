// 学习伴侣 AI 化 · companion 功能域路由（聊天页）。
//
// 聊天页装配：LLM 客户端按配置解析（未配置规则兜底）+ 记忆 curator + 当前性格。
// 学习上下文快照由 MonsterChatState 经记忆事实层间接携带（curator 沉淀）。
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:word_app/app/router/route_names.dart';
import 'package:word_app/core/application/monster_memory_curator.dart';
import 'package:word_app/core/application/presentation_prefs.dart';
import 'package:word_app/core/infrastructure/companion_memory_dao.dart';
import 'package:word_app/core/infrastructure/llm_resolver.dart';
import 'package:word_app/core/utils/monster_speech.dart';
import 'package:word_app/features/companion/presentation/monster_chat_page.dart';
import 'package:word_app/features/companion/presentation/monster_chat_state.dart';

abstract final class CompanionRoutes {
  static Widget? build(String? name, Object? args) {
    switch (name) {
      case RouteNames.monsterChat:
        return const _MonsterChatEntry();
      default:
        return null;
    }
  }
}

/// 聊天页装配入口：经 Provider 注入 MonsterChatState（LLM/记忆/性格）。
class _MonsterChatEntry extends StatelessWidget {
  const _MonsterChatEntry();

  @override
  Widget build(BuildContext context) {
    final prefs = context.read<PresentationPrefs>();
    return ChangeNotifierProvider<MonsterChatState>(
      create: (_) => MonsterChatState(
        llm: resolveLlmClient(prefs.llmConfig),
        memory: MonsterMemoryCurator(CompanionMemoryDao.instance),
        personality: MonsterSpeech.currentPersonality,
      ),
      child: const MonsterChatPage(),
    );
  }
}
