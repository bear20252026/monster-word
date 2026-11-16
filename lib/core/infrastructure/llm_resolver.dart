// 学习伴侣 AI 化 · LLM 客户端解析器（core/infrastructure）。
//
// 把「读安全存储密钥 + 按配置选客户端」收敛到 LlmClientFactory（单一工厂，
// 审计 B2 2026-11-15 消除双写漂移）。密钥异步读入不阻塞装配：未配置即时返回
// 规则版；配置齐全先返回真实客户端（失败自动回退规则台词），密钥后台补入。
import 'package:word_app/core/application/llm_client.dart';
import 'package:word_app/core/infrastructure/llm_credentials.dart';
import 'package:word_app/core/infrastructure/openai_llm_client.dart';
import 'package:word_app/core/infrastructure/rule_based_llm.dart';

/// 按配置解析 LLM 客户端。未配置 → 规则版；配置齐全 → 真实客户端（失败回退规则）。
///
/// 审计 R9（2026-11-16）：密钥异步读入期间主客户端就是规则版（isLive 如实 false），
/// 不再用 key:'pending' 占位绕过空 key 分支——旧实现在读入完成前 UI 谎报 AI 模式、
/// 聊天正文不带鉴权仍外发、占位 Bearer 发出必然失败的请求。读入非空 key 后经
/// [ResilientLlmClient.upgradePrimary] 无缝升级；读入为空则保持规则版（如实）。
LlmClient resolveLlmClient(LlmConfig config, {LlmCredentials? credentials}) {
  final creds = credentials ?? LlmCredentials();
  if (!config.isConfigured) return RuleBasedLlm();
  final rule = RuleBasedLlm();
  final client = ResilientLlmClient(rule, rule);
  creds.readKey().then((key) {
    if (key.isEmpty) return; // 未配置密钥：保持规则版，isLive 如实为 false。
    client.upgradePrimary(OpenAiLlmClient(baseUrl: config.baseUrl, model: config.model, apiKey: key));
  });
  return client;
}
