import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:word_app/core/audio/audio_playback_state.dart';
import 'package:word_app/core/audio/audio_service.dart';

void main() {
  test('播放器状态在播放完成后公开当前词和播放标识', () async {
    final audio = _FakeAudioService();
    final state = AudioPlaybackState(audioService: audio);

    await state.playWord('monster', audioUrl: 'https://audio.example/monster.mp3');

    expect(state.currentWord, 'monster');
    expect(state.isLoading, isFalse);
    expect(state.isPlaying, isTrue);
    expect(audio.requests, [('monster', 'https://audio.example/monster.mp3')]);
  });

  test('停止会使迟到的旧播放完成回调失效', () async {
    final audio = _FakeAudioService(blockNextPlay: true);
    final state = AudioPlaybackState(audioService: audio);

    final pendingPlay = state.playWord('delayed');
    await Future<void>.delayed(Duration.zero);
    expect(state.isLoading, isTrue);

    await state.stop();
    audio.completeBlockedPlay();
    await pendingPlay;

    expect(audio.stopCalls, 1);
    expect(state.isLoading, isFalse);
    expect(state.isPlaying, isFalse);
  });

  test('恢复播放保留最近一次外部音频地址', () async {
    final audio = _FakeAudioService();
    final state = AudioPlaybackState(audioService: audio);

    await state.playWord('resume', audioUrl: 'https://audio.example/resume.mp3');
    state.pause();
    await state.resume();

    expect(state.isPlaying, isTrue);
    expect(audio.requests, [
      ('resume', 'https://audio.example/resume.mp3'),
      ('resume', 'https://audio.example/resume.mp3'),
    ]);
  });
}

class _FakeAudioService implements AudioService {
  _FakeAudioService({this.blockNextPlay = false});

  bool blockNextPlay;
  final List<(String, String?)> requests = [];
  final Completer<void> _blockedPlay = Completer<void>();
  int stopCalls = 0;

  @override
  Future<void> playWordAudio(String word, {String accent = 'us', String? audioUrl}) async {
    requests.add((word, audioUrl));
    if (blockNextPlay) {
      blockNextPlay = false;
      await _blockedPlay.future;
    }
  }

  void completeBlockedPlay() {
    if (!_blockedPlay.isCompleted) _blockedPlay.complete();
  }

  @override
  Future<void> stop() async {
    stopCalls++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
