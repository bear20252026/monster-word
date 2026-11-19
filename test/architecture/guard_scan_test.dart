// 第四轮审计 M12（2026-11-19）：守卫共享扫描层自测。
//
// 共享层是全部守卫的扫描底座，若有 bug 会让守卫假绿/误报，故用临时目录构造
// 可控样本整表验证：目录/文件根枚举、不存在根跳过、非 dart 过滤、多根去重、
// part of 单/双引号解析、首个 part of 生效、非 part 文件不入映射。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'guard_scan.dart';

void main() {
  late Directory tmp;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('guard_scan_test');
  });

  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  String write(String rel, String content) {
    final f = File('${tmp.path}/$rel');
    f.parent.createSync(recursive: true);
    f.writeAsStringSync(content);
    return f.path;
  }

  String norm(String p) => p.replaceAll(Platform.pathSeparator, '/');

  group('enumerateDartFiles', () {
    test('目录根递归枚举 dart 文件，过滤非 dart', () {
      write('a.dart', 'var a = 1;');
      write('sub/b.dart', 'var b = 2;');
      write('sub/c.txt', 'not dart');
      final files = enumerateDartFiles(tmp.path);
      final paths = files.map((f) => f.path).toSet();
      expect(paths, {norm('${tmp.path}/a.dart'), norm('${tmp.path}/sub/b.dart')});
    });

    test('单文件根直接收录', () {
      final p = write('main.dart', 'void main() {}');
      final files = enumerateDartFiles(p);
      expect(files.single.path, norm(p));
      expect(files.single.lines, ['void main() {}']);
    });

    test('不存在的根返回空（不抛）', () {
      expect(enumerateDartFiles('${tmp.path}/nope'), isEmpty);
    });

    test('行内容如实读入', () {
      write('x.dart', 'line1\nline2\n');
      final files = enumerateDartFiles(tmp.path);
      expect(files.single.lines, ['line1', 'line2']);
    });
  });

  group('scanRootDartFiles', () {
    test('多根枚举并按归一路径去重', () {
      write('lib/a.dart', 'var a = 1;');
      write('lib/sub/b.dart', 'var b = 2;');
      write('other/c.dart', 'var c = 3;');
      // 两根重叠（lib 与 lib/sub），b.dart 只应出现一次。
      final files = scanRootDartFiles(['${tmp.path}/lib', '${tmp.path}/lib/sub', '${tmp.path}/other']);
      final paths = files.map((f) => f.path).toList();
      expect(paths.where((p) => p.endsWith('sub/b.dart')).length, 1);
      expect(paths.toSet().length, 3);
    });

    test('目录根与文件根混合，不存在根跳过', () {
      write('lib/a.dart', 'var a = 1;');
      final mainPath = write('lib/main.dart', 'void main() {}');
      final files = scanRootDartFiles(['${tmp.path}/lib', mainPath, '${tmp.path}/gone']);
      expect(files.map((f) => f.path).toSet().length, 2);
    });
  });

  group('resolvePartOwners', () {
    test('part of 单引号归到同目录主文件', () {
      final files = [
        DartSource('lib/x/main.dart', ["part 'part_a.dart';", 'class Main {}']),
        DartSource('lib/x/part_a.dart', ["part of 'main.dart';", 'extension E on Main {}']),
      ];
      final owners = resolvePartOwners(files);
      expect(owners['lib/x/part_a.dart'], 'lib/x/main.dart');
      expect(owners.containsKey('lib/x/main.dart'), isFalse);
    });

    test('part of 双引号同样解析', () {
      final files = [
        DartSource('lib/y/p.dart', ['part of "host.dart";']),
      ];
      expect(resolvePartOwners(files)['lib/y/p.dart'], 'lib/y/host.dart');
    });

    test('首个 part of 生效，非 part 文件不入映射', () {
      final files = [
        DartSource('lib/z/p.dart', ["part of 'first.dart';", "part of 'second.dart';"]),
        DartSource('lib/z/plain.dart', ['var x = 1;']),
      ];
      final owners = resolvePartOwners(files);
      expect(owners['lib/z/p.dart'], 'lib/z/first.dart');
      expect(owners.containsKey('lib/z/plain.dart'), isFalse);
    });

    test('消费方 map[path] ?? path 取主文件口径', () {
      final files = [
        DartSource('lib/w/main.dart', ["part 'p.dart';"]),
        DartSource('lib/w/p.dart', ["part of 'main.dart';"]),
        DartSource('lib/w/solo.dart', ['var s = 1;']),
      ];
      final owners = resolvePartOwners(files);
      String ownerOf(String p) => owners[p] ?? p;
      expect(ownerOf('lib/w/p.dart'), 'lib/w/main.dart');
      expect(ownerOf('lib/w/solo.dart'), 'lib/w/solo.dart');
    });
  });
}
