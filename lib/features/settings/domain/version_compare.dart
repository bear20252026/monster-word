// 由 Claude 团队生成 | Monster Word App

// 检查更新结果值对象与版本比较纯函数。
library;

/// 检查更新结果。
class UpdateCheckResult {
  final String currentVersion;
  final String latestVersion;

  /// Release 页面地址（有新版时用于跳转下载）。
  final String releaseUrl;

  /// Release 更新日志（原文，可为空）。
  final String? notes;

  /// 远端是否比当前版本新。
  final bool hasUpdate;

  /// 网络请求是否失败（失败时 latestVersion/releaseUrl 无效）。
  final bool failed;

  const UpdateCheckResult({
    required this.currentVersion,
    required this.latestVersion,
    required this.releaseUrl,
    this.notes,
    required this.hasUpdate,
    this.failed = false,
  });
}

/// 比较两个语义化版本（支持 `v` 前缀与 `+build` 后缀）。
/// 返回正数表示 [a] 更新，负数表示 [b] 更新，0 表示相同。
/// core（major.minor.patch）优先；core 相同时 build 号大者新（缺失按 0）。
int compareVersions(String a, String b) {
  final (aCore, aBuild) = _split(a);
  final (bCore, bBuild) = _split(b);

  for (var i = 0; i < 3; i++) {
    final cmp = aCore[i].compareTo(bCore[i]);
    if (cmp != 0) return cmp;
  }
  return aBuild.compareTo(bBuild);
}

(List<int>, int) _split(String version) {
  var v = version.trim();
  if (v.startsWith('v')) v = v.substring(1);
  var build = 0;
  final plusIndex = v.indexOf('+');
  if (plusIndex >= 0) {
    build = int.tryParse(v.substring(plusIndex + 1)) ?? 0;
    v = v.substring(0, plusIndex);
  }
  final parts = v.split('.');
  final core = List<int>.generate(3, (int i) => i < parts.length ? (int.tryParse(parts[i]) ?? 0) : 0);
  return (core, build);
}
