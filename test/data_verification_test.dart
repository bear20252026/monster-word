// Wordbook database verification tests
// Expected: 191 books / ~32,000 words / full official library
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:word_app/core/infrastructure/wordbook_database.dart';

/// 词库全量解压 + 抽样 I/O 过重，默认 30s 在并行测试下会超时（2026-09-19 审计 N4）。
const _kHeavyTimeout = Timeout(Duration(minutes: 3));

/// Use temp directory to replace system app dir
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
    tmp = await Directory.systemTemp.createTemp('wordbook_data_test');
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

  group('Book list', () {
    late List<Book> allBooks;

    setUpAll(() async {
      allBooks = await WordBookDatabase.instance.getBooks();
    });

    test('Book count covers full library baseline', () async {
      // M8：与导入管线契约一致——官方 191 + kajweb 81 = 272；管线可追加专题书，
      // 断言「不少于基线」且核心分类齐全，避免硬编码 exact 值卡死数据批次。
      expect(
        allBooks.length,
        greaterThanOrEqualTo(272),
        reason: 'Full library should have at least 272 books, got ${allBooks.length}',
      );
      for (final b in allBooks) {
        expect(b.code.isNotEmpty, true, reason: 'id=${b.id} code should not be empty');
        expect(b.wordCount >= 0, true, reason: '${b.code} wordCount should be non-negative');
      }
    });

    test('Core exam books exist (CET4/CET6/Postgrad/TOEFL/IELTS/GRE)', () async {
      final codes = allBooks.map((b) => b.code.toUpperCase()).toList();
      expect(codes.any((c) => c.contains('CET4')), true, reason: 'Should have CET4 category');
      expect(codes.any((c) => c.contains('CET6')), true, reason: 'Should have CET6 category');
      expect(codes.any((c) => c.contains('TOEFL')), true, reason: 'Should have TOEFL category');
      expect(codes.any((c) => c.contains('IELTS')), true, reason: 'Should have IELTS category');
      expect(codes.any((c) => c.contains('GRE')), true, reason: 'Should have GRE category');
      expect(codes.any((c) => c.contains('KY')), true, reason: 'Should have Postgrad (KY) category');
    });
  });

  group('Words by book', () {
    late List<Book> books;

    setUpAll(() async {
      books = await WordBookDatabase.instance.getBooks();
    });

    test('All sampled books have words', () async {
      final samples = books.take(5).toList()..addAll(books.where((b) => b.code.toUpperCase().contains('CET4')).take(2));
      for (final b in samples) {
        final words = await WordBookDatabase.instance.getWordsByBook(b.id);
        expect(words.isNotEmpty, true, reason: 'Book ${b.name}(id=${b.id}) should have words');
      }
    }, timeout: _kHeavyTimeout);

    test('Word field coverage meets real-world standard', () async {
      final cet4Book = books.firstWhere((b) => b.code.toUpperCase().contains('CET4'), orElse: () => books.first);
      final words = await WordBookDatabase.instance.getWordsByBook(cet4Book.id);
      expect(words.length, greaterThan(10), reason: 'Book ${cet4Book.name} should have plenty of words');

      var noInterpret = 0, noPhonetic = 0, noExample = 0;
      for (final w in words) {
        expect(w.word.isNotEmpty, true, reason: 'Word text should not be empty (id=${w.id})');
        if (w.interpret.trim().isEmpty) noInterpret++;
        if (w.ukPron.isEmpty && w.usPron.isEmpty) noPhonetic++;
        if (w.example.isEmpty) noExample++;
      }
      // CET4 category: interpret/phonetic coverage >= 50%
      // M8：example 允许 RAW 管线带来的少量空壳（不再要求 0），阈值与释义同级。
      expect(
        noInterpret * 100 <= words.length * 50,
        true,
        reason: 'Interpret gap rate abnormal: $noInterpret/${words.length} (book=${cet4Book.code})',
      );
      expect(
        noPhonetic * 100 <= words.length * 50,
        true,
        reason: 'Phonetic gap rate abnormal: $noPhonetic/${words.length}',
      );
      expect(
        noExample * 100 <= words.length * 50,
        true,
        reason: 'Example gap rate abnormal: $noExample/${words.length} (book=${cet4Book.code})',
      );
    }, timeout: _kHeavyTimeout);

    test('getWord round-trip consistency', () async {
      final cet4Book = books.firstWhere((b) => b.code.toUpperCase().contains('CET4'), orElse: () => books.first);
      final words = await WordBookDatabase.instance.getWordsByBook(cet4Book.id, limit: 50);
      final probe = words.firstWhere((w) => w.interpret.trim().isNotEmpty, orElse: () => words.first);
      final got = await WordBookDatabase.instance.getWord(probe.word);
      expect(got, isNotNull);
      expect(got!.word.toLowerCase(), probe.word.toLowerCase());
      expect(got.interpret.trim(), probe.interpret.trim());
      if (probe.interpret.trim().isNotEmpty) {
        expect(got.interpretLines.isNotEmpty, true, reason: 'interpretLines should parse meaning rows');
        expect(
          got.ukPron.isNotEmpty || got.usPron.isNotEmpty,
          true,
          reason: 'Word with meaning should have at least one phonetic',
        );
      }
    });
  });

  group('Search', () {
    test('Prefix search available', () async {
      final books = await WordBookDatabase.instance.getBooks();
      final any = await WordBookDatabase.instance.getWordsByBook(books.first.id, limit: 1);
      final prefix = any.first.word.substring(0, 1);
      final hits = await WordBookDatabase.instance.searchWords(prefix);
      expect(hits.isNotEmpty, true, reason: "Prefix search with '$prefix' should hit");
    });
  });
}
