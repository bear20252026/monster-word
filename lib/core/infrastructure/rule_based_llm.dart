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

  /// 审计 R13：规则版无网络资源，释放为无操作。
  @override
  void close() {}
}

/// 审计 B2（2026-11-15）：真实客户端失败时回退规则台词的包装器。
///
/// 端口契约（llm_client.dart）承诺「调用方据 LlmException 回退规则台词」，
/// 但此前聊天/主动台词两条调用链都没有兑现。把回退下沉到客户端装饰器，
/// 所有调用方自动获得「配置了但 key 失效/网络故障 ⇒ 仍有温暖台词」的行为。
/// isLive 透传主客户端，失败静默降级不报错。
///
/// 审计 R9（2026-11-16）：主客户端可切换——密钥未就绪时主客户端就是规则版
/// （isLive 如实为 false，不再「UI 显示 AI 模式但永远规则版」）；安全存储读入
/// 非空 key 后经 [upgradePrimary] 无缝升级为真实客户端。旧实现用 key:'pending'
/// 占位绕过空 key 分支，导致状态误导 + 占位 Bearer 外发。
class ResilientLlmClient implements LlmClient {
  ResilientLlmClient(this._primary, this._fallback);

  LlmClient _primary;
  final LlmClient _fallback;

  @override
  bool get isLive => _primary.isLive;

  /// 密钥就绪后升级主客户端（解析器异步读入安全存储后调用）。
  void upgradePrimary(LlmClient client) => _primary = client;

  @override
  Future<String> complete(List<LlmMessage> messages) async {
    try {
      return await _primary.complete(messages);
    } on LlmException {
      return _fallback.complete(messages);
    }
  }

  /// 审计 R13：释放主客户端自持资源（规则版无操作）。
  @override
  void close() => _primary.close();
}
