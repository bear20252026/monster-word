// 由 Claude 团队生成 | Monster Word App

// StereoPlayerState 回归测试：顺序重排、连播推进、竞态防护与暂停/停止。
import 'package:flutter_test/flutter_test.dart';

import 'package:word_app/core/audio/audio_service.dart';
import 'package:word_app/features/learning/application/play_order.dart';
import 'package:word_app/features/learning/application/stereo_player_state.dart';
import 'package:word_app/models/word.dart';

class _FakeAudioService implements AudioService {
  final List<String> played = [];
  int stopCount = 0;

  @override
  Future<void> playWordAudio(String word, {String accent = 'us', String? audioUrl}) async {
    played.add(word);
  }

  @override
  Future<void> playFromUrl(String url) async {}

  @override
  Future<void> stop() async {
    stopCount++;
  }

  @override
  bool get isPlaying => false;

  @override
  void dispose() {}
}

Word _word(String text) => Word(id: text.hashCode, word: text, interpret: '释义-$text');

void main() {
  test('start 按字母顺序重排播放列表', () {
    final audio = _FakeAudioService();
    final player = StereoPlayerState(audioService: audio)..setOrder(PlayOrder.alphabetical);
    addTearDown(player.dispose);

    player.start(source: StereoSource.todayLearned, words: ['pear', 'Apple', 'mango'].map(_word).toList());

    expect(player.playlist.map((w) => w.word).toList(), ['Apple', 'mango', 'pear']);
    expect(player.currentWord!.word, 'Apple');
    expect(player.isPlaying, isTrue);
  });

  test('start 逆序重排播放列表', () {
    final audio = _FakeAudioService();
    final player = StereoPlayerState(audioService: audio)..setOrder(PlayOrder.reverse);
    addTearDown(player.dispose);

    player.start(source: StereoSource.reviewing, words: ['a', 'b', 'c'].map(_word).toList());

    expect(player.playlist.map((w) => w.word).toList(), ['c', 'b', 'a']);
  });

  test('随机顺序保持同一批单词', () {
    final audio = _FakeAudioService();
    final player = StereoPlayerState(audioService: audio)..setOrder(PlayOrder.random);
    addTearDown(player.dispose);

    final words = List.generate(20, (i) => _word('w${i.toString().padLeft(2, '0')}'));
    player.start(source: StereoSource.newWords, words: words);

    expect(player.playlist.map((w) => w.word).toSet(), words.map((w) => w.word).toSet());
  });

  test('空词源只记录来源并保持停止态', () async {
    final audio = _FakeAudioService();
    final player = StereoPlayerState(audioService: audio);
    addTearDown(player.dispose);

    player.start(source: StereoSource.favorites, words: const []);
    await Future<void>.delayed(Duration.zero);

    expect(player.source, StereoSource.favorites);
    expect(player.isPlaying, isFalse);
    expect(audio.played, isEmpty);
  });

  test('next 到末词进入停止态；previous 回退重播', () async {
    final audio = _FakeAudioService();
    final player = StereoPlayerState(audioService: audio);
    addTearDown(player.dispose);

    player.start(source: StereoSource.todayLearned, words: ['a', 'b'].map(_word).toList());
    await Future<void>.delayed(Duration.zero);
    expect(player.progressPosition, 1);

    await player.next();
    expect(player.progressPosition, 2);
    expect(player.isPlaying, isTrue);

    await player.next();
    expect(player.isPlaying, isFalse);

    await player.previous();
    expect(player.progressPosition, 1); // 从末词回退到前一词
    expect(player.isPlaying, isTrue);
  });

  test('暂停停止发音，恢复从当前词重播', () async {
    final audio = _FakeAudioService();
    final player = StereoPlayerState(
      audioService: audio,
      interval: const Duration(hours: 1), // 阻止定时器推进
    );
    addTearDown(player.dispose);

    player.start(source: StereoSource.newWords, words: ['a', 'b'].map(_word).toList());
    await Future<void>.delayed(Duration.zero);

    await player.pause();
    expect(player.isPlaying, isFalse);
    final stopsAfterPause = audio.stopCount;
    expect(stopsAfterPause, greaterThanOrEqualTo(1));

    player.resume();
    await Future<void>.delayed(Duration.zero);
    expect(player.isPlaying, isTrue);
    expect(player.progressPosition, 1); // 仍在当前词
  });

  test('切换播放顺序时保持当前词继续', () {
    final audio = _FakeAudioService();
    final player = StereoPlayerState(audioService: audio);
    addTearDown(player.dispose);

    player.start(source: StereoSource.todayLearned, words: ['a', 'b', 'c'].map(_word).toList());
    player.next();

    player.setOrder(PlayOrder.reverse);

    expect(player.currentWord!.word, 'b');
    expect(player.progressPosition, 2);
  });

  test('stop 清空播放态', () async {
    final audio = _FakeAudioService();
    final player = StereoPlayerState(audioService: audio, interval: const Duration(hours: 1));
    addTearDown(player.dispose);

    player.start(source: StereoSource.reviewing, words: ['a'].map(_word).toList());
    await Future<void>.delayed(Duration.zero);
    expect(player.isPlaying, isTrue);

    await player.stop();
    expect(player.isPlaying, isFalse);
    expect(player.hasPlaylist, isTrue); // 列表保留供查看进度
  });
}
