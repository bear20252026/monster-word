// 学习伴侣 AI 化 · 规则兜底 LLM（core/infrastructure）。
//
// 未配置真实模型时的默认客户端：委托现有 MonsterSpeech 模板引擎，输出必然 ∈ 槽位
// 模板渲染集（性格组/去重/空值过滤口径完全复用），保证「未配置 == 现状」。
// 它不消耗每日主动预算（预算由调用方按「是否主动弹」决定，与 pick 语义一致）。
import 'package:word_app/core/application/llm_client.dart';
import 'package:word_app/core/utils/monster_speech.dart';

class RuleBasedLlm implements LlmClient {
  RuleBasedLlm({MonsterSpeech? speech, this.slot = SpeechSlot.dailyGreeting, this.vars = const {}})
    : _speech = speech ?? MonsterSpeech();

  final MonsterSpeech _speech;
  final SpeechSlot slot;
  final Map<String, Object?> vars;

  @override
  bool get isLive => false;

  @override
  Future<String> complete(List<LlmMessage> messages) async {
    // 规则版不读消息内容，直接按槽位挑模板（与现有主动/点击台词同源）。
    return _speech.pick(slot, vars: vars);
  }
}
