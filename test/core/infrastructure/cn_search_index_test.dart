// P0-1（I12 收尾）：CnSearchIndex 测试。
// 核心契约：索引路径结果与第 3 层全表 LIKE **严格一致**（超集预筛 + 候选集
// 原语义验证）；未就绪/无相邻二元组/指纹失效回退 null（调用方走全表，双轨）。
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
  final indices = <CnSearchIndex>[];

  CnSearchIndex makeIndex() {
    final index = CnSearchIndex();
    indices.add(index);
    return index;
  }

  setUp(() async {
    databaseFactory = databaseFactoryFfi;
    tmpDir = await Directory.systemTemp.createTemp('cn_search_idx_test');
    wordsPath = p.join(tmpDir.path, 'wordbook.db');
    indexPath = p.join(tmpDir.path, 'search_cn_index.db');
    wordsDb = await openDatabase(wordsPath);
    await wordsDb.execute('CREATE TABLE words (id INTEGER PRIMARY KEY, word TEXT NOT NULL, interpret TEXT NOT NULL)');
    await wordsDb.insert('words', {'id': 1, 'word': 'apple', 'interpret': 'n. 苹果;水果'});
    await wordsDb.insert('words', {'id': 2, 'word': 'pineapple', 'interpret': 'n. 菠萝'});
    await wordsDb.insert('words', {'id': 3, 'word': 'exam', 'interpret': 'n. 考试;检查'});
    await wordsDb.insert('words', {'id': 4, 'word': 'computer', 'interpret': 'n. 电脑;计算机.计'});
    await wordsDb.insert('words', {'id': 5, 'word': 'vitamin', 'interpret': 'n. 维生素(维他命)'});
    await wordsDb.insert('words', {'id': 6, 'word': 'pure_en', 'interpret': 'only english here'});
    await wordsDb.insert('words', {'id': 7, 'word': '考试', 'interpret': '中文词本身也可命中'});
    // P2-1 回归词行：叠词串在 interpret 中真实存在，保证叠词查询「非空」断言有靶
    await wordsDb.insert('words', {'id': 8, 'word': 'step_by_step', 'interpret': '一步一步来，人人人人有责'});
    await wordsDb.insert('words', {'id': 9, 'word': '渐进步骤', 'interpret': '一步一个脚印，一步一步走'});
    await wordsDb.insert('words', {'id': 10, 'word': 'study', 'interpret': '反复研究研究才能掌握'});
  });

  tearDown(() async {
    for (final index in indices) {
      await index.close();
    }
    indices.clear();
    await wordsDb.close();
    try {
      tmpDir.deleteSync(recursive: true);
    } catch (_) {
      // Windows 句柄释放有时序延迟，残留临时目录无碍
    }
  });

  /// 旧第 3 层全表 LIKE 快照（word/interpret 中缀 + CASE 0/1/2 排序）。
  Future<List<String>> legacyLike(Database db, String q, int cap) async {
    final like = '%$q%';
    final maps = await db.rawQuery(
      '''
      SELECT word FROM words
      WHERE (word LIKE ? ESCAPE '\\' OR interpret LIKE ? ESCAPE '\\')
      ORDER BY
        CASE WHEN word = ? THEN 0 WHEN word LIKE ? ESCAPE '\\' THEN 1 ELSE 2 END,
        word COLLATE NOCASE,
        rowid
      LIMIT ?
    ''',
      [like, like, q, '$q%', cap],
    );
    return maps.map((m) => m['word'] as String).toList();
  }

  /// 索引路径 vs 全表快照的一致性断言（含 null 回退口径）。
  Future<void> expectConsistentWithFullScan(
    CnSearchIndex index,
    String q, {
    bool shouldUseIndex = true,
    int cap = 50,
  }) async {
    final maps = await index.searchByInterpret(wordsDb: wordsDb, query: q, escapedQuery: q, limit: cap);
    if (!shouldUseIndex) {
      expect(maps, isNull, reason: '查询 "$q" 应回退全表（不走索引）');
      return;
    }
    expect(maps, isNotNull, reason: '查询 "$q" 应走索引路径');
    final expected = await legacyLike(wordsDb, q, cap);
    expect(maps!.map((m) => m['word']), expected, reason: '查询 "$q" 结果序列与全表不一致');
  }

  group('CnSearchIndex（超集一致性契约）', () {
    test('构建后就绪；多组中文查询与全表 LIKE 严格一致', () async {
      final index = makeIndex();
      await index.ensureBuilt(wordsDb: wordsDb, wordsPath: wordsPath, indexPath: indexPath);
      expect(index.isReady, isTrue);

      // 单字查询（'果'）无相邻对、一律回退全表，见「双轨回退」组
      for (final q in ['苹果', '考试', '电脑', '计算机', '维他命', '生素', '中文词', '不存在']) {
        await expectConsistentWithFullScan(index, q);
      }
    });

    test('word 精确命中 CASE 0 位次在索引路径下保持（中文 word 行第一）', () async {
      final index = makeIndex();
      await index.ensureBuilt(wordsDb: wordsDb, wordsPath: wordsPath, indexPath: indexPath);
      await expectConsistentWithFullScan(index, '考试');
      final maps = await index.searchByInterpret(wordsDb: wordsDb, query: '考试', escapedQuery: '考试', limit: 50);
      expect(maps!.first['word'], '考试', reason: 'word = 查询 的行 CASE 0 排首，与旧排序一致');
    });

    test('混合 ASCII 查询：有相邻对走索引且与全表一致，无相邻对回退', () async {
      final index = makeIndex();
      await index.ensureBuilt(wordsDb: wordsDb, wordsPath: wordsPath, indexPath: indexPath);

      // 超集性质对混合查询同样成立：'生素(' 的 LIKE 命中必含子串 '生素('，
      // 必含相邻对 '生素' → 预筛候选是命中的超集，验证后与全表严格一致
      for (final q in ['生素(', '他命', '苹果C']) {
        await expectConsistentWithFullScan(index, q);
      }
    });

    test('叠词查询（重复 bigram）：索引路径与全表一致且非空（P2-1 回归）', () async {
      final index = makeIndex();
      await index.ensureBuilt(wordsDb: wordsDb, wordsPath: wordsPath, indexPath: indexPath);

      // 叠词产生重复 bigram：建索引侧每词每 bigram 只存一行，查询侧不去重时
      // HAVING COUNT(DISTINCT bigram) = N 因 N 虚大恒假 → 索引路径静默返回空，
      // 与全表路径不一致。回归口径：走索引 + 非空 + 与全表序列严格一致。
      for (final q in ['人人人', '一步一步', '研究研究']) {
        await expectConsistentWithFullScan(index, q);
        // 防「双空互证」：一致性断言对空==空也会绿，显式要求索引路径非空
        final maps = await index.searchByInterpret(wordsDb: wordsDb, query: q, escapedQuery: q, limit: 50);
        expect(maps!, isNotEmpty, reason: '叠词查询 "$q" 必须命中词库中的目标行，不得漏配为空');
      }
    });
  });

  group('CnSearchIndex（双轨回退）', () {
    test('未就绪返回 null（首启构建窗口走全表）', () async {
      final index = makeIndex();
      final maps = await index.searchByInterpret(wordsDb: wordsDb, query: '苹果', escapedQuery: '苹果', limit: 50);
      expect(maps, isNull);
      expect(index.isReady, isFalse);
    });

    test('无相邻 CJK 对的查询返回 null（维C / 纯英文 / 单字 / 跨标点断开）', () async {
      final index = makeIndex();
      await index.ensureBuilt(wordsDb: wordsDb, wordsPath: wordsPath, indexPath: indexPath);

      // '维C'：维后是 ASCII，无对；'机.计'/'果;水'：标点打断 CJK 段，无对
      for (final q in ['维C', 'app', 'a', '果', '机.计', '果;水']) {
        await expectConsistentWithFullScan(index, q, shouldUseIndex: false);
      }
    });

    test('词库文件变化 → 指纹失效回退 null → 重新构建恢复', () async {
      final index = makeIndex();
      await index.ensureBuilt(wordsDb: wordsDb, wordsPath: wordsPath, indexPath: indexPath);
      expect(await index.searchByInterpret(wordsDb: wordsDb, query: '苹果', escapedQuery: '苹果', limit: 50), isNotNull);

      // 模拟词库解压重建/资产升级：mtime 变化即指纹失效
      File(wordsPath).setLastModifiedSync(DateTime.now().add(const Duration(hours: 1)));
      expect(
        await index.searchByInterpret(wordsDb: wordsDb, query: '苹果', escapedQuery: '苹果', limit: 50),
        isNull,
        reason: '索引内容不得超前于词库，指纹失效立即回退',
      );
      expect(index.isReady, isFalse);

      await index.ensureBuilt(wordsDb: wordsDb, wordsPath: wordsPath, indexPath: indexPath);
      expect(index.isReady, isTrue);
      expect(
        await index.searchByInterpret(wordsDb: wordsDb, query: '苹果', escapedQuery: '苹果', limit: 50),
        isNotNull,
        reason: '重建后恢复索引路径',
      );
    });
  });
}
