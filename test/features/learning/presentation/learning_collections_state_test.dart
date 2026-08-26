import 'package:flutter_test/flutter_test.dart';
import 'package:word_app/features/learning/presentation/learning_collections_state.dart';

void main() {
  group('LearningCollectionsSnapshot', () {
    test('空快照为展示页面提供安全的零值默认值', () {
      const snapshot = LearningCollectionsSnapshot.empty();

      expect(snapshot.favoriteCount, 0);
      expect(snapshot.masteredCount, 0);
    });

    test('集合快照保留收藏与掌握计数', () {
      const snapshot = LearningCollectionsSnapshot(favoriteCount: 12, masteredCount: 37);

      expect(snapshot.favoriteCount, 12);
      expect(snapshot.masteredCount, 37);
    });
  });
}
