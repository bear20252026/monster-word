import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:word_app/core/repositories/note_repository_impl.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NoteRepositoryImpl.countAllNotes（MEM/U5 计数缓存）', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({
        'notes_v1_1':
            '[{"id":1,"word_id":1,"word":"a","content":"x","created_at":"2026-01-01","updated_at":"2026-01-01"}]',
        'other_key': 'ignored',
      });
    });

    test('统计全部笔记键之和，忽略无关键', () async {
      final repo = NoteRepositoryImpl();
      expect(await repo.countAllNotes(), 1);
    });

    test('写入后计数失效重算（不返回陈旧缓存）', () async {
      final repo = NoteRepositoryImpl();
      expect(await repo.countAllNotes(), 1);

      await repo.addNote(2, '新笔记', word: 'b');
      expect(await repo.countAllNotes(), 2, reason: 'addNote 必须使计数缓存失效');

      final noteId = await repo.addNote(2, '再来一条', word: 'b');
      await repo.deleteNote(noteId);
      expect(await repo.countAllNotes(), 2, reason: 'deleteNote 同样失效重算');
    });

    test('键被外部移除后按键集变化重算', () async {
      final repo = NoteRepositoryImpl();
      expect(await repo.countAllNotes(), 1);

      // 模拟外部直改 SP（绕过仓储契约）：删除笔记键后必须重扫而不是用旧缓存
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('notes_v1_1');
      expect(await repo.countAllNotes(), 0);
    });
  });
}
