import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:word_app/features/learning/application/review_audio_player.dart';
import 'package:word_app/features/learning/presentation/review_audio_state.dart';

void main() {
  group('ReviewAudioState', () {
    test('播放期间保留加载词并忽略并发播放请求', () async {
      final completion = Completer<void>();
      final requestedWords = <String>[];
      final state = ReviewAudioState(
        audioPlayer: ReviewAudioPlayer(
          playAudio: (word) {
            requestedWords.add(word);
            return completion.future;
          },
        ),
      );

      final firstPlay = state.playWord('first');
      expect(state.isLoading, isTrue);
      expect(state.isLoadingWord('first'), isTrue);

      await state.playWord('second');
      expect(requestedWords, ['first']);
      expect(state.isLoadingWord('second'), isFalse);

      completion.complete();
      await firstPlay;
      expect(state.isLoading, isFalse);
      expect(state.isLoadingWord('first'), isFalse);
    });

    test('播放失败后清除加载状态并将错误交给页面协调层', () async {
      final state = ReviewAudioState(
        audioPlayer: ReviewAudioPlayer(playAudio: (_) => Future<void>.error(StateError('audio unavailable'))),
      );

      await expectLater(state.playWord('first'), throwsA(isA<StateError>()));
      expect(state.isLoading, isFalse);
    });
  });
}
