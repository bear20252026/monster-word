// 由 Claude 团队生成 | Monster Word App

// GitHub 更新检查服务测试：版本比较纯函数、Release JSON 解析、失败兜底。
// REG-UPD-001：检查更新必须真实对比远端版本，禁止无比对直接弹「已是最新」。
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:word_app/features/settings/data/github_update_check_service.dart';
import 'package:word_app/features/settings/domain/version_compare.dart';

void main() {
  group('compareVersions', () {
    test('相同版本为 0（含 +build）', () {
      expect(compareVersions('2.7.27+68', '2.7.27+68'), 0);
      expect(compareVersions('v2.7.27+68', '2.7.27+68'), 0);
    });

    test('core 优先于 build', () {
      // 2.7.28+5 应新于 2.7.27+99（patch 大者新，build 不参与跨段比较）。
      expect(compareVersions('2.7.28+5', '2.7.27+99'), greaterThan(0));
      expect(compareVersions('3.0.0', '2.99.99+999'), greaterThan(0));
    });

    test('core 相同时 build 大者新（缺失按 0）', () {
      expect(compareVersions('2.7.27+68', '2.7.27'), greaterThan(0));
      expect(compareVersions('2.7.27+69', '2.7.27+68'), greaterThan(0));
      expect(compareVersions('2.7.27', '2.7.27+1'), lessThan(0));
    });

    test('v 前缀与缺失段容错', () {
      expect(compareVersions('v2.8.0', '2.7.27+68'), greaterThan(0));
      expect(compareVersions('2.7', '2.7.0'), 0);
    });
  });

  group('GithubUpdateCheckService (REG-UPD-001)', () {
    test('远端 tag 更新时 hasUpdate 为真并透传 releaseUrl 与 notes', () async {
      final service = GithubUpdateCheckService(
        fetchOverride: (url) async => jsonEncode(<String, dynamic>{
          'tag_name': 'v2.7.28+69',
          'html_url': 'https://github.com/bear20252026/monster-word/releases/tag/v2.7.28%2B69',
          'body': '## 修复\n- 词典页崩溃\n- Dock 重叠',
        }),
      );

      final result = await service.check(currentVersion: '2.7.27+68');

      expect(result.failed, isFalse);
      expect(result.hasUpdate, isTrue);
      expect(result.latestVersion, '2.7.28+69');
      expect(result.releaseUrl, contains('releases/tag'));
      expect(result.notes, contains('词典页崩溃'));
    });

    test('远端不比当前新时 hasUpdate 为假', () async {
      final service = GithubUpdateCheckService(
        fetchOverride: (url) async => jsonEncode(<String, dynamic>{
          'tag_name': 'v2.7.27+68',
          'html_url': 'https://github.com/bear20252026/monster-word/releases/latest',
        }),
      );

      final result = await service.check(currentVersion: '2.7.27+68');

      expect(result.failed, isFalse);
      expect(result.hasUpdate, isFalse);
    });

    test('网络失败时 failed 为真（不假装已是最新）', () async {
      final service = GithubUpdateCheckService(fetchOverride: (url) async => throw Exception('network down'));

      final result = await service.check(currentVersion: '2.7.27+68');

      expect(result.failed, isTrue);
      expect(result.hasUpdate, isFalse);
    });
  });
}
