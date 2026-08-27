import 'package:flutter_test/flutter_test.dart';
import 'package:word_app/features/learning/application/review_audio_player.dart';

void main() {
  test('正式复习音频端口将单词播放请求转发给已注入命令', () async {
    String? playedWord;
    final player = ReviewAudioPlayer(
      playAudio: (word) async {
        playedWord = word;
      },
    );

    await player.play('resilient');

    expect(playedWord, 'resilient');
  });
}
