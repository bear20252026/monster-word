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
    tmpDir.deleteSync(recursive: true);
  });

  http.Response ok(Uint8List bytes) => http.Response.bytes(bytes, 200);

  test('主源成功：落盘原子文件、不再请求备源', () async {
    AudioDownloader.fetchOverride = (url) async {
      requested.add(url);
      return ok(Uint8List.fromList([1, 2, 3, 4]));
    };
    final result = await AudioDownloader.downloadFile(
      localPath,
      'https://primary.example/a.mp3',
      fallbackUrl: 'https://fallback.example/a.mp3',
    );
    expect(result.success, isTrue);
    expect(result.file?.readAsBytesSync(), [1, 2, 3, 4]);
    expect(requested.length, 1, reason: '主源成功不应触碰备源');
    expect(File('$localPath.tmp').existsSync(), isFalse, reason: 'tmp 必须原子改名不留半写文件');
  });

  test('主源失败（404）→ 切备源成功', () async {
    AudioDownloader.fetchOverride = (url) async {
      requested.add(url);
      return url.host == 'primary.example' ? http.Response('nf', 404) : ok(Uint8List.fromList([9]));
    };
    final result = await AudioDownloader.downloadFile(
      localPath,
      'https://primary.example/a.mp3',
      fallbackUrl: 'https://fallback.example/a.mp3',
    );
    expect(result.success, isTrue);
    expect(result.file?.readAsBytesSync(), [9]);
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
}
