import 'package:flutter/foundation.dart';

import '../application/review_audio_player.dart';

/// 正式复习页的单词发音展示状态。
///
/// 该状态仅维护当前播放请求的加载标识，并委托 [ReviewAudioPlayer] 执行发音。
/// 失败会向页面抛出，由页面统一提供用户可见反馈。
class ReviewAudioState extends ChangeNotifier {
  ReviewAudioState({required ReviewAudioPlayer audioPlayer}) : _audioPlayer = audioPlayer;

  final ReviewAudioPlayer _audioPlayer;
  String? _loadingWord;

  bool get isLoading => _loadingWord != null;
  bool isLoadingWord(String word) => _loadingWord == word;

  Future<void> playWord(String word) async {
    if (word.isEmpty || _loadingWord != null) return;

    _loadingWord = word;
    notifyListeners();
    try {
      await _audioPlayer.play(word);
    } finally {
      _loadingWord = null;
      notifyListeners();
    }
  }
}
