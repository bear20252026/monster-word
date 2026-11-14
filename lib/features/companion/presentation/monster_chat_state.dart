// 学习伴侣 AI 化 · 小怪兽聊天状态（companion/presentation）。
//
// 注入 LlmClient + 记忆 curator + 性格 + 学习上下文快照，组装 system prompt：
// 性格人设 + 记忆上下文 + 学习近况 + 台词红线（温暖不指责/防焦虑）。对话不耗主动预算。
// 每轮把用户消息沉淀近期层记忆（规则提取入口；LLM 提取接入后增强）。
import 'package:flutter/foundation.dart';

import 'package:word_app/core/application/llm_client.dart';
import 'package:word_app/core/application/monster_memory_curator.dart';
import 'package:word_app/core/utils/monster_personality.dart';
import 'package:word_app/features/companion/application/monster_chat_port.dart';

class MonsterChatState extends ChangeNotifier implements MonsterChatPort {
  MonsterChatState({
    required this.llm,
    required this.memory,
    this.personality = MonsterPersonality.lively,
    this.learningContext = '',
  });

  final LlmClient llm;
  final MonsterMemoryCurator memory;
  final MonsterPersonality personality;
  final String learningContext;

  final List<ChatTurn> _history = [];
  bool _busy = false;

  bool get busy => _busy;
  bool get isLive => llm.isLive;

  @override
  List<ChatTurn> get history => List.unmodifiable(_history);

  @override
  void clear() {
    _history.clear();
    notifyListeners();
  }

  /// 性格人设（按性格定调，台词红线统一）。
  String _personaPrompt() {
    final tone = switch (personality) {
      MonsterPersonality.lively => '活泼热情，元气满满，喜欢用波浪号和语气词',
      MonsterPersonality.calm => '温柔安静，体贴细腻，说话平和',
      MonsterPersonality.stubborn => '有点小傲娇，嘴硬心软，偶尔别扭但很关心对方',
    };
    return '你是用户背单词 app 里的桌面小怪兽伙伴。性格：$tone。'
        '你陪用户学英语，会鼓励、会闲聊、会关心。'
        '红线：温暖不指责，不催促、不羞辱、不制造焦虑；回复简短口语化（一两句话），像朋友聊天。';
  }

  Future<String> _systemPrompt() async {
    final memoryCtx = await memory.buildContext();
    final buf = StringBuffer(_personaPrompt());
    if (learningContext.isNotEmpty) {
      buf.write('\n【当前学习状态】$learningContext');
    }
    if (memoryCtx.isNotEmpty) {
      buf.write('\n【你对用户的记忆】\n$memoryCtx');
    }
    return buf.toString();
  }

  @override
  Future<String> send(String userText) async {
    final text = userText.trim();
    if (text.isEmpty || _busy) return '';
    _busy = true;
    _history.add(ChatTurn(role: LlmRole.user, text: text));
    notifyListeners();
    try {
      final system = await _systemPrompt();
      final messages = <LlmMessage>[
        LlmMessage(LlmRole.system, system),
        // 携带最近若干轮历史，保证多轮连贯（上限防 prompt 膨胀）。
        for (final t in _history.skip(_history.length > 12 ? _history.length - 12 : 0)) LlmMessage(t.role, t.text),
      ];
      final reply = await llm.complete(messages);
      _history.add(ChatTurn(role: LlmRole.assistant, text: reply));
      // 沉淀近期记忆（规则入口：记用户这句；LLM 提取接入后改为提炼要点）。
      await memory.recordRecent('chat_${DateTime.now().millisecondsSinceEpoch}', '用户说：$text');
      await memory.trimRecent(20);
      return reply;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }
}
