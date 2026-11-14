// 学习伴侣 AI 化 · LLM 密钥安全存储 + 客户端工厂（core/infrastructure）。
//
// 密钥仅存平台安全存储（iOS Keychain / Android Keystore），不落明文、不进日志。
// 工厂：配置开关开 + 端点/模型非空 + key 非空 → OpenAiLlmClient；否则 RuleBasedLlm
//（行为等同现状）。base URL/model/开关由 AppPreferences 提供（经 PresentationPrefs 门面）。
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:word_app/core/application/llm_client.dart';
import 'package:word_app/core/infrastructure/openai_llm_client.dart';
import 'package:word_app/core/infrastructure/rule_based_llm.dart';
import 'package:word_app/core/utils/swallowed_error_report.dart';

/// LLM API key 安全存储（独立键，与账号 token 隔离）。
class LlmCredentials {
  LlmCredentials({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage(aOptions: AndroidOptions(encryptedSharedPreferences: true));

  static const String _key = 'llm_api_key_v1';

  final FlutterSecureStorage _storage;

  /// 读取 key（失败返回空串，不抛——未配置即走规则兜底）。
  Future<String> readKey() async {
    try {
      return await _storage.read(key: _key) ?? '';
    } catch (e, s) {
      reportSwallowedError('LLM 密钥读取失败（按未配置处理）', e, s);
      return '';
    }
  }

  /// 写入 key（失败仅上报，不阻断设置流程）。
  Future<void> writeKey(String value) async {
    try {
      if (value.isEmpty) {
        await _storage.delete(key: _key);
      } else {
        await _storage.write(key: _key, value: value);
      }
    } catch (e, s) {
      reportSwallowedError('LLM 密钥写入失败', e, s);
    }
  }
}

/// LLM 客户端工厂：按配置与密钥决定真实客户端或规则兜底。
class LlmClientFactory {
  LlmClientFactory({LlmCredentials? credentials}) : _credentials = credentials ?? LlmCredentials();

  final LlmCredentials _credentials;

  /// 构建客户端。未配置（开关关/端点模型空/key 空）→ RuleBasedLlm。
  Future<LlmClient> create(LlmConfig config, {RuleBasedLlm? fallback}) async {
    final rule = fallback ?? RuleBasedLlm();
    if (!config.isConfigured) return rule;
    final key = await _credentials.readKey();
    if (key.isEmpty) return rule;
    return OpenAiLlmClient(baseUrl: config.baseUrl, model: config.model, apiKey: key);
  }
}
