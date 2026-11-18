// 第四轮审计 M5（2026-11-18）：检查更新编排下沉 application。
//
// 原 more_settings_page 内联约 130 行更新检查逻辑（busy 闸 / 版本加载 /
// 结果分类 / releaseUrl 安全校验 / 更新日志摘要），与页面 UI 混在一起难以单测。
// 现镜像 PetWindowController 范式抽为独立控制器：页面只消费 isChecking /
// appVersion 通知与 check 命令，并按返回结果渲染弹窗（弹窗 UI 逐字留在页面，
// 零视觉变化）。竞态与安全口径逐条保留（注释随迁）。
//
// 可测性：UpdateCheckService 与版本加载器均经构造注入，平台 PackageInfo 在
// 测试里可替换为可控假件（此前这段逻辑在页面里无法单测）。
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:word_app/core/utils/debug_log.dart';
import 'package:word_app/features/settings/application/update_check_service.dart';
import 'package:word_app/features/settings/domain/version_compare.dart';

/// 一次检查更新的结果分类（页面据此渲染对应弹窗）。
enum UpdateCheckOutcome {
  /// 在途重入被拒（未发起新检查）。
  busy,

  /// 网络请求失败。
  failed,

  /// 发现新版本。
  hasUpdate,

  /// 已是最新版本。
  upToDate,
}

/// 检查更新控制器：版本加载 + 请求编排 + 结果分类 + 下载链接安全校验。
class UpdateCheckController extends ChangeNotifier {
  UpdateCheckController({required this.service, Future<String> Function()? versionLoader})
    : _versionLoader = versionLoader ?? _defaultVersionLoader;

  final UpdateCheckService service;
  final Future<String> Function() _versionLoader;

  bool _disposed = false;

  /// 真实应用版本号（含 buildNumber，MW-13 比较口径）。
  String _appVersion = '';
  String get appVersion => _appVersion;

  bool _isChecking = false;
  bool get isChecking => _isChecking;

  /// 页面 initState 调用：加载真实版本号（替换原硬编码）。
  Future<void> loadVersion() async {
    try {
      final version = await _versionLoader();
      if (_disposed) return;
      _appVersion = version;
      notifyListeners();
    } catch (e) {
      debugLog('读取应用版本失败: $e');
    }
  }

  /// 发起一次检查更新。busy 闸拒重入（原 _isChecking 守卫）。
  ///
  /// 返回结果分类与原始结果（页面渲染弹窗用）；在途重入返回 busy + null。
  Future<(UpdateCheckOutcome, UpdateCheckResult?)> check() async {
    if (_isChecking) return (UpdateCheckOutcome.busy, null);
    _isChecking = true;
    notifyListeners();
    try {
      final result = await service.check(currentVersion: _appVersion);
      if (result.failed) return (UpdateCheckOutcome.failed, result);
      if (result.hasUpdate) return (UpdateCheckOutcome.hasUpdate, result);
      return (UpdateCheckOutcome.upToDate, result);
    } finally {
      _isChecking = false;
      if (!_disposed) notifyListeners();
    }
  }

  /// 下载链接安全校验（原页面内联守卫，逐字保留）：releaseUrl 来自 GitHub API
  /// 响应，仓库/Release 失守时可能被注入任意 URI（file:/自定义协议）唤起外部
  /// 程序——只放行 GitHub 站点（https + github.com）。返回 null = 拒绝跳转。
  static Uri? safeReleaseUri(String releaseUrl) {
    final uri = Uri.tryParse(releaseUrl);
    if (uri == null || uri.scheme != 'https' || uri.host != 'github.com') return null;
    return uri;
  }

  /// 更新日志摘要：取前 [maxLines] 行，压掉空行与图片标记（原 _firstLines）。
  static String notesPreview(String? notes, {int maxLines = 6}) {
    if (notes == null) return '';
    final lines = notes
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty && !line.startsWith('!['))
        .toList();
    final picked = lines.take(maxLines).join('\n');
    return lines.length > maxLines ? '$picked\n…' : picked;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// 默认版本加载器：PackageInfo 真实版本 + buildNumber（MW-13：比较口径必须含
/// buildNumber，只取 version 会让「已装最新版」仍被判 hasUpdate）。
Future<String> _defaultVersionLoader() async {
  final info = await PackageInfo.fromPlatform();
  return '${info.version}+${info.buildNumber}';
}
