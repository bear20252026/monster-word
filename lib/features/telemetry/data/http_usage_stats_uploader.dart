// 使用统计的上报通道。
//
// 设计要点：
//   - **永远不抛异常**：统计是附加能力，任何失败都不该影响学习主流程，
//     也不该在 UI 上冒出任何提示。失败只记 Sentry。
//   - 未配置上报地址时直接返回 false（而不是静默成功）：调用方据此写退避、
//     不标记已传，数据留在本地等待。**静默成功会让数据被标成"已上报"而永久丢失。**
//   - 未配置但开关被打开时额外上报一次错误：这是配置事故（比如发版忘了注入
//     STATS_BASE_URL），必须能被发现，不能像没开一样安静。

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'package:word_app/core/utils/swallowed_error_report.dart';
import 'package:word_app/features/telemetry/application/usage_stats_ports.dart';
import 'package:word_app/features/telemetry/domain/usage_daily_stats.dart';

/// 上报地址（不含路径）。构建时注入：
///   --dart-define=STATS_BASE_URL=https://stats.cloudbear.cloud
/// 为空即视为「未配置」，不上报。
const String usageStatsBaseUrl = String.fromEnvironment('STATS_BASE_URL');

class HttpUsageStatsUploader implements UsageStatsUploader {
  HttpUsageStatsUploader({
    String? baseUrl,
    Duration timeout = const Duration(seconds: 20),
    Future<http.Response> Function(Uri url, Map<String, String> headers, String body)? postOverride,
  }) : baseUrl = _trimSlash(baseUrl ?? usageStatsBaseUrl),
       _timeout = timeout,
       _postOverride = postOverride;

  final String baseUrl;
  final Duration _timeout;
  final Future<http.Response> Function(Uri, Map<String, String>, String)? _postOverride;

  /// 「未配置」只提醒一次，避免每次启动都刷一条。
  static bool _warnedUnconfigured = false;

  static String _trimSlash(String value) => value.endsWith('/') ? value.substring(0, value.length - 1) : value;

  @override
  Future<bool> upload(UsageStatsReport report) async {
    if (baseUrl.isEmpty) {
      if (!_warnedUnconfigured) {
        _warnedUnconfigured = true;
        reportSwallowedError(
          '使用统计已启用但未配置 STATS_BASE_URL —— 数据留在本地不会上报。'
          '这是发版配置事故，请在构建时注入该 define。',
          StateError('STATS_BASE_URL 为空'),
          StackTrace.current,
        );
      }
      return false;
    }
    if (report.isEmpty) return true; // 没内容可传，视作成功（别让它占住退避窗口）

    final url = Uri.parse('$baseUrl/v1/report');
    final body = jsonEncode(report.toJson());
    const headers = {'Content-Type': 'application/json'};

    try {
      final response = _postOverride != null
          ? await _postOverride!(url, headers, body).timeout(_timeout)
          : await http.post(url, headers: headers, body: body).timeout(_timeout);
      // 2xx 才算成功。4xx 是契约问题（不该重试到天荒地老），但也不该丢数据 ——
      // 一律返回 false 让调用方写退避、保留本地数据，由人来看日志。
      if (response.statusCode >= 200 && response.statusCode < 300) return true;
      reportSwallowedError(
        '使用统计上报被拒：HTTP ${response.statusCode}',
        StateError(response.body.length > 500 ? response.body.substring(0, 500) : response.body),
        StackTrace.current,
      );
      return false;
    } on TimeoutException catch (e, s) {
      reportSwallowedError('使用统计上报超时', e, s);
      return false;
    } on SocketException catch (e, s) {
      reportSwallowedError('使用统计上报网络不可达', e, s);
      return false;
    } catch (e, s) {
      reportSwallowedError('使用统计上报异常', e, s);
      return false;
    }
  }
}
