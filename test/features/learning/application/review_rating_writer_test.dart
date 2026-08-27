import 'package:flutter_test/flutter_test.dart';
import 'package:word_app/engine/fsrs6_engine.dart';
import 'package:word_app/features/learning/application/review_rating_writer.dart';

void main() {
  group('ReviewRatingWriter', () {
    test('原样转发评分到注入的持久化动作', () async {
      String? capturedWord;
      FsrsRating? capturedRating;
      final writer = ReviewRatingWriter(
        writeRating: ({required word, required rating}) async {
          capturedWord = word;
          capturedRating = rating;
        },
      );

      await writer.rate(word: 'reviewed', rating: FsrsRating.good);

      expect(capturedWord, 'reviewed');
      expect(capturedRating, FsrsRating.good);
    });

    test('透传底层持久化失败，不伪造成功结果', () async {
      final writer = ReviewRatingWriter(
        writeRating: ({required word, required rating}) => Future<void>.error(StateError('write failed')),
      );

      await expectLater(writer.rate(word: 'reviewed', rating: FsrsRating.again), throwsA(isA<StateError>()));
    });
  });
}
