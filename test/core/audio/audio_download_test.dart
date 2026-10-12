// REG-AUDIT-005 守护：单词音频主/备双源下载逻辑（台账「待补单测」补齐）。
//
// 三分支：主源成功不再碰备源；主源失败切备源；双败返回失败态。
// 经 AudioDownloader.fetchOverride 注入，不发真网络请求。
// 附：SfxPlayer 音量表（REG-SFX-001 配套）与 distractor_generator 表测
// 归于本文件的兄弟测试文件，见 test/core/utils/sfx_volume_test.dart、
// test/core/engine/distractor_generator_test.dart。
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:word_app/core/audio/audio_players.dart';

void main() {
  late Directory tmpDir;
  late String localPath;
  final requested = <Uri>[];

  setUp(() {
    tmpDir = Directory.systemTemp.createTempSync('audio_dl_test');
    localPath = '${tmpDir.path}/word.mp3';
    requested.clear();
    AudioDownloader.fetchOverride = (url) async {
      requested.add(url);
      return http.Response('x', 500); // 默认失败，用例各自覆写
    };
  });

  tearDown(() {
    AudioDownloader.fetchOverride = null;
    AudioDownloader.renameOverrideForTest = null;
    tmpDir.deleteSync(recursive: true);
  });

  http.Response ok(Uint8List bytes) => http.Response.bytes(bytes, 200);

  /// 合法 MP3 载荷（ID3v2 文件头 'ID3' + 任意尾字节）。
  ///
  /// MW-50 起下载落盘后校验 magic bytes：测试载荷必须带真实文件头，否则会被
  /// 判为「CDN 返回的 HTML 错误页」而按 415 丢弃（见文件末尾的 415 用例）。
  Uint8List mp3(List<int> tail) => Uint8List.fromList([0x49, 0x44, 0x33, ...tail]);

  test('主源成功：落盘原子文件、不再请求备源', () async {
    AudioDownloader.fetchOverride = (url) async {
      requested.add(url);
      return ok(mp3([1, 2, 3, 4]));
    };
    final result = await AudioDownloader.downloadFile(
      localPath,
      'https://primary.example/a.mp3',
      fallbackUrl: 'https://fallback.example/a.mp3',
    );
    expect(result.success, isTrue);
    expect(result.file?.readAsBytesSync(), [0x49, 0x44, 0x33, 1, 2, 3, 4]);
    expect(requested.length, 1, reason: '主源成功不应触碰备源');
    expect(File('$localPath.tmp').existsSync(), isFalse, reason: 'tmp 必须原子改名不留半写文件');
  });

  test('主源失败（404）→ 切备源成功', () async {
    AudioDownloader.fetchOverride = (url) async {
      requested.add(url);
      return url.host == 'primary.example' ? http.Response('nf', 404) : ok(mp3([9]));
    };
    final result = await AudioDownloader.downloadFile(
      localPath,
      'https://primary.example/a.mp3',
      fallbackUrl: 'https://fallback.example/a.mp3',
    );
    expect(result.success, isTrue);
    expect(result.file?.readAsBytesSync(), [0x49, 0x44, 0x33, 9]);
    expect(requested.map((u) => u.host), ['primary.example', 'fallback.example'], reason: '失败后必须切备源');
  });

  test('双源皆败：返回失败态且两次请求都发生', () async {
    final result = await AudioDownloader.downloadFile(
      localPath,
      'https://primary.example/a.mp3',
      fallbackUrl: 'https://fallback.example/a.mp3',
    );
    expect(result.success, isFalse);
    expect(result.file, isNull);
    expect(requested.length, 2);
    expect(File(localPath).existsSync(), isFalse, reason: '失败不得留下坏缓存文件');
  });

  test('无备源时主源失败即止（单源词）', () async {
    final result = await AudioDownloader.downloadFile(localPath, 'https://primary.example/a.mp3');
    expect(result.success, isFalse);
    expect(requested.length, 1);
  });

  test('超大小上限（>10MB）：按 413 拒收且不落盘', () async {
    final huge = Uint8List(10 * 1024 * 1024 + 1);
    AudioDownloader.fetchOverride = (url) async {
      requested.add(url);
      return ok(huge);
    };
    final result = await AudioDownloader.downloadFile(
      localPath,
      'https://primary.example/a.mp3',
      fallbackUrl: 'https://fallback.example/a.mp3',
    );
    expect(result.success, isFalse, reason: '防恶意服务器撑爆磁盘（安全审计 S4）');
    expect(File(localPath).existsSync(), isFalse);
    expect(requested.length, 2, reason: '413 亦触发备源重试');
  });

  test('MW-50：CDN 返回 HTML 错误页（200 + <!DOCTYPE）→ 415 拒收且不落盘', () async {
    AudioDownloader.fetchOverride = (url) async {
      requested.add(url);
      return ok(Uint8List.fromList('<!DOCTYPE html><html>not found</html>'.codeUnits));
    };
    final result = await AudioDownloader.downloadFile(
      localPath,
      'https://primary.example/a.mp3',
      fallbackUrl: 'https://fallback.example/a.mp3',
    );
    expect(result.success, isFalse, reason: '非音频内容不得当作音频缓存（否则此后永久命中坏缓存）');
    expect(result.statusCode, 415);
    expect(File(localPath).existsSync(), isFalse, reason: '判为损坏必须丢弃，不留半写文件');
    expect(File('$localPath.tmp').existsSync(), isFalse);
    expect(requested.length, 2, reason: '415 亦触发备源重试');
  });

  // DN-D01 同类口径：替换已存在缓存时，**绝不先删原件再改名**——先删后改名时
  // 一旦第二次改名也失败，原件与新文件会同时不存在（音频表现为该词彻底播不出，
  // 且离线时无法恢复）。以下三条锁定「失败必留一份完整旧数据」。
  group('替换已存在缓存的失败保护（DN-D01 同类）', () {
    const oldBytes = [0x49, 0x44, 0x33, 9, 9, 9];

    test('全部改名失败 → 原件一字未丢', () async {
      await File(localPath).writeAsBytes(oldBytes);
      AudioDownloader.fetchOverride = (url) async {
        requested.add(url);
        return ok(mp3([1, 2, 3, 4]));
      };
      AudioDownloader.renameOverrideForTest = (from, to) async {
        throw const FileSystemException('injected rename failure');
      };

      final result = await AudioDownloader.downloadFile(localPath, 'https://primary.example/a.mp3');

      expect(result.success, isFalse);
      expect(File(localPath).readAsBytesSync(), oldBytes, reason: '替换失败绝不能连原件一起丢（先删后改名即此缺陷）');
    });

    test('移走原件后第二次改名失败 → 原件回滚到位、无 .old 残留', () async {
      await File(localPath).writeAsBytes(oldBytes);
      AudioDownloader.fetchOverride = (url) async {
        requested.add(url);
        return ok(mp3([1, 2, 3, 4]));
      };
      // 调用序：① tmp→目标(失败) ② 原件→.old(成功) ③ tmp→目标(失败) ④ .old→目标(放回成功)
      var call = 0;
      AudioDownloader.renameOverrideForTest = (from, to) async {
        call++;
        if (call == 1 || call == 3) {
          throw const FileSystemException('injected rename failure');
        }
        await from.rename(to);
      };

      final result = await AudioDownloader.downloadFile(localPath, 'https://primary.example/a.mp3');

      expect(result.success, isFalse);
      expect(File(localPath).readAsBytesSync(), oldBytes, reason: '原件必须被放回原位');
      expect(File('$localPath.old').existsSync(), isFalse, reason: '.old 已放回，不应残留');
    });

    test('替换成功 → 新内容生效且不留 .old 残留', () async {
      await File(localPath).writeAsBytes(oldBytes);
      AudioDownloader.fetchOverride = (url) async {
        requested.add(url);
        return ok(mp3([1, 2, 3, 4]));
      };

      final result = await AudioDownloader.downloadFile(localPath, 'https://primary.example/a.mp3');

      expect(result.success, isTrue);
      expect(File(localPath).readAsBytesSync(), [0x49, 0x44, 0x33, 1, 2, 3, 4]);
      expect(File('$localPath.old').existsSync(), isFalse);
      expect(File('$localPath.tmp').existsSync(), isFalse);
    });
  });
}
