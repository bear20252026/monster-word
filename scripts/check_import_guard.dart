// 本机运行架构守卫（ImportGuard）对 lib/ 全库扫描。
//
// 为什么需要它：本仓 `flutter analyze` / `dart analyze` 受 365vpn 影响不可用
// （分析服务器子进程起不来），而架构守卫是 analyzer 之外**最容易在 CI 才暴露**
// 的一类问题（R3 分层 / R4 跨 feature / R5 领域纯净）。ImportGuard 本身是纯 Dart、
// 零 import，所以能在本机直接跑 —— 用它把这一轮反馈从「等 CI」缩到「几秒」。
//
// 用法：dart scripts/check_import_guard.dart
// 退出码：0 = 无违规；1 = 有违规（与 CI 同判据）。

import 'dart:io';

import 'package:word_app/core/import_guard.dart';

/// 把 import 路径解析成 `lib/` 相对逻辑路径（与守卫的路径约定一致）。
String resolve(String fromLogical, String raw) {
  const pkgPrefix = 'package:word_app/';
  if (raw.startsWith(pkgPrefix)) return raw.substring(pkgPrefix.length);
  if (raw.startsWith('dart:') || raw.startsWith('package:')) return raw;

  final dir = fromLogical.contains('/') ? fromLogical.substring(0, fromLogical.lastIndexOf('/')) : '';
  final parts = <String>[...(dir.isEmpty ? <String>[] : dir.split('/')), ...raw.split('/')];
  final out = <String>[];
  for (final p in parts) {
    if (p.isEmpty || p == '.') continue;
    if (p == '..') {
      if (out.isNotEmpty) out.removeLast();
      continue;
    }
    out.add(p);
  }
  return out.join('/');
}

final _importRe = RegExp(r"""^\s*import\s+['"]([^'"]+)['"]""", multiLine: true);

void main() {
  const guard = ImportGuard();
  final libDir = Directory('lib');
  if (!libDir.existsSync()) {
    stderr.writeln('请在仓库根目录运行（找不到 lib/）');
    exit(2);
  }

  var files = 0;
  var imports = 0;
  final violations = <String>[];

  for (final entity in libDir.listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    files++;
    final logical = entity.path.replaceAll(r'\', '/').replaceFirst(RegExp(r'^lib/'), '');
    final text = entity.readAsStringSync();
    for (final m in _importRe.allMatches(text)) {
      imports++;
      final to = resolve(logical, m.group(1)!);
      for (final v in guard.check(from: logical, to: to)) {
        violations.add('  [$logical] $v');
      }
    }
  }

  stdout.writeln('扫描 $files 个文件 / $imports 条 import');
  if (violations.isEmpty) {
    stdout.writeln('✅ 无依赖边界违规');
    return;
  }
  stdout.writeln('❌ 发现 ${violations.length} 条依赖边界违规：');
  for (final v in violations) {
    stdout.writeln(v);
  }
  exit(1);
}
