// 学习伴侣 AI 化 · LLM 抽象端口（core/application，中性接口，禁 import features，守 R-core）。
//
// 可插拔设计：未配置（无 key/开关关）时工厂返回规则兜底版（RuleBasedLlm，委托现有
// MonsterSpeech 模板），行为等同现状；配置后返回 OpenAI 兼容客户端。本次不接真实服务，
// 只搭接口与配置，真实调用留待用户填入 base URL/key/model 后启用。
//
// 台词红线（与 monster_speech 一致）：温暖不指责、不催促、防焦虑。调用方在 system
// 提示里注入性格与学习上下文，端口本身不感知业务。

/// 对话角色（中性，不绑定任何服务商）。
enum LlmRole { system, user, assistant }

/// 一条对话消息。
class LlmMessage {
  const LlmMessage(this.role, this.content);

  final LlmRole role;
  final String content;
}

/// LLM 服务配置（base URL / 模型名 / 开关；key 单独走安全存储，不入此对象、不进日志）。
class LlmConfig {
  const LlmConfig({required this.enabled, required this.baseUrl, required this.model});

  /// 未配置默认值：关闭、空端点、空模型。
  const LlmConfig.disabled() : enabled = false, baseUrl = '', model = '';

  final bool enabled;
  final String baseUrl;
  final String model;

  /// 是否具备真实调用条件（开关开 + 端点/模型非空）。key 由工厂另行校验。
  bool get isConfigured => enabled && baseUrl.trim().isNotEmpty && model.trim().isNotEmpty;
}

/// LLM 客户端端口：一次多轮对话补全。
///
/// 实现须保证：失败/超时抛出 [LlmException]（调用方据此回退规则台词），绝不静默返回空。
abstract interface class LlmClient {
  /// 是否真实模型客户端（false = 规则兜底）。调用方据此决定是否走异步增强。
  bool get isLive;

  /// 发送对话，返回助手回复文本。失败抛 [LlmException]。
  Future<String> complete(List<LlmMessage> messages);
}

/// LLM 调用异常（网络/超时/服务端错误/未配置）。
class LlmException implements Exception {
  const LlmException(this.message);
  final String message;
  @override
  String toString() => 'LlmException: $message';
}
