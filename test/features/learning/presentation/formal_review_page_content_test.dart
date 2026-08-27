import 'package:flutter_test/flutter_test.dart';
import 'package:word_app/features/learning/presentation/widgets/formal_review_page_content.dart';

void main() {
  group('formalReviewPagePhase', () {
    test('加载阶段优先于其他会话快照', () {
      final phase = formalReviewPagePhase(isLoading: true, hasLoadError: true, hasWord: true);

      expect(phase, FormalReviewPagePhase.loading);
    });

    test('失败阶段不会被误映射为完成或答题内容', () {
      final phase = formalReviewPagePhase(isLoading: false, hasLoadError: true, hasWord: false);

      expect(phase, FormalReviewPagePhase.failed);
    });

    test('就绪会话依据当前词区分完成与答题内容', () {
      expect(
        formalReviewPagePhase(isLoading: false, hasLoadError: false, hasWord: false),
        FormalReviewPagePhase.complete,
      );
      expect(
        formalReviewPagePhase(isLoading: false, hasLoadError: false, hasWord: true),
        FormalReviewPagePhase.reviewing,
      );
    });
  });
}
