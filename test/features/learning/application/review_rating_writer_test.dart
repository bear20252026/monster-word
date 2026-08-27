import 'package:flutter_test/flutter_test.dart';
import 'package:word_app/engine/fsrs6_engine.dart';
import 'package:word_app/features/learning/application/review_rating_writer.dart';

void main() {
  group('ReviewRatingWriter', () {
    test('原样转发评分到注入的持久化动作', () async {
      FsrsRating? captured;
      final writer = ReviewRatingWriter(
        writeRating: (rating) async {
          captured = rating;
        },
      );

      await writer.rate(FsrsRating.good);

      expect(captured, FsrsRating.good);
    });

    test('透传底层持久化失败，不伪造成功结果', () async {
      final writer = ReviewRatingWriter(writeRating: (_) => Future<void>.error(StateError('write failed')));

      await expectLater(writer.rate(FsrsRating.again), throwsA(isA<StateError>()));
    });
  });
}
