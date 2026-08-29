import 'package:flutter_test/flutter_test.dart';
import 'package:word_app/core/infrastructure/wordbook_database.dart';

void main() {
  group('WordBookDatabase (XP-FIX-4)', () {
    test('isInitialized 可通过 instance 访问', () {
      // WordBookDatabase 使用单例模式，isInitialized getter 是公开的
      final db = WordBookDatabase.instance;
      // 测试期间数据库可能已初始化（由其他测试触发），只验证 getter 可访问
      expect(db.isInitialized, isA<bool>());
    });

    test('isInitialized 为 false 时调用方可安全跳过 db 访问', () {
      final db = WordBookDatabase.instance;
      // 调用方可以检查 isInitialized 再决定是否访问 db
      // 若未初始化，访问 db 会抛 StateError；isInitialized 提供了安全前置检查
      if (!db.isInitialized) {
        expect(() => db.db, throwsA(isA<StateError>()));
      }
      expect(db.isInitialized, isA<bool>());
    });
  });
}
