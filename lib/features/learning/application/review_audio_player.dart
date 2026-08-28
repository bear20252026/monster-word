/// 正式复习的单词发音写入端口。
///
/// 正式复习展示状态只依赖该命令，而不感知全局音频服务的具体实现。
typedef ReviewAudioCommand = Future<void> Function(String word);

class ReviewAudioPlayer {
  const ReviewAudioPlayer({required this._playAudio});

  final ReviewAudioCommand _playAudio;

  Future<void> play(String word) => _playAudio(word);
}
