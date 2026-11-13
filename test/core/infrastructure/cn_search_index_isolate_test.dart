// P2-11（架构审计 2026-11-12）：CnSearchIndex 后台 isolate 构建路径专项测试。
//
// 与 cn_search_index_test（注入内存索引库、走主 isolate 回退路径）互补：本文件用
// **生产路径**（无 openIndexDatabase 注入），让构建整体进后台 isolate——isolate 自开
// 只读词库与 staging 索引库（桌面 FFI），验证「读/建对/排序/插入/写指纹」全后台可用，
// 且查询结果与全表 LIKE 严格一致。
//
// ⚠️ 本测试在桌面（Windows/Linux FFI）验证 isolate 开库；Android 原生 sqflite 后台
// isolate 开库尚未真机验证，生产以「失败回退主 isolate 分块路径」兜底（最坏 == 现状）。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:word_app/core/infrastructure/cn_search_index.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Database wordsDb;
  late Directory tmpDir;
  late String wordsPath;
  late String indexPath;

  setUp(() async {
    databaseFactory = databaseFactoryFfi;
    tmpDir = await Directory.systemTemp.createTemp('cn_search_isolate_test');
    wordsPath = p.join(tmpDir.path, 'wordbook.db');
    indexPath = p.join(tmpDir.path, 'search_cn_index.db');
    wordsDb = await openDatabase(wordsPath);
    await wordsDb.execute('CREATE TABLE words (id INTEGER PRIMARY KEY, word TEXT NOT NULL, interpret TEXT NOT NULL)');
    await wordsDb.insert('words', {'id': 1, 'word': 'apple', 'interpret': 'n. 苹果;水果'});
    await wordsDb.insert('words', {'id': 2, 'word': 'pineapple', 'interpret': 'n. 菠萝'});
    await wordsDb.insert('words', {'id': 3, 'word': 'exam', 'interpret': 'n. 考试;检查'});
    await wordsDb.insert('words', {'id': 4, 'word': 'computer', 'interpret': 'n. 电脑;计算机.计'});
    await wordsDb.insert('words', {'id': 5, 'word': 'vitamin', 'interpret': 'n. 维生素(维他命)'});
    await wordsDb.insert('words', {'id': 6, 'word': '考试', 'interpret': '中文词本身也可命中'});
    await wordsDb.insert('words', {'id': 7, 'word': 'step_by_step', 'interpret': '一步一步来，人人人人有责'});
  });

  tearDown(() async {
    await wordsDb.close();
    try {
      tmpDir.deleteSync(recursive: true);
    } catch (_) {
      // Windows 句柄释放有时序延迟，残留临时目录无碍
    }
  });

  test('生产路径：后台 isolate 构建就绪，中文查询命中且与全表一致', () async {
    final index = CnSearchIndex(); // 无注入 → 生产路径 → isolate 构建
    addTearDown(index.close);

    await index.ensureBuilt(wordsDb: wordsDb, wordsPath: wordsPath, indexPath: indexPath);
    expect(index.isReady, isTrue, reason: 'isolate 构建应成功就绪（桌面 FFI）');

    final hit = await index.searchByInterpret(wordsDb: wordsDb, query: '苹果', escapedQuery: '苹果', limit: 10);
    expect(hit, isNotNull, reason: '就绪后中文查询应走索引而非回退');
    expect(hit!.map((r) => r['word']), contains('apple'));

    // 叠词查询（P2-1 去重契约）：isolate 构建的索引同样命中
    final redup = await index.searchByInterpret(wordsDb: wordsDb, query: '一步一步', escapedQuery: '一步一步', limit: 10);
    expect(redup, isNotNull);
    expect(redup!.map((r) => r['word']), contains('step_by_step'));
  });

  test('生产路径：纯 ASCII 查询回退 null（无相邻二元组）', () async {
    final index = CnSearchIndex();
    addTearDown(index.close);
    await index.ensureBuilt(wordsDb: wordsDb, wordsPath: wordsPath, indexPath: indexPath);
    expect(index.isReady, isTrue);

    final ascii = await index.searchByInterpret(wordsDb: wordsDb, query: 'apple', escapedQuery: 'apple', limit: 10);
    expect(ascii, isNull, reason: '纯 ASCII 无相邻 CJK 对，回退全表');
  });

  test('生产路径：指纹一致二次 ensureBuilt 不重建（幂等）', () async {
    final index = CnSearchIndex();
    addTearDown(index.close);
    await index.ensureBuilt(wordsDb: wordsDb, wordsPath: wordsPath, indexPath: indexPath);
    expect(index.isReady, isTrue);

    // 再次 ensureBuilt：指纹未变，应直接就绪（不重复构建）
    await index.ensureBuilt(wordsDb: wordsDb, wordsPath: wordsPath, indexPath: indexPath);
    expect(index.isReady, isTrue);
    final hit = await index.searchByInterpret(wordsDb: wordsDb, query: '考试', escapedQuery: '考试', limit: 10);
    expect(hit, isNotNull);
    expect(hit!.map((r) => r['word']), contains('考试'));
  });
}
