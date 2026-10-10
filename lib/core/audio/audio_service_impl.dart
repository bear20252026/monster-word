// AudioServiceImpl — 音频播放服务实现

import 'package:word_app/core/utils/debug_log.dart';
import 'package:word_app/core/utils/swallowed_error_report.dart';

import 'dart:async';

import 'package:word_app/core/audio/audio_players.dart';
import 'package:word_app/core/audio/audio_service.dart';
import 'package:word_app/core/audio/system_tts.dart';

/// 音频播放服务实现
///
/// 通过 audio_players 工具类实现具体的音频播放功能。
/// UI 层只依赖 AudioService 接口，不感知底层实现。
///
/// 播放优先级：audioUrl > 音标音频(本地缓存→Youdao下载) > 系统 TTS 兜底。
class AudioServiceImpl implements AudioService {
  final MwAudioPlayer _bbPlayer = MwAudioPlayer();
  final PhoneticAudioPlayer _phoneticPlayer;
  final SentenceAudioPlayer _sentencePlayer;
  bool _disposed = false;

  AudioServiceImpl({PhoneticAudioPlayer? phoneticPlayer, SentenceAudioPlayer? sentencePlayer})
    : _phoneticPlayer = phoneticPlayer ?? PhoneticAudioPlayer(),
      _sentencePlayer = sentencePlayer ?? SentenceAudioPlayer();

  @override
  Future<void> playWordAudio(String word, {String accent = 'us', String? audioUrl}) async {
    if (_disposed) return;
    try {
      // 优先使用第三方服务器提供的音频 URL
      if (audioUrl != null && audioUrl.isNotEmpty) {
        await playFromUrl(audioUrl);
      } else {
        // 回退到 Youdao 发音（内部含本地缓存；下载失败时会自行 TTS 兜底）
        await _phoneticPlayer.playAudio(word, isUK: accent == 'uk');
      }
    } catch (e) {
      debugLog('[AudioService] Failed to play word audio: $e');
      // 最终兜底：任何网络链路异常都落到系统 TTS，保证用户能听到发音
      if (!_disposed) await SystemTts().speakEnglish(word);
    }
  }

  @override
  Future<void> playFromUrl(String url) async {
    if (_disposed) return;
    try {
      // 使用 SentenceAudioPlayer 播放网络音频
      await _sentencePlayer.playAudio(url);
    } catch (e) {
      debugLog('[AudioService] Failed to play from URL: $e');
    }
  }

  @override
  Future<void> stop() async {
    if (_disposed) return;
    // MW-46：stop 必须覆盖真实发声的所有通道——原实现只 stop 从未参与
    // 播放的 _bbPlayer，正在响的音标/句子播放器完全不受控。
    try {
      await _phoneticPlayer.stop();
    } catch (e) {
      debugLog('[AudioService] phonetic stop error: ');
    }
    try {
      await _sentencePlayer.stop();
    } catch (e) {
      debugLog('[AudioService] sentence stop error: ');
    }
    try {
      await _bbPlayer.stop();
    } catch (e) {
      debugLog('[AudioService] bb stop error: ');
    }
    try {
      await SystemTts().stop();
    } catch (e) {
      debugLog('[AudioService] tts stop error: ');
    }
  }

  @override
  bool get isPlaying {
    if (_disposed) return false;
    // MW-46：任一真实通道在响即为 playing（原实现读 _bbPlayer 恒 false 语义）。
    return _phoneticPlayer.isPlaying() || _sentencePlayer.isPlaying() || _bbPlayer.isPlaying;
  }

  /// 释放所有音频资源（防止内存泄漏）
  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    // 与历史行为一致：主播放器同步标记释放；单例播放器异步 release（不 await、无 Timer）。
    try {
      _bbPlayer.release();
    } catch (e, s) {
      reportSwallowedError('主播放器同步释放失败', e, s);
    }
    unawaited(_safeRelease(() => PhoneticAudioPlayer().release()));
    unawaited(_safeRelease(() => SentenceAudioPlayer().release()));
    unawaited(_safeRelease(() => TextAudioPlayer().release()));
    debugLog('[AudioService] Disposed all audio resources');
  }

  Future<void> _safeRelease(Future<void> Function() op) async {
    try {
      await op();
    } catch (e, s) {
      // 单例播放器释放失败只降级（进程多在退出路径），但须可见。
      reportSwallowedError('单例播放器释放失败', e, s);
    }
  }
}
