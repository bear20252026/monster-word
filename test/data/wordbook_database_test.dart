import 'package:flutter_test/flutter_test.dart';
import 'package:word_app/core/infrastructure/wordbook_database.dart';

void main() {
  group('WordBookDatabase (XP-FIX-4)', () {
    test('instance 为真单例（重复访问同一实例）', () {
      expect(WordBookDatabase.instance, same(WordBookDatabase.instance));
    });

    test('isInitialized 与 db 可用性一致：未初始化时访问 db 必抛 StateError', () {
      final db = WordBookDatabase.instance;
      if (db.isInitialized) {
        // 已被同 isolate 其他用例初始化：getter 不抛即正确行为
        expect(() => db.db, returnsNormally);
      } else {
        expect(() => db.db, throwsA(isA<StateError>()), reason: 'isInitialized=false 时 db getter 必须显式失败，不能返回半开状态');
      }
    });
  });
}
