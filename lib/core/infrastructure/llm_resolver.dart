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
/// 密钥异步从安全存储读入后补入（[OpenAiLlmClient.setApiKey]），不阻塞装配。
LlmClient resolveLlmClient(LlmConfig config, {LlmCredentials? credentials}) {
  final creds = credentials ?? LlmCredentials();
  final factory = LlmClientFactory(credentials: creds);
  if (!config.isConfigured) return RuleBasedLlm();
  // 配置齐全：经工厂构建真实客户端+失败回退包装；密钥后台读入补入（不阻塞装配）。
  final client = factory.createSync(config, key: 'pending');
  creds.readKey().then((key) {
    if (client is ResilientLlmClient) client.setPrimaryKey(key);
  });
  return client;
}
