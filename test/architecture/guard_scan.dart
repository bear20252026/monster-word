// 第四轮审计 M12（2026-11-19）：守卫共享扫描层（第一批）。
//
// 背景：28 个架构守卫各自重复「全库 walk + part 家族解析」机械逻辑（审计 M12
// 「9 套守卫各自全库 walk + 剥注释逻辑重复」）。本文件抽出**纯机械、无语义分歧**
// 的两层共享：
//   ① 文件枚举：目录/文件根 → 归一化路径的 dart 文件列表；
//   ② part 家族解析：`part of 'x.dart'` → 主文件（sp_direct_access 与
//      static_prefs_facade 原本逐字重复）。
//
// **刻意不抽**各守卫的扫描根选择、白名单、剥注释/掩码、匹配判定与行号算法——
// 那些各有语义（如 scale_doc_guard 专门查注释文本、故意不剥注释；color/alpha
// 扫描根与读行/读串口径各异），统一会改变守卫行为、制造假绿或误报。剥注释共享
// 留待后续逐守卫评估批（M12 余项）。
//
// 路径归一保留各守卫原口径：enumerateDartFiles 用 Platform.pathSeparator
// （part 解析守卫原口径），scanRootDartFiles 用 '\\'→'/'（walk 守卫原口径）；
// 二者在 Windows 等价、在 POSIX 均保持 '/'，迁移不改判定结果。
import 'dart:io';

/// 一个 dart 源文件（归一化 '/' 路径 + 行列表）。
class DartSource {
  DartSource(this.path, this.lines);

  /// 归一化为 '/' 的相对路径（如 lib/features/.../x.dart）。
  final String path;
  final List<String> lines;
}

/// 枚举 [root]（目录或单文件）下全部 dart 文件，路径按 Platform.pathSeparator
/// 归一为 '/'。目录不存在则跳过（与多数守卫 `if (!dir.existsSync()) continue`
/// 同口径）；单文件根（如 lib/main.dart）直接收录。
List<DartSource> enumerateDartFiles(String root) {
  final out = <DartSource>[];
  final type = FileSystemEntity.typeSync(root);
  if (type == FileSystemEntityType.directory) {
    for (final entity in Directory(root).listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      out.add(DartSource(entity.path.replaceAll(Platform.pathSeparator, '/'), entity.readAsLinesSync()));
    }
  } else if (type == FileSystemEntityType.file && root.endsWith('.dart')) {
    final f = File(root);
    out.add(DartSource(f.path.replaceAll(Platform.pathSeparator, '/'), f.readAsLinesSync()));
  }
  return out;
}

/// 按扫描根列表枚举 dart 文件，路径按 '\\'→'/' 归一（walk 守卫原口径）。
/// 目录根不存在则跳过；文件根（lib/main.dart）直接收录。多根命中同一文件会
/// 去重（按归一路径），与守卫逐根扫描后合并的口径一致。
List<DartSource> scanRootDartFiles(List<String> roots) {
  final seen = <String>{};
  final out = <DartSource>[];
  for (final root in roots) {
    final type = FileSystemEntity.typeSync(root);
    if (type == FileSystemEntityType.directory) {
      for (final entity in Directory(root).listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final rel = entity.path.replaceAll('\\', '/');
        if (seen.add(rel)) out.add(DartSource(rel, entity.readAsLinesSync()));
      }
    } else if (type == FileSystemEntityType.file && root.endsWith('.dart')) {
      final rel = root.replaceAll('\\', '/');
      if (seen.add(rel)) out.add(DartSource(rel, File(root).readAsLinesSync()));
    }
  }
  return out;
}

/// 解析 part 家族：返回「part 文件归一路径 → 其主文件归一路径」映射。
///
/// 口径与 sp_direct_access / static_prefs_facade 原实现逐字一致：扫描每个文件
/// 的行，命中首个 `part of 'x.dart'`（或者双引号）即把该文件归到同目录下 x.dart。
/// 非 part 文件不出现在映射里（消费方用 `map[path] ?? path` 取主文件）。
Map<String, String> resolvePartOwners(List<DartSource> files) {
  final partOfDirective = RegExp(r'''^\s*part\s+of\s+['"]([^'"]+)['"]''');
  final owners = <String, String>{};
  for (final file in files) {
    final dir = file.path.substring(0, file.path.lastIndexOf('/'));
    for (final line in file.lines) {
      final m = partOfDirective.firstMatch(line);
      if (m != null) {
        owners[file.path] = '$dir/${m.group(1)}';
        break;
      }
    }
  }
  return owners;
}
