// 学习伴侣 AI 化 · LLM 客户端解析器（core/infrastructure）。
//
// 同步解析（供 Provider create）：配置齐全（开关开+端点/模型非空）→ 真实 OpenAI 客户端
//（密钥后台从安全存储读入，未就绪前调用按失败回退）；否则规则兜底（行为等同现状）。
import 'package:word_app/core/application/llm_client.dart';
import 'package:word_app/core/infrastructure/llm_credentials.dart';
import 'package:word_app/core/infrastructure/openai_llm_client.dart';
import 'package:word_app/core/infrastructure/rule_based_llm.dart';

/// 按配置解析 LLM 客户端。密钥异步读入真实客户端；未配置即规则版。
LlmClient resolveLlmClient(LlmConfig config, {LlmCredentials? credentials}) {
  if (!config.isConfigured) return RuleBasedLlm();
  final client = OpenAiLlmClient(baseUrl: config.baseUrl, model: config.model, apiKey: '');
  // 后台补入密钥：readKey 失败返回空串，客户端按未配置抛 LlmException → 调用方回退规则。
  (credentials ?? LlmCredentials()).readKey().then(client.setApiKey);
  return client;
}
