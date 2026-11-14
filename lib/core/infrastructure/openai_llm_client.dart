// 学习伴侣 AI 化 · OpenAI 兼容 LLM 客户端（core/infrastructure）。
//
// 接任意 OpenAI 兼容 /chat/completions 端点（通义千问 DashScope 兼容模式、OpenAI、
// DeepSeek、本地 Ollama 等）。base URL/model 来自配置，key 走安全存储（不入日志）。
// http.Client 可注入：测试用 mock 离线验证，不联网。失败/超时统一抛 LlmException。
import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:word_app/core/application/llm_client.dart';

class OpenAiLlmClient implements LlmClient {
  OpenAiLlmClient({
    required String baseUrl,
    required this.model,
    required this.apiKey,
    http.Client? httpClient,
    this.timeout = const Duration(seconds: 30),
  }) : _baseUrl = baseUrl.trim().replaceAll(RegExp(r'/+$'), ''),
       _http = httpClient ?? http.Client();

  final String _baseUrl;
  final String model;
  final String apiKey;
  final http.Client _http;
  final Duration timeout;

  @override
  bool get isLive => true;

  @override
  Future<String> complete(List<LlmMessage> messages) async {
    if (_baseUrl.isEmpty || model.isEmpty) {
      throw const LlmException('LLM 未配置端点或模型');
    }
    final uri = Uri.parse('$_baseUrl/chat/completions');
    final body = jsonEncode({
      'model': model,
      'messages': [
        for (final m in messages) {'role': m.role.name, 'content': m.content},
      ],
    });
    try {
      final resp = await _http
          .post(
            uri,
            headers: {'Content-Type': 'application/json', if (apiKey.isNotEmpty) 'Authorization': 'Bearer $apiKey'},
            body: body,
          )
          .timeout(timeout);
      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        // 不回显服务端原文（可能含敏感信息），只报状态码。
        throw LlmException('LLM 服务端返回 ${resp.statusCode}');
      }
      final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
      final choices = decoded['choices'] as List<dynamic>?;
      if (choices == null || choices.isEmpty) {
        throw const LlmException('LLM 响应无 choices');
      }
      final message = (choices.first as Map<String, dynamic>)['message'] as Map<String, dynamic>?;
      final content = message?['content'] as String?;
      if (content == null || content.trim().isEmpty) {
        throw const LlmException('LLM 响应内容为空');
      }
      return content.trim();
    } on LlmException {
      rethrow;
    } on TimeoutException {
      throw const LlmException('LLM 请求超时');
    } catch (e) {
      // 网络/解析异常统一归一为 LlmException；不泄露 key/原文。
      throw LlmException('LLM 请求失败：${e.runtimeType}');
    }
  }
}
