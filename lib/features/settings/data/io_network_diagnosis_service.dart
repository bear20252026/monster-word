// 由 Claude 团队生成 | Monster Word App

// 基于 dart:io 的真实网络诊断实现：
// DNS 解析（InternetAddress.lookup）+ HTTP 可达性（HttpClient）。
// App 仅面向 Windows/Android，dart:io 可用。
import 'dart:async';
import 'dart:io';

import 'package:word_app/features/settings/application/network_diagnosis_service.dart';
import 'package:word_app/features/settings/domain/diagnosis_result.dart';

/// 短信验证码服务域名（与 SpugSmsCodeService 保持同一事实来源）。
const String kSmsServiceHost = 'push.spug.cc';

/// 崩溃上报服务主机（Sentry DE 区域 ingest，见 main.dart Sentry DSN）。
const String kSentryIngestHost = 'o4511997928341504.ingest.de.sentry.io';

class IoNetworkDiagnosisService implements NetworkDiagnosisService {
  IoNetworkDiagnosisService({this.stepTimeout = const Duration(seconds: 6)});

  final Duration stepTimeout;

  @override
  Future<List<DiagnosisResult>> runDiagnosis({void Function(DiagnosisResult step)? onStep}) async {
    final results = <DiagnosisResult>[];

    void emit(DiagnosisResult r) {
      results.add(r);
      onStep?.call(r);
    }

    emit(await _checkDns('网络连接', 'www.baidu.com'));
    emit(await _checkDns('DNS 解析', kSmsServiceHost));
    emit(await _checkHttp('短信服务可达', Uri.https(kSmsServiceHost, '/')));
    emit(await _checkHttp('崩溃上报可达', Uri.https(kSentryIngestHost, '/')));

    return results;
  }

  /// DNS 解析检测：能解析出任意 IPv4/IPv6 即成功。
  Future<DiagnosisResult> _checkDns(String name, String host) async {
    final watch = Stopwatch()..start();
    try {
      final addresses = await InternetAddress.lookup(host, type: InternetAddressType.any).timeout(stepTimeout);
      watch.stop();
      final ips = addresses.map((a) => a.address).take(2).join(', ');
      return DiagnosisResult(
        name: name,
        success: addresses.isNotEmpty,
        detail: addresses.isNotEmpty ? '解析成功：$ips (${watch.elapsedMilliseconds}ms)' : '解析结果为空',
      );
    } catch (e) {
      watch.stop();
      return DiagnosisResult(name: name, success: false, detail: '失败：${_brief(e)} (${watch.elapsedMilliseconds}ms)');
    }
  }

  /// HTTP 可达性检测：只要与主机完成 TLS 握手并收到任意 HTTP 响应即算可达
  /// （403/404/405 等同样说明服务在线；仅网络层异常才算失败）。
  Future<DiagnosisResult> _checkHttp(String name, Uri url) async {
    final watch = Stopwatch()..start();
    final client = HttpClient();
    client.connectionTimeout = stepTimeout;
    try {
      final request = await client.headUrl(url).timeout(stepTimeout);
      final response = await request.close().timeout(stepTimeout);
      await response.drain<void>();
      watch.stop();
      // HEAD 不被支持时（405）服务仍在线，视为可达。
      final reachable = response.statusCode < 500;
      return DiagnosisResult(
        name: name,
        success: reachable,
        detail: reachable
            ? '可达（HTTP ${response.statusCode}，${watch.elapsedMilliseconds}ms）'
            : '服务异常（HTTP ${response.statusCode}）',
      );
    } catch (e) {
      watch.stop();
      return DiagnosisResult(name: name, success: false, detail: '失败：${_brief(e)} (${watch.elapsedMilliseconds}ms)');
    } finally {
      client.close(force: true);
    }
  }

  /// 错误摘要：压成单行并截断，避免 detail 撑爆卡片。
  static String _brief(Object e) {
    final line = e.toString().replaceAll('\n', ' ').trim();
    return line.length <= 80 ? line : '${line.substring(0, 77)}...';
  }
}
