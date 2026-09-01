// 由 Claude 团队生成 | Monster Word App

// 基于 GitHub Releases API 的真实更新检查：
// 与 CI 发版共用同一事实来源（tag vX.Y.Z+N → Release）。
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:word_app/features/settings/application/update_check_service.dart';
import 'package:word_app/features/settings/domain/version_compare.dart';

class GithubUpdateCheckService implements UpdateCheckService {
  GithubUpdateCheckService({this.fetchOverride});

  static const String repoUrl = 'https://github.com/bear20252026/monster-word';
  static const String _latestApiUrl = '$repoUrl/releases/latest';
  static const Duration _timeout = Duration(seconds: 10);

  /// 测试注入：绕过真实 HTTP，返回 JSON 原文。
  final Future<String> Function(Uri url)? fetchOverride;

  @override
  Future<UpdateCheckResult> check({required String currentVersion}) async {
    try {
      final body = await _fetch(Uri.parse(_latestApiUrl));
      final Map<String, dynamic> json = jsonDecode(body) as Map<String, dynamic>;

      final tag = (json['tag_name'] as String?)?.trim() ?? '';
      final latest = tag.startsWith('v') ? tag.substring(1) : tag;
      final releaseUrl = (json['html_url'] as String?)?.trim().isNotEmpty == true
          ? json['html_url'] as String
          : _latestApiUrl;
      final notes = (json['body'] as String?)?.trim();

      return UpdateCheckResult(
        currentVersion: currentVersion,
        latestVersion: latest,
        releaseUrl: releaseUrl,
        notes: (notes == null || notes.isEmpty) ? null : notes,
        hasUpdate: compareVersions(latest, currentVersion) > 0,
      );
    } catch (_) {
      return UpdateCheckResult(
        currentVersion: currentVersion,
        latestVersion: '',
        releaseUrl: repoUrl,
        hasUpdate: false,
        failed: true,
      );
    }
  }

  Future<String> _fetch(Uri url) async {
    final override = fetchOverride;
    if (override != null) return override(url);

    final client = HttpClient();
    try {
      final request = await client.getUrl(url).timeout(_timeout);
      request.headers.set(HttpHeaders.acceptHeader, 'application/vnd.github+json');
      final response = await request.close().timeout(_timeout);
      if (response.statusCode != 200) {
        throw HttpException('GitHub API HTTP ${response.statusCode}');
      }
      return await response.transform(utf8.decoder).join().timeout(_timeout);
    } finally {
      client.close(force: true);
    }
  }
}
