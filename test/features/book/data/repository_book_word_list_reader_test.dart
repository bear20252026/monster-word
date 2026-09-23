// MEM/F2：RepositoryBookWordListReader 分页查询（COUNT / LIMIT-OFFSET / 单列文本）
// 与全量加载的口径一致性测试。用 FFI 现做小而合法的三表词库压成 gz 作为资产替身
//（与 wordbook_database_concurrency_test 同款夹具），避免加载真实 35MB 资产。
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:word_app/core/infrastructure/wordbook_database.dart';
import 'package:word_app/features/book/data/repository_book_word_list_reader.dart';

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
  late Uint8List gzBytes;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    tmp = await Directory.systemTemp.createTemp('book_word_list_reader_test');
    PathProviderPlatform.instance = _FakePathProvider(tmp.path);
    await WordBookDatabase.ensurePlatform();

    // book 1 = 3 词（含大小写混合，验证 COLLATE NOCASE 排序）；book 2 = 1 词
    final src = await databaseFactory.openDatabase(p.join(tmp.path, 'src.db'));
    await src.execute('CREATE TABLE books (id INTEGER PRIMARY KEY, name TEXT, word_count INTEGER)');
    await src.execute(
      'CREATE TABLE words (id INTEGER PRIMARY KEY, word TEXT, interpret TEXT, uk_pron TEXT, '
      'us_pron TEXT, confuse TEXT, word_root TEXT, example TEXT, audio_urls TEXT, image_urls TEXT, phrase TEXT)',
    );
    await src.execute('CREATE TABLE word_books (word_id INTEGER, book_id INTEGER)');
    await src.insert('books', {'name': '测试书A', 'word_count': 3});
    await src.insert('books', {'name': '测试书B', 'word_count': 1});
    await src.insert('words', {'word': 'banana', 'interpret': '[]', 'example': 'long example payload'});
    await src.insert('words', {'word': 'apple', 'interpret': '[]', 'example': 'long example payload'});
    await src.insert('words', {'word': 'Cherry', 'interpret': '[]'});
    await src.insert('words', {'word': 'dog', 'interpret': '[]'});
    await src.insert('word_books', {'word_id': 1, 'book_id': 1});
    await src.insert('word_books', {'word_id': 2, 'book_id': 1});
    await src.insert('word_books', {'word_id': 3, 'book_id': 1});
    await src.insert('word_books', {'word_id': 4, 'book_id': 2});
    await src.close();
    final raw = await File(p.join(tmp.path, 'src.db')).readAsBytes();
    gzBytes = Uint8List.fromList(GZipEncoder().encode(raw)!);

    WordBookDatabase.gzBytesOverrideForTest = () => gzBytes;
  });

  tearDownAll(() async {
    WordBookDatabase.gzBytesOverrideForTest = null;
    try {
      await WordBookDatabase.instance.close();
    } catch (_) {}
    try {
      await tmp.delete(recursive: true);
    } catch (_) {}
  });

  setUp(() async {
    // 单例状态复位：close 清空 _initialized 与互斥屏障
    await WordBookDatabase.instance.close();
    await WordBookDatabase.instance.initialize();
  });

  group('RepositoryBookWordListReader（MEM/F2 分页）', () {
    late RepositoryBookWordListReader reader;

    setUp(() {
      reader = RepositoryBookWordListReader(database: WordBookDatabase.instance);
    });

    test('countWords 返回 SQL 总数，与全量加载长度一致', () async {
      expect(await reader.countWords(1), 3);
      expect(await reader.countWords(2), 1);
      expect(await reader.countWords(999), 0);
      expect(await reader.countWords(1), (await reader.loadWords(1)).length);
    });

    test('loadWordPage 按字母序（大小写不敏感）切片，不越界', () async {
      final page0 = await reader.loadWordPage(1, offset: 0, limit: 2);
      expect(page0.map((w) => w.word).toList(), ['apple', 'banana']);

      final page1 = await reader.loadWordPage(1, offset: 2, limit: 2);
      expect(page1.map((w) => w.word).toList(), ['Cherry']);

      final beyond = await reader.loadWordPage(1, offset: 3, limit: 2);
      expect(beyond, isEmpty);
    });

    test('loadWordPage 为 lightweight 列：不含 example 大字段', () async {
      final page = await reader.loadWordPage(1, offset: 0, limit: 10);
      expect(page.map((w) => w.word), contains('banana'));
      expect(
        page.firstWhere((w) => w.word == 'banana').example,
        isEmpty,
        reason: 'lightweight 模式不查 example（省 ~95% 内存）',
      );
    });

    test('loadWordTexts 返回单列 A-Z 文本，与全量词序一致', () async {
      final texts = await reader.loadWordTexts(1);
      expect(texts, ['apple', 'banana', 'Cherry']);
      expect(texts, (await reader.loadWords(1)).map((w) => w.word).toList());
    });

    test('分页拼接 == 全量加载（口径一致性）', () async {
      final full = await reader.loadWords(1);
      final paged = <String>[];
      for (var offset = 0; offset < full.length; offset += 2) {
        final page = await reader.loadWordPage(1, offset: offset, limit: 2);
        paged.addAll(page.map((w) => w.word));
      }
      expect(paged, full.map((w) => w.word).toList());
    });
  });
}
