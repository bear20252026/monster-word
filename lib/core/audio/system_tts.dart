// 系统 TTS 引擎封装
// 使用设备内置语音合成，无需网络，支持中英双语
// 仅在移动端使用，桌面端回退到网络音频
import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

enum TtsLanguage { english, chinese }

class SystemTts {
  static final SystemTts _instance = SystemTts._();
  factory SystemTts() => _instance;
  SystemTts._();

  final FlutterTts _tts = FlutterTts();
  bool _initialized = false;
  double _speechRate = 0.5; // 0.0 - 1.0
  double _volume = 1.0;
  double _pitch = 1.0;
  TtsLanguage _lastLanguage = TtsLanguage.english;

  // 状态回调
  VoidCallback? onStart;
  VoidCallback? onComplete;
  VoidCallback? onErrorHandler;
  void Function(String)? onProgress;

  /// 初始化 TTS 引擎
  Future<void> init() async {
    if (_initialized) return;

    try {
      // 基本参数
      await _tts.setSpeechRate(_speechRate);
      await _tts.setVolume(_volume);
      await _tts.setPitch(_pitch);

      // 英语配置
      if (Platform.isAndroid) {
        await _tts.setLanguage('en-US');
      } else if (Platform.isIOS) {
        await _tts.setLanguage('en-US');
      } else {
        // Windows / macOS / Linux
        await _tts.setLanguage('en-US');
      }

      // 事件监听
      _tts.setStartHandler(() {
        debugPrint('[SystemTts] Speech started');
        onStart?.call();
      });

      _tts.setCompletionHandler(() {
        debugPrint('[SystemTts] Speech completed');
        onComplete?.call();
      });

      _tts.setErrorHandler((msg) {
        debugPrint('[SystemTts] Error: $msg');
        onErrorHandler?.call();
      });

      if (!kIsWeb) {
        _tts.setCancelHandler(() {
          debugPrint('[SystemTts] Speech cancelled');
        });

        _tts.setPauseHandler(() {
          debugPrint('[SystemTts] Speech paused');
        });

        _tts.setContinueHandler(() {
          debugPrint('[SystemTts] Speech continued');
        });

        // Android/iOS 支持进度回调
        _tts.setProgressHandler((String text, int start, int end, String word) {
          onProgress?.call(word);
        });
      }

      _initialized = true;
      debugPrint('[SystemTts] Initialized successfully');
    } catch (e) {
      debugPrint('[SystemTts] Init error: $e');
      _initialized = false;
    }
  }

  /// 说英语
  Future<void> speakEnglish(String text) async {
    await init();
    try {
      if (_lastLanguage != TtsLanguage.english) {
        await _tts.setLanguage('en-US');
        _lastLanguage = TtsLanguage.english;
      }
      await _tts.speak(text);
    } catch (e) {
      debugPrint('[SystemTts] speakEnglish error: $e');
      onErrorHandler?.call();
    }
  }

  /// 说中文
  Future<void> speakChinese(String text) async {
    await init();
    try {
      if (_lastLanguage != TtsLanguage.chinese) {
        await _tts.setLanguage('zh-CN');
        _lastLanguage = TtsLanguage.chinese;
      }
      await _tts.speak(text);
    } catch (e) {
      debugPrint('[SystemTts] speakChinese error: $e');
      onErrorHandler?.call();
    }
  }

  /// 说单词 + 释义（先英后中）
  Future<void> speakWordWithMeaning(String word, String meaning) async {
    await init();
    try {
      // 先读单词
      if (_lastLanguage != TtsLanguage.english) {
        await _tts.setLanguage('en-US');
        _lastLanguage = TtsLanguage.english;
      }
      await _tts.speak(word);

      // 等完成后读释义
      final completer = Completer<void>();
      VoidCallback? oldComplete;
      oldComplete = onComplete;
      onComplete = () {
        oldComplete?.call();
        if (!completer.isCompleted) completer.complete();
      };

      // 设置超时（防止 TTS 不触发 completion）
      Future.delayed(const Duration(seconds: 3), () {
        if (!completer.isCompleted) completer.complete();
      });

      await completer.future;

      // 短暂停顿后读中文
      await Future.delayed(const Duration(milliseconds: 300));
      if (_lastLanguage != TtsLanguage.chinese) {
        await _tts.setLanguage('zh-CN');
        _lastLanguage = TtsLanguage.chinese;
      }
      await _tts.speak(meaning);
    } catch (e) {
      debugPrint('[SystemTts] speakWordWithMeaning error: $e');
    }
  }

  /// 停止播放
  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (e) {
      debugPrint('[SystemTts] stop error: $e');
    }
  }

  /// 暂停播放
  Future<void> pause() async {
    try {
      await _tts.pause();
    } catch (e) {
      debugPrint('[SystemTts] pause error: $e');
    }
  }

  /// 设置语速 (0.0 - 1.0)
  Future<void> setRate(double rate) async {
    _speechRate = rate.clamp(0.1, 1.0);
    try {
      await _tts.setSpeechRate(_speechRate);
    } catch (e) {
      debugPrint('[SystemTts] setRate error: $e');
    }
  }

  /// 设置音量 (0.0 - 1.0)
  Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0.0, 1.0);
    try {
      await _tts.setVolume(_volume);
    } catch (e) {
      debugPrint('[SystemTts] setVolume error: $e');
    }
  }

  /// 设置音调 (0.5 - 2.0)
  Future<void> setPitch(double pitch) async {
    _pitch = pitch.clamp(0.5, 2.0);
    try {
      await _tts.setPitch(_pitch);
    } catch (e) {
      debugPrint('[SystemTts] setPitch error: $e');
    }
  }

  /// 获取可用语言列表
  Future<List<dynamic>> getLanguages() async {
    try {
      return await _tts.getLanguages ?? [];
    } catch (e) {
      return [];
    }
  }

  /// 获取可用语音列表
  Future<List<dynamic>> getVoices() async {
    try {
      return await _tts.getVoices ?? [];
    } catch (e) {
      return [];
    }
  }

  /// 释放资源
  Future<void> dispose() async {
    try {
      await _tts.stop();
      _initialized = false;
    } catch (e) {
      debugPrint('[SystemTts] dispose error: $e');
    }
  }

  bool get initialized => _initialized;
}

// 便捷函数
Future<void> speakEnglish(String text) => SystemTts().speakEnglish(text);
Future<void> speakChinese(String text) => SystemTts().speakChinese(text);
Future<void> stopTts() => SystemTts().stop();
