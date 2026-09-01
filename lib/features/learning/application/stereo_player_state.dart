// 由 Claude 团队生成 | Monster Word App

// 随身听播放器状态：按所选词源构建播放列表，按播放顺序连播单词发音。
import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:word_app/core/audio/audio_service.dart';
import 'package:word_app/features/learning/application/play_order.dart';
import 'package:word_app/models/word.dart';

/// 随身听播放的词源。
enum StereoSource { todayLearned, reviewing, newWords, favorites }

/// 随身听播放器状态。
///
/// 职责：持有播放列表与播放进度，驱动「发音 → 间隔 → 下一词」的顺序连播。
/// 单词音频的获取与兜底（缓存 → 有道 → TTS）由 [AudioService] 负责；本状态
/// 只关心「当前播到哪个词、在播还是暂停」。
///
/// 竞态防护：会话序号 [session] 在每次用户命令（开始/暂停/上下词/停止）时自增，
/// 迟到的定时器或异步回放不会覆盖新命令的状态。
class StereoPlayerState extends ChangeNotifier {
  /// 单词音频播放服务。
  final AudioService audioService;

  StereoPlayerState({required this.audioService, this.interval = const Duration(seconds: 4)});

  /// 每个词播放后的停留间隔（也是发音链路下载/播放的兜底推进时限）。
  final Duration interval;

  Timer? _timer;
  int session = 0;
  bool _disposed = false;

  List<Word> _playlist = const [];
  PlayOrder _order = PlayOrder.sequential;
  int _index = 0;
  bool _isPlaying = false;
  StereoSource? _source;

  List<Word> get playlist => _playlist;
  PlayOrder get order => _order;
  int get currentIndex => _index;
  bool get isPlaying => _isPlaying;
  StereoSource? get source => _source;
  bool get hasPlaylist => _playlist.isNotEmpty;

  /// 进度展示用：第几个词（从 1 起）。
  int get progressPosition => _playlist.isEmpty ? 0 : _index + 1;

  Word? get currentWord => _playlist.isEmpty ? null : _playlist[_index.clamp(0, _playlist.length - 1)];

  /// 开始播放一个词源。列表为空时只记录来源并保持停止态。
  void start({required StereoSource source, required List<Word> words}) {
    _invalidatePending();
    _source = source;
    _playlist = List.of(words);
    _applyOrderToPlaylist();
    _index = 0;
    if (_playlist.isEmpty) {
      _isPlaying = false;
      notifyListeners();
      return;
    }
    unawaited(_playCurrent(session));
  }

  /// 切换播放顺序；若正在播放，保持当前词继续，剩余列表按新顺序重排。
  void setOrder(PlayOrder order) {
    if (order == _order) return;
    _order = order;
    final current = currentWord;
    _applyOrderToPlaylist();
    if (current != null) {
      final newIndex = _playlist.indexWhere((w) => identical(w, current) || w.word == current.word);
      if (newIndex >= 0) _index = newIndex;
    }
    notifyListeners();
  }

  /// 暂停：停止当前发音并取消后续推进；再次播放从当前词重新开始。
  Future<void> pause() async {
    _invalidatePending();
    _isPlaying = false;
    notifyListeners();
    await _safeStopAudio();
  }

  /// 恢复：从当前词重新播放并继续连播。
  void resume() {
    if (_playlist.isEmpty || _isPlaying) return;
    unawaited(_playCurrent(session));
  }

  /// 下一词；末词时进入停止态。
  Future<void> next() async {
    if (_playlist.isEmpty) return;
    _invalidatePending();
    if (_index >= _playlist.length - 1) {
      _isPlaying = false;
      notifyListeners();
      await _safeStopAudio();
      return;
    }
    _index++;
    unawaited(_playCurrent(session));
  }

  /// 上一词；首词时从头重播当前词。
  Future<void> previous() async {
    if (_playlist.isEmpty) return;
    _invalidatePending();
    if (_index > 0) _index--;
    unawaited(_playCurrent(session));
  }

  /// 停止播放并清空会话（保留列表供查看进度）。
  Future<void> stop() async {
    _invalidatePending();
    _isPlaying = false;
    notifyListeners();
    await _safeStopAudio();
  }

  /// 按 [order] 重排播放列表（不改变 [_index] 语义，由调用方处理当前词定位）。
  void _applyOrderToPlaylist() {
    switch (_order) {
      case PlayOrder.sequential:
        break;
      case PlayOrder.reverse:
        _playlist = _playlist.reversed.toList();
      case PlayOrder.random:
        // 拷贝后 shuffle：初始列表可能为不可变常量；双次 shuffle 提升短列表随机性
        _playlist = _playlist.toList()
          ..shuffle()
          ..shuffle();
      case PlayOrder.alphabetical:
        _playlist = [..._playlist]..sort((a, b) => a.word.toLowerCase().compareTo(b.word.toLowerCase()));
    }
  }

  Future<void> _playCurrent(int session) async {
    _isPlaying = true;
    notifyListeners();
    final word = currentWord;
    if (word == null) return;
    try {
      await audioService.playWordAudio(word.word);
    } catch (error) {
      debugPrint('[StereoPlayer] playWordAudio failed: $error');
    }
    if (_disposed || session != this.session || !_isPlaying) return;
    _timer = Timer(interval, () => _advance(session));
  }

  void _advance(int session) {
    if (_disposed || session != this.session || !_isPlaying) return;
    if (_index >= _playlist.length - 1) {
      _isPlaying = false;
      notifyListeners();
      return;
    }
    _index++;
    unawaited(_playCurrent(session));
  }

  /// 使未决的定时器与迟到异步回放全部失效。
  void _invalidatePending() {
    session++;
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _safeStopAudio() async {
    try {
      await audioService.stop();
    } catch (error) {
      debugPrint('[StereoPlayer] stop audio failed: $error');
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _timer = null;
    super.dispose();
  }
}
