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
       _http = httpClient ?? http.Client(),
       _ownsHttp = httpClient == null;

  final String _baseUrl;
  final String model;
  String apiKey;
  final http.Client _http;
  final bool _ownsHttp;
  final Duration timeout;

  /// 后台补入密钥（解析器异步从安全存储读入；未就绪前调用按失败回退）。
  void setApiKey(String value) => apiKey = value;

  /// 审计 B7（2026-11-15）：释放自建的 http.Client（注入的 client 由调用方负责），
  /// 供装配层在客户端替换/应用销毁时调用，防连接泄漏。
  @override
  void close() {
    if (_ownsHttp) _http.close();
  }

  @override
  bool get isLive => true;

  @override
  Future<String> complete(List<LlmMessage> messages) async {
    if (_baseUrl.isEmpty || model.isEmpty) {
      throw const LlmException('LLM 未配置端点或模型');
    }
    // 审计 D4（2026-11-15）：Bearer key 不得经明文 http 传输；畸形 URL 的
    // FormatException 归一为 LlmException（调用方据此回退规则台词）。
    final Uri uri;
    try {
      uri = Uri.parse('$_baseUrl/chat/completions');
    } on FormatException {
      throw const LlmException('LLM 端点 URL 畸形');
    }
    if (uri.scheme != 'https') {
      throw const LlmException('LLM 端点必须使用 https（密钥不得明文传输）');
    }
    // 审计 R9（2026-11-16）：密钥未就绪（空串/解析器占位 'pending'）不得发送——
    // 空 key 请求不带鉴权头仍会把聊天正文送到端点（必然失败还落对方日志），
    // 'pending' 窗口期更会把占位串当 Bearer 发出。调用方据 LlmException 回退规则台词。
    if (apiKey.isEmpty || apiKey == 'pending') {
      throw const LlmException('LLM 密钥未就绪');
    }
    final body = jsonEncode({
      'model': model,
      'messages': [
        for (final m in messages) {'role': m.role.name, 'content': m.content},
      ],
    });
    try {
      // 审计 R7（2026-11-16）：禁止跟随重定向——默认 followRedirects=true 会把
      // Authorization 头原样带到跳转目标且不限 scheme，恶意/被劫持端点 302→http
      // 即让 Bearer key 明文外泄。http.Client.post 不暴露该开关，改显式 Request。
      // 3xx 落入下方非 2xx 分支 → LlmException → 调用方回退规则台词。
      final request = http.Request('POST', uri)
        ..followRedirects = false
        ..headers['Content-Type'] = 'application/json'
        ..headers['Authorization'] = 'Bearer $apiKey'
        ..body = body;
      // 第三轮 T3：超时必须覆盖 send（响应头）+ fromStream（body 读取）全程——
      // 旧实现只包 send，服务端慢滴 body 可无限挂起（_busy 永占）。整体限时，
      // 超时后取消订阅关闭连接（http 流语义），不留悬挂 socket。
      final resp = await () async {
        final streamed = await _http.send(request);
        return http.Response.fromStream(streamed);
      }().timeout(timeout);
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
