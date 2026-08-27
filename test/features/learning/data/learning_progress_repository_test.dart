import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:word_app/features/learning/data/learning_progress_repository.dart';
import 'package:word_app/models/book.dart';
import 'package:word_app/models/word.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('保存并恢复既有学习进度键和值结构', () async {
    final repository = LearningProgressRepository();
    final book = Book(id: 42, code: 'CET4', name: '四级', wordCount: 2);

    await repository.save(
      currentBook: book,
      currentIndex: 1,
      queue: [
        Word(id: 7, word: 'first'),
        Word(id: 8, word: 'second'),
      ],
    );

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(LearningProgressRepository.currentBookPrefKey), '42');
    expect(prefs.getInt(LearningProgressRepository.currentIndexPrefKey), 1);
    expect(jsonDecode(prefs.getString(LearningProgressRepository.queueSnapshotPrefKey)!), [7, 8]);

    final restored = await repository.load();
    expect(restored?.bookId, '42');
    expect(restored?.currentIndex, 1);
    expect(restored?.queueWordIds, [7, 8]);
  });

  test('没有当前词书时不覆盖既有学习进度', () async {
    SharedPreferences.setMockInitialValues({
      LearningProgressRepository.currentBookPrefKey: '42',
      LearningProgressRepository.currentIndexPrefKey: 3,
      LearningProgressRepository.queueSnapshotPrefKey: '[7,8]',
    });
    final repository = LearningProgressRepository();

    await repository.save(currentBook: null, currentIndex: 0, queue: const []);

    final restored = await repository.load();
    expect(restored?.bookId, '42');
    expect(restored?.currentIndex, 3);
    expect(restored?.queueWordIds, [7, 8]);
  });
}
