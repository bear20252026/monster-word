import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:word_app/core/infrastructure/wordbook_database.dart';
import 'package:word_app/core/parsers/example_parser.dart';

/// REG-DICT-006：例句缺口批次（Tatoeba / OpenSubtitles / 原生句池）守护。
/// 批次写入的词必须能被 App 真实 ExampleParser 解析出非空例句，
/// 且目标词在句中以 <b> 高亮、来源标签正确。
class _FakePathProvider extends PathProviderPlatform {
  final String dir;
  _FakePathProvider(this.dir);
  @override
  Future<String?> getApplicationSupportPath() async => dir;
  @override
  Future<String?> getApplicationDocumentsPath() async => dir;
  @override
  Future<String?> getTemporaryPath() async => dir;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tmp;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    tmp = await Directory.systemTemp.createTemp('reg_dict006');
    PathProviderPlatform.instance = _FakePathProvider(tmp.path);
    await WordBookDatabase.instance.initialize();
  });

  tearDownAll(() async {
    try {
      await WordBookDatabase.instance.close();
    } catch (_) {}
    try {
      await tmp.delete(recursive: true);
    } catch (_) {}
  });

  group('REG-DICT-006 sentence backfill integrity', () {
    // 抽样覆盖三个来源与两种形态（单词/词组）。
    const backfilled = {
      'unmitigated': 'OpenSubtitles',
      'warmonger': 'OpenSubtitles',
      'folic acid': 'OpenSubtitles', // 词组
      'anti-inflammatory': 'OpenSubtitles', // 连字符词
      'singly': 'Tatoeba',
      'wildebeest': 'Tatoeba',
    };

    test('backfilled words parse to sentences via the real ExampleParser', () async {
      final words = await WordBookDatabase.instance.getWordsByNames(backfilled.keys.toSet());
      expect(words.length, backfilled.length, reason: 'all sampled words must exist');
      for (final w in words) {
        final sentences = ExampleParser.parse(w.example);
        expect(sentences, isNotEmpty, reason: '"${w.word}" must have >=1 sentence');
        for (final s in sentences) {
          expect(s.en.trim(), isNotEmpty, reason: '"${w.word}" sentence en must not be empty');
          expect(s.cn.trim(), isNotEmpty, reason: '"${w.word}" sentence cn must not be empty');
        }
        final expectedSource = backfilled[w.word.toLowerCase()]!;
        expect(
          sentences.any((s) => s.source == expectedSource),
          true,
          reason: '"${w.word}" should carry source "$expectedSource"',
        );
      }
    });

    test('target word is highlighted in backfilled sentences', () async {
      final words = await WordBookDatabase.instance.getWordsByNames({'warmonger', 'singly'});
      for (final w in words) {
        final sentences = ExampleParser.parse(w.example);
        final hasHighlight = sentences.any((s) => s.highlightedParts.any((p) => p.highlight));
        expect(hasHighlight, true, reason: '"${w.word}" should have a <b> highlight');
      }
    });
  });
}
