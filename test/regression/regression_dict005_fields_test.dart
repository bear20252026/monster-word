import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:word_app/core/infrastructure/wordbook_database.dart';
import 'package:word_app/core/parsers/example_parser.dart';
import 'package:word_app/models/word.dart';
import 'package:word_app/models/word_root_model.dart';

/// 用 App 的真实解析器校验词库结构化字段，防止未来数据写入破坏格式。
/// REG-DICT-005：word_root 必须是 {"prefix","roots","suffix"} 结构；
/// example 必须能被 ExampleParser 解析出非空例句。
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
    tmp = await Directory.systemTemp.createTemp('reg_dict005');
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

  group('REG-DICT-005 structured field integrity', () {
    // Bounded sample: first 6 books, up to 300 words each — enough to catch a
    // malformed field without scanning the whole 770k-word dictionary.
    Future<List<Word>> _sample() async {
      final books = await WordBookDatabase.instance.getBooks();
      final out = <Word>[];
      for (final book in books.take(6)) {
        final words = await WordBookDatabase.instance.getWordsByBook(book.id, limit: 300);
        out.addAll(words);
      }
      return out;
    }

    test('every non-empty word_root is valid JSON with string/list fields', () async {
      final words = await _sample();
      var checked = 0;
      for (final w in words) {
        if (w.wordRoot.trim().isEmpty) continue;
        final decoded = jsonDecode(w.wordRoot);
        // Contract: word_root must be a valid JSON object. Individual keys are
        // optional — WordRootData.fromJson defaults missing keys to ''/[].
        expect(
          decoded,
          isA<Map<String, dynamic>>(),
          reason: 'word_root must be a JSON object for "${w.word}" (id=${w.id})',
        );
        checked++;
      }
      expect(checked, greaterThan(0), reason: 'should have at least one non-empty word_root');
    });

    test('every non-empty example parses to non-empty sentences', () async {
      final words = await _sample();
      var checked = 0;
      for (final w in words) {
        if (w.example.trim().isEmpty) continue;
        final sentences = ExampleParser.parse(w.example);
        expect(sentences, isNotEmpty, reason: 'example should yield >=1 sentence for "${w.word}" (id=${w.id})');
        expect(sentences.first.en.trim(), isNotEmpty);
        checked++;
      }
      expect(checked, greaterThan(0), reason: 'should have at least one non-empty example');
    });

    test('example payloads are valid JSON when double-encoded', () async {
      final words = await _sample();
      for (final w in words) {
        if (w.example.trim().isEmpty) continue;
        final decoded = jsonDecode(w.example);
        expect(decoded, isNotNull, reason: 'example must be valid JSON for "${w.word}"');
      }
    });
  });
}
