// A6（v2.7.42）：WordBookDatabase.initialize 并发互斥守卫。
//
// 修复前（复审 A6/M7）：initialize() 的早退检查（if (_initialized) return）
// 与置位之间隔着解压/开库/自检多个 await，并发调用会各自执行一遍 35MB gz
// 慢路径并竞写同一 db 文件；forceRebuild 进行中混入的 initialize 也不受
// _rebuilding 保护。
// 修复后：Completer 互斥屏障——进行中的初始化/重建被后续调用共享同一 Future；
// 失败释放屏障允许重试；close() 清屏障允许重新初始化。
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:word_app/core/infrastructure/wordbook_database.dart';

/// Use temp directory to replace system app dir（与 data_verification_test 同款夹具）
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
  var loadCalls = 0;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    tmp = await Directory.systemTemp.createTemp('wordbook_concurrency_test');
    PathProviderPlatform.instance = _FakePathProvider(tmp.path);
    await WordBookDatabase.ensurePlatform();

    // 用 FFI 现做一个小而合法的三表词库（books/words/word_books 各 1 行），
    // 压成 gz 作为资产替身——避免加载真实 35MB 资产拖慢测试。
    final src = await databaseFactory.openDatabase(p.join(tmp.path, 'src.db'));
    await src.execute('CREATE TABLE books (id INTEGER PRIMARY KEY, name TEXT, word_count INTEGER)');
    await src.execute(
      'CREATE TABLE words (id INTEGER PRIMARY KEY, word TEXT, interpret TEXT, uk_pron TEXT, '
      'us_pron TEXT, confuse TEXT, word_root TEXT, example TEXT, audio_urls TEXT, image_urls TEXT, phrase TEXT)',
    );
    await src.execute('CREATE TABLE word_books (word_id INTEGER, book_id INTEGER)');
    await src.insert('books', {'name': '测试书', 'word_count': 1});
    await src.insert('words', {'word': 'hello', 'interpret': '[]'});
    await src.insert('word_books', {'word_id': 1, 'book_id': 1});
    await src.close();
    final raw = await File(p.join(tmp.path, 'src.db')).readAsBytes();
    gzBytes = Uint8List.fromList(GZipEncoder().encode(raw)!);

    WordBookDatabase.gzBytesOverrideForTest = () {
      loadCalls++;
      return gzBytes;
    };
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
  });

  group('A6: initialize 并发互斥', () {
    test('并发三次 initialize 共享同一次初始化（资产只加载一次）', () async {
      loadCalls = 0;
      await Future.wait([
        WordBookDatabase.instance.initialize(),
        WordBookDatabase.instance.initialize(),
        WordBookDatabase.instance.initialize(),
      ]);
      expect(WordBookDatabase.instance.isInitialized, isTrue);
      expect(loadCalls, 1, reason: '并发调用必须共享同一次慢路径，不得重复加载/解压资产');
      // 三个调用方等到的都是可用数据库
      final books = await WordBookDatabase.instance.getBooks();
      expect(books, isNotEmpty);
    });

    test('初始化完成后重复调用快速返回，不再触发资产加载', () async {
      loadCalls = 0;
      await WordBookDatabase.instance.initialize();
      final before = loadCalls;
      await WordBookDatabase.instance.initialize();
      await WordBookDatabase.instance.initialize();
      expect(loadCalls, before, reason: '已初始化后必须走早退检查');
    });

    test('初始化失败释放互斥屏障，允许重试成功', () async {
      var failNext = true;
      WordBookDatabase.gzBytesOverrideForTest = () {
        loadCalls++;
        if (failNext) throw StateError('模拟资产加载失败');
        return gzBytes;
      };
      // 首次：资产加载抛错 → initialize 整体失败
      await expectLater(WordBookDatabase.instance.initialize(), throwsStateError);
      expect(WordBookDatabase.instance.isInitialized, isFalse);
      // 重试：不再抛错 → 成功（屏障已释放，新的一次初始化真正执行）
      failNext = false;
      await WordBookDatabase.instance.initialize();
      expect(WordBookDatabase.instance.isInitialized, isTrue);
      final books = await WordBookDatabase.instance.getBooks();
      expect(books, isNotEmpty);
    });
  });
}
