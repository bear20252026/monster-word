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

  // R2-14 回归：pause 必须真正下发到底层音频服务，而不是只改 UI 标识——
  // 此前实现只置 _isPlaying=false，界面显示「已暂停」而扬声器继续出声。
  test('暂停会真正下发到底层音频服务', () async {
    final audio = _FakeAudioService();
    final state = AudioPlaybackState(audioService: audio);

    await state.playWord('pause', audioUrl: 'https://audio.example/pause.mp3');
    expect(state.isPlaying, isTrue);

    state.pause();

    expect(audio.pauseCalls, 1, reason: '必须调用底层 pause，不能只改播放标识');
    expect(state.isPlaying, isFalse);
  });
}

class _FakeAudioService implements AudioService {
  _FakeAudioService({this.blockNextPlay = false});

  bool blockNextPlay;
  final List<(String, String?)> requests = [];
  final Completer<void> _blockedPlay = Completer<void>();
  int stopCalls = 0;
  int pauseCalls = 0;

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
  Future<void> pause() async {
    pauseCalls++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
