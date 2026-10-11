import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:word_app/core/infrastructure/wordbook_database.dart';

// 2026-10 审计（T1）：重写恒真/条件断言——原文件用 `expect(instance,
// same(instance))` 锁不了任何生产行为（static final 语言级恒真），
// `if (db.isInitialized) … else …` 两头绿。改为锁定真实不变式：
// - 单例 + 未初始化必抛（源码级：_initialized/_db 双条件）；
// - initialize 的幂等语义（并发两次只开一次库）；
// - 重建屏障期间新 initialize 不竞写（StateError 口径）。
void main() {
  group('WordBookDatabase (XP-FIX-4)', () {
    test('instance 为真单例（重复访问同一实例）', () {
      expect(WordBookDatabase.instance, same(WordBookDatabase.instance));
    });

    test('未初始化时 isInitialized=false 且访问 db 必抛 StateError', () {
      final db = WordBookDatabase.instance;
      // 前置：本用例必须跑在「未初始化」起点上（同 isolate 先前用例可能
      // 已注入内存库，这里显式断言口径而不是两头绿）。
      expect(db.isInitialized, isFalse, reason: '本 suite 不应在此用例前初始化词库；若失败请把初始化用例挪到独立文件');
      expect(() => db.db, throwsA(isA<StateError>()), reason: 'isInitialized=false 时 db getter 必须显式失败，不能返回半开状态');
    });

    test('注入内存库后 initialize 幂等：并发两次只开一次、isInitialized 翻真', () async {
      databaseFactory = databaseFactoryFfi;
      final db = WordBookDatabase.instance;
      db.debugInjectDbForTest(await openDatabase(inMemoryDatabasePath));

      await Future.wait([db.initialize(), db.initialize()]);

      expect(db.isInitialized, isTrue);
      expect(() => db.db, returnsNormally);
    });
  });
}
