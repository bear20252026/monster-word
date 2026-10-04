// 系统 TTS 引擎封装
// 使用设备内置语音合成，无需网络，支持中英双语
// 仅在移动端使用，桌面端回退到网络音频
import 'package:word_app/core/utils/debug_log.dart';
import 'package:word_app/core/utils/swallowed_error_report.dart';

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

  // 怪兽发声闸门用：系统引擎同一时刻只能说一句，单词/例句朗读正在跑时怪兽必须让路。
  bool _speaking = false;

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
        debugLog('[SystemTts] Speech started');
        _speaking = true;
        onStart?.call();
      });

      _tts.setCompletionHandler(() {
        debugLog('[SystemTts] Speech completed');
        _speaking = false;
        onComplete?.call();
      });

      _tts.setErrorHandler((msg) {
        debugLog('[SystemTts] Error: $msg');
        _speaking = false;
        onErrorHandler?.call();
      });

      if (!kIsWeb) {
        _tts.setCancelHandler(() {
          debugLog('[SystemTts] Speech cancelled');
          _speaking = false;
        });

        _tts.setPauseHandler(() {
          debugLog('[SystemTts] Speech paused');
        });

        _tts.setContinueHandler(() {
          debugLog('[SystemTts] Speech continued');
        });

        // Android/iOS 支持进度回调
        _tts.setProgressHandler((String text, int start, int end, String word) {
          onProgress?.call(word);
        });
      }

      _initialized = true;
      debugLog('[SystemTts] Initialized successfully');
    } catch (e) {
      debugLog('[SystemTts] Init error: $e');
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
    } catch (e, s) {
      // B 级豁免：朗读失败调用方各有降级（网络音频/静默），此处保底可见。
      debugLog('[SystemTts] speakEnglish error: $e');
      reportSwallowedError('系统 TTS 英语朗读失败', e, s);
      onErrorHandler?.call();
    }
  }

  /// 说中文。
  ///
  /// 失败会 rethrow：怪兽发声闸门（MonsterVoice）依赖该异常把设备标记为
  /// 「无中文语音」并降级回文案气泡——吞错会让降级路径成为死代码。
  Future<void> speakChinese(String text) async {
    await init();
    try {
      if (_lastLanguage != TtsLanguage.chinese) {
        await _tts.setLanguage('zh-CN');
        _lastLanguage = TtsLanguage.chinese;
      }
      await _tts.speak(text);
    } catch (e) {
      debugLog('[SystemTts] speakChinese error: $e');
      onErrorHandler?.call();
      rethrow;
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

      // 内存审计 P2：此前每次调用把 onComplete 包一层且从不还原，链长随
      // 调用次数线性增长（单例存活全程 = 永久累积，旧页面回调被钉住）。
      // 改为 try/finally 完成后恢复原回调。
      final completer = Completer<void>();
      final oldComplete = onComplete;
      onComplete = () {
        oldComplete?.call();
        if (!completer.isCompleted) completer.complete();
      };

      // 设置超时（防止 TTS 不触发 completion）
      final timeout = Timer(const Duration(seconds: 3), () {
        if (!completer.isCompleted) completer.complete();
      });

      try {
        await completer.future;
      } finally {
        timeout.cancel();
        // 内存审计 P2（2026-10-04 复审）：页面 dispose 会把回调槽清空以解绑
        // 已销毁 State——此刻不得把旧回调装回单例（钉住整页对象图直到下次
        // 赋值）。仅当槽位仍被占用（正常路径=本包装）时才恢复原回调。
        if (onComplete != null) onComplete = oldComplete;
      }

      // 短暂停顿后读中文
      await Future.delayed(const Duration(milliseconds: 300));
      if (_lastLanguage != TtsLanguage.chinese) {
        await _tts.setLanguage('zh-CN');
        _lastLanguage = TtsLanguage.chinese;
      }
      await _tts.speak(meaning);
    } catch (e) {
      debugLog('[SystemTts] speakWordWithMeaning error: $e');
    }
  }

  /// 停止播放
  Future<void> stop() async {
    try {
      await _tts.stop();
      _speaking = false; // 停止不一定触发 cancel/error 回调，忙标记必须自己清
    } catch (e) {
      debugLog('[SystemTts] stop error: $e');
    }
  }

  /// 暂停播放
  Future<void> pause() async {
    try {
      await _tts.pause();
    } catch (e) {
      debugLog('[SystemTts] pause error: $e');
    }
  }

  /// 设置语速 (0.0 - 1.0)
  Future<void> setRate(double rate) async {
    _speechRate = rate.clamp(0.1, 1.0);
    try {
      await _tts.setSpeechRate(_speechRate);
    } catch (e) {
      debugLog('[SystemTts] setRate error: $e');
    }
  }

  /// 设置音量 (0.0 - 1.0)
  Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0.0, 1.0);
    try {
      await _tts.setVolume(_volume);
    } catch (e) {
      debugLog('[SystemTts] setVolume error: $e');
    }
  }

  /// 设置音调 (0.5 - 2.0)
  Future<void> setPitch(double pitch) async {
    _pitch = pitch.clamp(0.5, 2.0);
    try {
      await _tts.setPitch(_pitch);
    } catch (e) {
      debugLog('[SystemTts] setPitch error: $e');
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
      // MEM/L4：单例持有 State 闭包会钉住页面，全部回调置空再 stop。
      onStart = null;
      onComplete = null;
      onErrorHandler = null;
      onProgress = null;
      await _tts.stop();
      _initialized = false;
    } catch (e) {
      debugLog('[SystemTts] dispose error: $e');
      _initialized = false;
    }
  }

  bool get initialized => _initialized;

  /// 系统引擎正在朗读中（单词/例句/怪兽台词共用同一引擎，一次只能说一句）。
  bool get isSpeaking => _speaking;

  /// 设备中文语音可用性：true 可用 / false 确认缺失 / null 无从判断（按可用先试一次）。
  ///
  /// 只探一次并缓存（含「平台不返回列表」的 null 结论——否则此类设备上
  /// 每场仪式都重敲一次 getLanguages）。
  Future<bool?> chineseVoiceAvailable() async {
    if (_chineseVoiceProbed) return _chineseVoiceAvailable;
    _chineseVoiceProbed = true;
    final langs = await getLanguages();
    final flat = langs.map((e) => '$e').join('|').toLowerCase();
    if (flat.isEmpty) return null; // 平台不返回列表：不下结论
    _chineseVoiceAvailable = flat.contains('zh');
    return _chineseVoiceAvailable;
  }

  /// 中文语音包探测结果：null=尚未探到，true=可用，false=确认缺失（缺失即静默降级回文案气泡）。
  bool? _chineseVoiceAvailable;
  bool _chineseVoiceProbed = false;

  /// 发声实际失败后标记不可用（本进程内不再打扰）。
  void markChineseVoiceUnavailable() => _chineseVoiceAvailable = false;
}

// 便捷函数
Future<void> speakEnglish(String text) => SystemTts().speakEnglish(text);
Future<void> speakChinese(String text) => SystemTts().speakChinese(text);
Future<void> stopTts() => SystemTts().stop();
