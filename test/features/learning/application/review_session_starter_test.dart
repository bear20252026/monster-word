import 'package:flutter_test/flutter_test.dart';
import 'package:word_app/features/learning/application/review_queue_reader.dart';
import 'package:word_app/features/learning/application/review_session_starter.dart';

void main() {
  group('ReviewSessionStarter', () {
    test('将页面提供的队列快照转发给会话初始化命令', () async {
      const snapshot = ReviewQueueSnapshot(dueWords: [], queueWords: []);
      ReviewQueueSnapshot? receivedSnapshot;
      final starter = ReviewSessionStarter(
        snapshot: snapshot,
        initialize: (value) async {
          receivedSnapshot = value;
        },
      );

      final result = await starter.start();

      expect(result, ReviewSessionStartResult.ready);
      expect(identical(receivedSnapshot, snapshot), isTrue);
    });

    test('初始化失败时返回失败结果而不将会话已保存的错误再次抛给页面', () async {
      const snapshot = ReviewQueueSnapshot(dueWords: [], queueWords: []);
      final starter = ReviewSessionStarter(
        snapshot: snapshot,
        initialize: (_) => Future<void>.error(StateError('review source unavailable')),
      );

      final result = await starter.start();

      expect(result, ReviewSessionStartResult.failed);
    });
  });
}
