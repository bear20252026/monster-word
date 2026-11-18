// 第四轮审计 M5（2026-11-18）：检查更新控制器单测。
//
// 控制器从 more_settings_page 内联编排下沉而来，这里验证：版本加载（含
// buildNumber 口径与失败兜底）、busy 闸拒重入、结果三分类、releaseUrl 安全
// 校验（只放行 https+github.com）、更新日志摘要（压空行/图片标记/截断）。
// 弹窗 UI 仍由 more_settings_page_test 守卫（零视觉变化）。
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:word_app/features/settings/application/update_check_controller.dart';
import 'package:word_app/features/settings/application/update_check_service.dart';
import 'package:word_app/features/settings/domain/version_compare.dart';

class _FakeService implements UpdateCheckService {
  _FakeService(this.result);

  UpdateCheckResult result;
  int calls = 0;
  String? lastVersion;
  Completer<UpdateCheckResult>? gate;

  @override
  Future<UpdateCheckResult> check({required String currentVersion}) {
    calls++;
    lastVersion = currentVersion;
    if (gate != null) return gate!.future;
    return Future.value(result);
  }
}

UpdateCheckResult _result({bool failed = false, bool hasUpdate = false, String? notes, String url = ''}) =>
    UpdateCheckResult(
      currentVersion: '1.0.0+1',
      latestVersion: '2.0.0+2',
      releaseUrl: url,
      notes: notes,
      hasUpdate: hasUpdate,
      failed: failed,
    );

void main() {
  group('版本加载', () {
    test('loadVersion 注入加载器结果并通知', () async {
      final controller = UpdateCheckController(service: _FakeService(_result()), versionLoader: () async => '9.9.9+1');
      addTearDown(controller.dispose);
      var notifications = 0;
      controller.addListener(() => notifications++);

      await controller.loadVersion();

      expect(controller.appVersion, '9.9.9+1');
      expect(notifications, 1);
    });

    test('loadVersion 失败兜底：版本保持空、不抛、不通知', () async {
      final controller = UpdateCheckController(
        service: _FakeService(_result()),
        versionLoader: () async => throw StateError('boom'),
      );
      addTearDown(controller.dispose);
      var notifications = 0;
      controller.addListener(() => notifications++);

      await controller.loadVersion();

      expect(controller.appVersion, '');
      expect(notifications, 0);
    });
  });

  group('检查编排', () {
    test('失败结果分类 failed', () async {
      final controller = UpdateCheckController(service: _FakeService(_result(failed: true)));
      addTearDown(controller.dispose);
      final (outcome, result) = await controller.check();
      expect(outcome, UpdateCheckOutcome.failed);
      expect(result, isNotNull);
      expect(controller.isChecking, isFalse);
    });

    test('有新版分类 hasUpdate', () async {
      final controller = UpdateCheckController(service: _FakeService(_result(hasUpdate: true)));
      addTearDown(controller.dispose);
      final (outcome, _) = await controller.check();
      expect(outcome, UpdateCheckOutcome.hasUpdate);
    });

    test('已最新分类 upToDate', () async {
      final controller = UpdateCheckController(service: _FakeService(_result()));
      addTearDown(controller.dispose);
      final (outcome, _) = await controller.check();
      expect(outcome, UpdateCheckOutcome.upToDate);
    });

    test('check 用当前 appVersion 作比较口径', () async {
      final service = _FakeService(_result());
      final controller = UpdateCheckController(service: service, versionLoader: () async => '3.1.4+15');
      addTearDown(controller.dispose);
      await controller.loadVersion();
      await controller.check();
      expect(service.lastVersion, '3.1.4+15');
    });

    test('busy 闸：在途重入被拒，不发起第二次请求', () async {
      final service = _FakeService(_result());
      final gate = Completer<UpdateCheckResult>();
      service.gate = gate;
      final controller = UpdateCheckController(service: service);
      addTearDown(controller.dispose);

      final first = controller.check();
      expect(controller.isChecking, isTrue);
      final (busyOutcome, busyResult) = await controller.check();
      expect(busyOutcome, UpdateCheckOutcome.busy);
      expect(busyResult, isNull);
      expect(service.calls, 1);

      gate.complete(_result(hasUpdate: true));
      final (outcome, _) = await first;
      expect(outcome, UpdateCheckOutcome.hasUpdate);
      expect(controller.isChecking, isFalse);
    });
  });

  group('releaseUrl 安全校验', () {
    test('放行 https + github.com', () {
      expect(UpdateCheckController.safeReleaseUri('https://github.com/bear20252026/monster-word/releases'), isNotNull);
    });

    test('拒绝非 https、非 github.com、非法 URI', () {
      expect(UpdateCheckController.safeReleaseUri('http://github.com/x'), isNull);
      expect(UpdateCheckController.safeReleaseUri('https://evil.com/x'), isNull);
      expect(UpdateCheckController.safeReleaseUri('file:///etc/passwd'), isNull);
      expect(UpdateCheckController.safeReleaseUri('custom://github.com'), isNull);
      expect(UpdateCheckController.safeReleaseUri(''), isNull);
      expect(UpdateCheckController.safeReleaseUri('https://github.com.evil.com/x'), isNull);
    });
  });

  group('更新日志摘要', () {
    test('null 返回空串', () {
      expect(UpdateCheckController.notesPreview(null), '');
    });

    test('压掉空行与图片标记', () {
      const notes = '第一行\n\n![img](x)\n第二行\n  \n第三行';
      expect(UpdateCheckController.notesPreview(notes), '第一行\n第二行\n第三行');
    });

    test('超过 maxLines 截断并加省略号', () {
      final notes = List.generate(10, (i) => '行$i').join('\n');
      final preview = UpdateCheckController.notesPreview(notes, maxLines: 6);
      expect(preview, '行0\n行1\n行2\n行3\n行4\n行5\n…');
    });

    test('恰好 maxLines 不加省略号', () {
      final notes = List.generate(6, (i) => '行$i').join('\n');
      expect(UpdateCheckController.notesPreview(notes, maxLines: 6), '行0\n行1\n行2\n行3\n行4\n行5');
    });
  });
}
