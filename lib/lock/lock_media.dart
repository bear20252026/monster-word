// 由 Claude 团队生成 | 锁屏媒体播放管理
// 管理锁屏状态下的音频播放

import 'package:just_audio/just_audio.dart';
import 'package:flutter/foundation.dart';

/// 锁屏媒体播放管理器
/// 管理单词发音和例句音频的播放
class LockMedia {
  static final LockMedia _instance = LockMedia._();
  factory LockMedia() => _instance;
  LockMedia._();

  final AudioPlayer _wordPlayer = AudioPlayer();
  final AudioPlayer _sentencePlayer = AudioPlayer();
  bool _needPlay = false;

  /// 设置是否需要播放
  set needPlay(bool value) => _needPlay = value;

  /// 播放单词发音
  Future<void> playWord(String word) async {
    if (!_needPlay) return;
    try {
      // TODO: 从本地缓存或网络获取音频 URL
      final url = 'https://dict.youdao.com/dictvoice?audio=$word&type=2';
      await _wordPlayer.setUrl(url);
      await _wordPlayer.play();
    } catch (e) {
      debugPrint('LockMedia.playWord error: $e');
    }
  }

  /// 播放例句音频
  Future<void> playSentence(String mp3Path) async {
    if (!_needPlay) return;
    try {
      if (mp3Path.startsWith('http')) {
        await _sentencePlayer.setUrl(mp3Path);
      } else {
        await _sentencePlayer.setFilePath(mp3Path);
      }
      await _sentencePlayer.play();
    } catch (e) {
      debugPrint('LockMedia.playSentence error: $e');
    }
  }

  /// 暂停所有音频
  Future<void> pause() async {
    await _wordPlayer.pause();
    await _sentencePlayer.pause();
  }

  /// 停止所有音频
  Future<void> stop() async {
    await _wordPlayer.stop();
    await _sentencePlayer.stop();
  }

  /// 释放资源
  Future<void> dispose() async {
    await _wordPlayer.dispose();
    await _sentencePlayer.dispose();
  }
}
