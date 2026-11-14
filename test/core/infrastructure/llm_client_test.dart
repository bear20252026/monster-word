// 学习伴侣 AI 化 · LLM 层单测。
// 规则兜底输出∈模板集；工厂未配置返回规则版；OpenAI 客户端用 mock http 离线验证。
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:word_app/core/application/llm_client.dart';
import 'package:word_app/core/infrastructure/llm_credentials.dart';
import 'package:word_app/core/infrastructure/openai_llm_client.dart';
import 'package:word_app/core/infrastructure/rule_based_llm.dart';
import 'package:word_app/core/utils/monster_speech.dart';

/// 可注入密钥的假凭证（不触平台安全存储）。
class _FakeCredentials extends LlmCredentials {
  _FakeCredentials(this._key);
  final String _key;
  @override
  Future<String> readKey() async => _key;
}

void main() {
  setUp(MonsterSpeech.resetForTest);

  group('RuleBasedLlm', () {
    test('isLive=false，输出∈槽位模板渲染集', () async {
      final llm = RuleBasedLlm(slot: SpeechSlot.dailyGreeting, vars: const {});
      expect(llm.isLive, isFalse);
      final out = await llm.complete(const [LlmMessage(LlmRole.user, '你好')]);
      // dailyGreeting 含占位符的模板在 vars 为空时被过滤，输出必为无占位符条目之一。
      final candidates = MonsterSpeech.templatesOf(SpeechSlot.dailyGreeting).where((t) => !t.contains('{')).toSet();
      expect(candidates.contains(out), isTrue, reason: '规则输出必须来自模板集：$out');
    });
  });

  group('LlmClientFactory', () {
    test('开关关 → 规则版', () async {
      final factory = LlmClientFactory(credentials: _FakeCredentials('sk-test'));
      final client = await factory.create(const LlmConfig.disabled());
      expect(client.isLive, isFalse);
    });

    test('开关开但端点/模型空 → 规则版', () async {
      final factory = LlmClientFactory(credentials: _FakeCredentials('sk-test'));
      final client = await factory.create(const LlmConfig(enabled: true, baseUrl: '', model: ''));
      expect(client.isLive, isFalse);
    });

    test('配置齐全但 key 空 → 规则版', () async {
      final factory = LlmClientFactory(credentials: _FakeCredentials(''));
      final client = await factory.create(const LlmConfig(enabled: true, baseUrl: 'https://x/v1', model: 'm'));
      expect(client.isLive, isFalse);
    });

    test('配置齐全且 key 非空 → 真实客户端', () async {
      final factory = LlmClientFactory(credentials: _FakeCredentials('sk-test'));
      final client = await factory.create(const LlmConfig(enabled: true, baseUrl: 'https://x/v1', model: 'm'));
      expect(client.isLive, isTrue);
    });
  });

  group('OpenAiLlmClient（mock http，不联网）', () {
    test('正常响应解析 choices[0].message.content', () async {
      final mock = MockClient((req) async {
        expect(req.url.path, endsWith('/chat/completions'));
        expect(req.headers['Authorization'], 'Bearer sk-test');
        final body = jsonDecode(req.body) as Map<String, dynamic>;
        expect(body['model'], 'qwen-plus');
        return http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'choices': [
                {
                  'message': {'role': 'assistant', 'content': '  你好呀，一起加油~  '},
                },
              ],
            }),
          ),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
      final client = OpenAiLlmClient(baseUrl: 'https://x/v1/', model: 'qwen-plus', apiKey: 'sk-test', httpClient: mock);
      final out = await client.complete(const [LlmMessage(LlmRole.user, 'hi')]);
      expect(out, '你好呀，一起加油~');
    });

    test('非 2xx 抛 LlmException', () async {
      final mock = MockClient((req) async => http.Response('error', 500));
      final client = OpenAiLlmClient(baseUrl: 'https://x/v1', model: 'm', apiKey: 'k', httpClient: mock);
      expect(client.complete(const [LlmMessage(LlmRole.user, 'hi')]), throwsA(isA<LlmException>()));
    });

    test('空 choices 抛 LlmException', () async {
      final mock = MockClient((req) async => http.Response(jsonEncode({'choices': []}), 200));
      final client = OpenAiLlmClient(baseUrl: 'https://x/v1', model: 'm', apiKey: 'k', httpClient: mock);
      expect(client.complete(const [LlmMessage(LlmRole.user, 'hi')]), throwsA(isA<LlmException>()));
    });

    test('未配置端点抛 LlmException', () async {
      final client = OpenAiLlmClient(baseUrl: '', model: 'm', apiKey: 'k');
      expect(client.complete(const [LlmMessage(LlmRole.user, 'hi')]), throwsA(isA<LlmException>()));
    });
  });
}
