// 真库搜索基准（审计 I12 / I70）：旧单条全表 LIKE vs 新三层查询，
// 以及 P0-1 中文二元组索引 vs 全表（第 3 层）。
//
// 职责：
//   1. 一致性断言——新旧实现对同一查询集返回完全相同的 word 序列
//      （三层拆分依赖旧 ORDER BY CASE 的排序语义保证等价，见 word_repository_impl 注释；
//      索引路径依赖「子串命中 ⊇ 全部相邻二元组」的超集性质保证等价，见 cn_search_index 注释）。
//   2. P95 性能对比打印——不设性能阈值断言（CI 机性能噪声大），只报告数据。
//
// 真库：assets/db/wordbook.db.gz（241.8MB / words 32,154 词），
// 解压缓存到系统临时目录，二次运行免解压。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:word_app/core/infrastructure/cn_search_index.dart';
import 'package:word_app/core/infrastructure/wordbook_database.dart';
import 'package:word_app/core/repositories/word_repository_impl.dart';

const _queries = [
  // 英文主路径：精确 / 前缀 / 中缀混合
  'apple',
  'abandon',
  'the',
  'un',
  'pro',
  'a',
  'z',
  'qu',
  'xy',
  'ever',
  // 中文释义路径（第 3 层保底，预期不加速）
  '苹果',
  '考试',
  '电脑',
];

const _rounds = 3;

Future<File> _prepareDb() async {
  final out = File('${Directory.systemTemp.path}/wordbook_bench.db');
  if (out.existsSync() && out.lengthSync() > 100 * 1024 * 1024) return out;
  final gz = File('assets/db/wordbook.db.gz');
  final t0 = DateTime.now();
  final bytes = gzip.decode(gz.readAsBytesSync());
  out.writeAsBytesSync(bytes);
  stdout.writeln(
    '解压真库 ${out.path}（${bytes.length ~/ 1048576}MB，'
    '${DateTime.now().difference(t0).inMilliseconds}ms）',
  );
  return out;
}

/// 旧实现快照（2026-09-28 改造前的单条全表 LIKE），仅基准使用。
Future<List<String>> _legacySearch(Database db, String query, int limit) async {
  String escape(String input) => input.replaceAll(r'\', r'\\').replaceAll('%', r'\%').replaceAll('_', r'\_');
  final escaped = escape(query);
  final like = '%$escaped%';
  final maps = await db.rawQuery(
    '''
      SELECT * FROM words
      WHERE (word LIKE ? ESCAPE '\\' OR interpret LIKE ? ESCAPE '\\')
      ORDER BY
        CASE
          WHEN word = ? THEN 0
          WHEN word LIKE ? ESCAPE '\\' THEN 1
          ELSE 2
        END,
        word COLLATE NOCASE
      LIMIT ?
    ''',
    [like, like, query, '$escaped%', limit],
  );
  return maps.map((m) => m['word'] as String).toList();
}

Future<List<int>> _bench(Future<void> Function() run) async {
  final samples = <int>[];
  for (var i = 0; i < _rounds; i++) {
    final sw = Stopwatch()..start();
    await run();
    sw.stop();
    samples.add(sw.elapsedMilliseconds);
  }
  samples.sort();
  return samples;
}

void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('搜索三层化：新旧结果一致 + P95 对比', () async {
    final dbFile = await _prepareDb();
    final db = await databaseFactory.openDatabase(dbFile.path);
    final database = WordBookDatabase.instance;
    database.debugInjectDbForTest(db);
    final repo = WordRepositoryImpl(database);
    const cap = 50;

    final report = <String>[];
    final legacyAll = <int>[];
    final newAll = <int>[];
    var newWins = 0;
    for (final q in _queries) {
      final legacyWords = await _legacySearch(db, q, cap);
      final newWords = (await repo.searchWords(q, limit: cap)).map((w) => w.word).toList();

      // 一致性：分层拆分不允许改变返回序列
      expect(newWords, equals(legacyWords), reason: '查询 "$q"：三层化结果与旧实现不一致');

      final legacyMs = await _bench(() => _legacySearch(db, q, cap));
      final newMs = await _bench(() => repo.searchWords(q, limit: cap));
      legacyAll.addAll(legacyMs);
      newAll.addAll(newMs);
      final lAvg = legacyMs.reduce((a, b) => a + b) ~/ _rounds;
      final nAvg = newMs.reduce((a, b) => a + b) ~/ _rounds;
      if (nAvg < lAvg) newWins++;
      report.add(
        '$q — old ${legacyMs.join('/')}ms（均 ${lAvg}ms） | '
        'new ${newMs.join('/')}ms（均 ${nAvg}ms）',
      );
    }

    // P95（13 样本取次大，避免单点离群）
    int p95(List<int> all) {
      final s = [...all]..sort();
      return s[(s.length * 0.95).floor().clamp(0, s.length - 1)];
    }

    stdout.writeln('\n===== 搜索基准（words 真库，limit=$cap，$_rounds 轮）=====');
    stdout.writeln(report.join('\n'));
    stdout.writeln('P95：old ${p95(legacyAll)}ms / new ${p95(newAll)}ms');
    stdout.writeln('new 占优查询数：$newWins / ${_queries.length}');
    await db.close();
  }, timeout: const Timeout(Duration(minutes: 5)));

  test('P0-1 中文二元组索引：与全表一致 + 构建耗时 + P95 对比', () async {
    final dbFile = await _prepareDb();
    final db = await databaseFactory.openDatabase(dbFile.path);
    final database = WordBookDatabase.instance;
    database.debugInjectDbForTest(db);
    final index = CnSearchIndex();
    final indexPath = '${Directory.systemTemp.path}/wordbook_cn_idx_bench.db';

    final t0 = DateTime.now();
    await index.ensureBuilt(wordsDb: db, wordsPath: dbFile.path, indexPath: indexPath);
    final buildMs = DateTime.now().difference(t0).inMilliseconds;
    expect(index.isReady, isTrue, reason: '真库索引构建应成功');

    final indexSize = File(indexPath).lengthSync() ~/ 1048576;
    final repo = WordRepositoryImpl(database, cnSearchIndex: index);
    const cap = 50;
    const cnQueries = ['苹果', '考试', '电脑', '水果', '学习', '时间', '国家', '历史', '音乐', '经济'];

    final report = <String>[];
    final fullScanAll = <int>[];
    final indexedAll = <int>[];
    for (final q in cnQueries) {
      // 一致性：索引路径与第 3 层全表扫描不允许改变返回序列
      final legacyWords = await _legacySearch(db, q, cap);
      final indexedWords = (await repo.searchWords(q, limit: cap)).map((w) => w.word).toList();
      expect(indexedWords, equals(legacyWords), reason: '查询 "$q"：索引路径与全表扫描结果不一致');

      final fullScanMs = await _bench(() => _legacySearch(db, q, cap));
      final indexedMs = await _bench(() => repo.searchWords(q, limit: cap));
      fullScanAll.addAll(fullScanMs);
      indexedAll.addAll(indexedMs);
      report.add(
        '$q — 全表 ${fullScanMs.join('/')}ms（均 ${fullScanMs.reduce((a, b) => a + b) ~/ _rounds}ms） | '
        '索引 ${indexedMs.join('/')}ms（均 ${indexedMs.reduce((a, b) => a + b) ~/ _rounds}ms）',
      );
    }

    int p95(List<int> all) {
      final s = [...all]..sort();
      return s[(s.length * 0.95).floor().clamp(0, s.length - 1)];
    }

    stdout.writeln('\n===== 中文搜索索引基准（words 真库，limit=$cap，$_rounds 轮）=====');
    stdout.writeln('索引构建：${buildMs}ms（一次性，懒加载后台构建）；索引库 ${indexSize}MB');
    stdout.writeln(report.join('\n'));
    stdout.writeln('P95：全表 ${p95(fullScanAll)}ms / 索引 ${p95(indexedAll)}ms');
    await db.close();
  }, timeout: const Timeout(Duration(minutes: 10)));
}
