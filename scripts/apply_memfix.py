from pathlib import Path

root = Path(r"C:\Users\17296\WorkBuddy\2026-08-29-23-03-07\monster-word-wt-memfix")


def patch(path: str, pairs: list[tuple[str, str]] | None = None, replace_fn=None):
    p = root / path
    t = p.read_text(encoding="utf-8")
    o = t
    if pairs:
        for a, b in pairs:
            if a not in t:
                print("MISS", path, a[:60])
            t = t.replace(a, b, 1)
    if replace_fn:
        t = replace_fn(t)
    if t != o:
        p.write_text(t, encoding="utf-8")
        print("OK", path)
    else:
        print("NOCHANGE", path)


# ── L1/L2 audio players release ──
def audio_players(t: str) -> str:
    # PhoneticAudioPlayer: add release after factory ctor block
    if "void release() {\n    playStateListener = null;\n    _audioPlayer.release();\n  }" not in t:
        t = t.replace(
            """  final MwAudioPlayer _audioPlayer = MwAudioPlayer();
  PlayAudioListener? playStateListener;
  bool _isPronounceUK = false;""",
            """  final MwAudioPlayer _audioPlayer = MwAudioPlayer();
  PlayAudioListener? playStateListener;
  bool _isPronounceUK = false;

  /// MEM：释放内部播放器并清空监听（退出/销毁时由 AudioServiceImpl 调用）。
  Future<void> release() async {
    playStateListener = null;
    await _audioPlayer.release();
  }""",
            1,
        )
    # SentenceAudioPlayer
    if t.count("class SentenceAudioPlayer") == 1 and "class SentenceAudioPlayer" in t:
        # insert release after sentence player's final MwAudioPlayer line once near class
        idx = t.find("class SentenceAudioPlayer")
        nxt = t.find("class TextAudioPlayer", idx)
        block = t[idx:nxt]
        if "Future<void> release()" not in block:
            block2 = block.replace(
                "final MwAudioPlayer _audioPlayer = MwAudioPlayer();",
                """final MwAudioPlayer _audioPlayer = MwAudioPlayer();

  /// MEM：释放内部播放器并清空监听。
  Future<void> release() async {
    playStateListener = null;
    _sentenceListener = null;
    await _audioPlayer.release();
  }""",
                1,
            )
            t = t[:idx] + block2 + t[nxt:]
    # TextAudioPlayer
    idx = t.find("class TextAudioPlayer")
    if idx > 0:
        block = t[idx:]
        if "Future<void> release()" not in block[:800]:
            block2 = block.replace(
                "final MwAudioPlayer _audioPlayer = MwAudioPlayer();",
                """final MwAudioPlayer _audioPlayer = MwAudioPlayer();

  /// MEM：释放内部播放器并清空监听。
  Future<void> release() async {
    playStateListener = null;
    await _audioPlayer.release();
  }""",
                1,
            )
            t = t[:idx] + block2
    return t


patch("lib/core/audio/audio_players.dart", replace_fn=audio_players)

patch(
    "lib/core/audio/audio_service_impl.dart",
    [
        (
            """  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _bbPlayer.release();
    debugPrint('[AudioService] Disposed all audio resources');
  }""",
            """  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _bbPlayer.release();
    // MEM：释放静态单例播放器，避免 mpv/AudioPlayer 与订阅常驻。
    PhoneticAudioPlayer().release();
    SentenceAudioPlayer().release();
    TextAudioPlayer().release();
    debugPrint('[AudioService] Disposed all audio resources');
  }""",
        )
    ],
)

patch(
    "lib/core/audio/system_tts.dart",
    [
        (
            """  Future<void> dispose() async {
    try {
      await _tts.stop();
      _initialized = false;
    } catch (e) {
      debugPrint('[SystemTts] dispose error: $e');
    }
  }""",
            """  Future<void> dispose() async {
    try {
      onComplete = null;
      onErrorHandler = null;
      await _tts.stop();
      _initialized = false;
    } catch (e) {
      debugPrint('[SystemTts] dispose error: $e');
    }
  }""",
        )
    ],
)

patch(
    "lib/features/learning/presentation/listening_player_page.dart",
    [
        (
            """  void dispose() {
    _autoPlayTimer?.cancel();
    _tts.stop();
    super.dispose();
  }""",
            """  void dispose() {
    _autoPlayTimer?.cancel();
    // MEM：清空全局 SystemTts 回调，避免单例钉住本 State。
    _tts.onComplete = null;
    _tts.onErrorHandler = null;
    _tts.stop();
    super.dispose();
  }""",
        )
    ],
)

patch(
    "lib/app/service_locator.dart",
    [
        (
            """Future<void> disposeServiceLocator() async {
  if (sl.isRegistered<AudioService>()) {
    sl<AudioService>().dispose();
  }
  await sl.reset();
}""",
            """Future<void> disposeServiceLocator() async {
  if (sl.isRegistered<AudioService>()) {
    sl<AudioService>().dispose();
  }
  // MEM：TTS 静态单例随应用退出释放。
  try {
    await SystemTts().dispose();
  } catch (_) {}
  await sl.reset();
}""",
        )
    ],
)

# import SystemTts in service_locator if needed
p = root / "lib/app/service_locator.dart"
t = p.read_text(encoding="utf-8")
if "system_tts.dart" not in t:
    t = t.replace(
        "import 'package:word_app/core/audio/audio_service_impl.dart';",
        "import 'package:word_app/core/audio/audio_service_impl.dart';\nimport 'package:word_app/core/audio/system_tts.dart';",
    )
    if "system_tts.dart" not in t:
        t = t.replace(
            "import 'package:get_it/get_it.dart';",
            "import 'package:get_it/get_it.dart';\nimport 'package:word_app/core/audio/system_tts.dart';",
        )
    p.write_text(t, encoding="utf-8")
    print("OK service_locator import tts")

# app.dart lifecycle detached dispose
patch(
    "lib/app/app.dart",
    [
        (
            """  @override
  void didChangePlatformBrightness() {
    _syncSystemBrightness();
  }""",
            """  @override
  void didChangePlatformBrightness() {
    _syncSystemBrightness();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // MEM：进程 detach 时回收音频/TTS/DI（桌面关窗常见路径）。
    if (state == AppLifecycleState.detached) {
      unawaited(disposeServiceLocator());
    }
  }""",
        )
    ],
)
p = root / "lib/app/app.dart"
t = p.read_text(encoding="utf-8")
if "disposeServiceLocator" in t and "service_locator.dart" not in t:
    t = t.replace(
        "import 'package:flutter/material.dart';",
        "import 'dart:async';\n\nimport 'package:flutter/material.dart';\nimport 'package:word_app/app/service_locator.dart';",
        1,
    )
    p.write_text(t, encoding="utf-8")
    print("OK app.dart imports")
elif "disposeServiceLocator" in t and "dart:async" not in t.split("class ")[0]:
    t = t.replace("import 'package:flutter/material.dart';", "import 'dart:async';\n\nimport 'package:flutter/material.dart';", 1)
    p.write_text(t, encoding="utf-8")
    print("OK app.dart dart:async")

# L5 confetti
patch(
    "lib/widgets/confetti.dart",
    [
        (
            """  static void play() {
    getController().play();
  }""",
            """  static void play() {
    getController().play();
  }

  /// MEM：释放静态控制器（应用 detach 时调用）。
  static void dispose() {
    _controller?.dispose();
    _controller = null;
  }""",
        )
    ],
)

# F6 Word parse cache
def word_cache(t: str) -> str:
    t = t.replace(
        """  List<String> get interpretLines => cleanInterpret.split('\\n').where((l) => l.trim().isNotEmpty).toList();

  /// 第一行释义（用于列表显示，优先结构化释义）
  String get firstInterpretLine {
    if (hasStructuredDefinitions) {
      final defs = parsedDefinitions;
      if (defs.isNotEmpty) {
        final first = defs.first;
        return first.cnDef.isNotEmpty ? first.cnDef : first.enDef;
      }
    }
    final lines = interpretLines;
    return lines.isNotEmpty ? lines.first : '';
  }

  // === JSON 释义解析 ===
  List<Definition>? _cachedDefinitions;""",
        """  List<String>? _cachedInterpretLines;

  /// 解释按行拆分（带实例缓存，MEM：列表滚动勿反复 split/清理）
  List<String> get interpretLines =>
      _cachedInterpretLines ??= cleanInterpret.split('\\n').where((l) => l.trim().isNotEmpty).toList();

  String? _cachedFirstLine;

  /// 第一行释义（用于列表显示，优先结构化释义）
  String get firstInterpretLine {
    final cached = _cachedFirstLine;
    if (cached != null) return cached;
    String result;
    if (hasStructuredDefinitions) {
      final defs = parsedDefinitions;
      if (defs.isNotEmpty) {
        final first = defs.first;
        result = first.cnDef.isNotEmpty ? first.cnDef : first.enDef;
      } else {
        final lines = interpretLines;
        result = lines.isNotEmpty ? lines.first : '';
      }
    } else {
      final lines = interpretLines;
      result = lines.isNotEmpty ? lines.first : '';
    }
    return _cachedFirstLine = result;
  }

  // === JSON 释义解析 ===
  List<Definition>? _cachedDefinitions;
  bool? _cachedHasStructured;""",
    )
    t = t.replace(
        """  bool get hasStructuredDefinitions {
    try {
      final decoded = jsonDecode(interpret);
      return decoded is List && decoded.isNotEmpty;
    } catch (_) {
      // B 级豁免：词条/词库数据解析降级，损坏数据不影响主流程（不逐条上报防刷屏，REG-OBS-001）
      return false;
    }
  }""",
        """  bool get hasStructuredDefinitions {
    final cached = _cachedHasStructured;
    if (cached != null) return cached;
    try {
      final decoded = jsonDecode(interpret);
      return _cachedHasStructured = decoded is List && decoded.isNotEmpty;
    } catch (_) {
      // B 级豁免：词条/词库数据解析降级，损坏数据不影响主流程（不逐条上报防刷屏，REG-OBS-001）
      return _cachedHasStructured = false;
    }
  }""",
    )
    # also cache hasStructured when parsing definitions
    t = t.replace(
        "    _cachedDefinitions = result;\n    return result;",
        "    _cachedDefinitions = result;\n    _cachedHasStructured = result.isNotEmpty;\n    return result;",
    )
    return t


patch("lib/models/word.dart", replace_fn=word_cache)

# U1 message store cap
patch(
    "lib/features/account/application/message_store.dart",
    [
        (
            """    _messages = <MessageItem>[item, ..._messages];
    final prefs = await _prefs();""",
            """    _messages = <MessageItem>[item, ..._messages];
    // MEM：无界增长截断，仅保留最近 N 条。
    const maxMessages = 200;
    if (_messages.length > maxMessages) {
      _messages = _messages.take(maxMessages).toList();
    }
    final prefs = await _prefs();""",
        )
    ],
)

# U4 feedback cap
patch(
    "lib/features/account/application/feedback_archive.dart",
    [
        (
            """    final history = _decode(prefs.getString(_storageKey))..add(entry);
    await prefs.setString(_storageKey, jsonEncode(history.map((e) => e.toJson()).toList()));""",
            """    final history = _decode(prefs.getString(_storageKey))..add(entry);
    // MEM：本地反馈存档封顶，避免 SP 与内存无界增长。
    const maxEntries = 50;
    final trimmed = history.length > maxEntries ? history.sublist(history.length - maxEntries) : history;
    await prefs.setString(_storageKey, jsonEncode(trimmed.map((e) => e.toJson()).toList()));""",
        )
    ],
)

# C4 user_database mutex
patch(
    "lib/core/infrastructure/user_database.dart",
    [
        (
            """  Database? _db;
  bool _initialized = false;

  Database get db {""",
            """  Database? _db;
  bool _initialized = false;
  Completer<void>? _initCompleter;

  Database get db {""",
        ),
        (
            """  Future<void> initialize() async {
    if (_initialized) return;

    final dir = await getApplicationSupportDirectory();
    final dbPath = p.join(dir.path, 'user_data.db');

    _db = await openDatabase(dbPath, version: 2, onCreate: _onCreate, onUpgrade: _onUpgrade);
    _initialized = true;
  }""",
            """  Future<void> initialize() {
    if (_initialized) return Future.value();
    final inflight = _initCompleter;
    if (inflight != null) return inflight.future;
    final completer = Completer<void>();
    _initCompleter = completer;
    completer.future.ignore();
    _initializeInner().then(
      (_) => completer.complete(),
      onError: (Object e, StackTrace st) {
        if (identical(_initCompleter, completer)) _initCompleter = null;
        completer.completeError(e, st);
      },
    );
    return completer.future;
  }

  Future<void> _initializeInner() async {
    final dir = await getApplicationSupportDirectory();
    final dbPath = p.join(dir.path, 'user_data.db');

    _db = await openDatabase(dbPath, version: 2, onCreate: _onCreate, onUpgrade: _onUpgrade);
    _initialized = true;
  }""",
        ),
        (
            "import 'package:path/path.dart' as p;",
            "import 'dart:async';\n\nimport 'package:path/path.dart' as p;",
        ),
    ],
)

# C3 tmp cleanup + InputFileStream close attempt on wordbook
patch(
    "lib/core/infrastructure/wordbook_database.dart",
    [
        (
            """        final tmpGz = '$dbPath.extract.gz';
        await File(tmpGz).writeAsBytes(gzBytes, flush: true);
        try {
          final input = InputFileStream(tmpGz);
          final output = OutputFileStream(dbPath);
          GZipDecoder().decodeStream(input, output);
          await output.close();
        } finally {
          try {
            await File(tmpGz).delete();
          } catch (_) {}
        }""",
            """        final tmpGz = '$dbPath.extract.gz';
        // MEM：启动清理上次中断残留的临时 gz。
        try {
          final stale = File(tmpGz);
          if (stale.existsSync()) await stale.delete();
        } catch (_) {}
        await File(tmpGz).writeAsBytes(gzBytes, flush: true);
        final input = InputFileStream(tmpGz);
        try {
          final output = OutputFileStream(dbPath);
          GZipDecoder().decodeStream(input, output);
          await output.close();
        } finally {
          try {
            // archive 3.x FileBuffer/输入流随文件删除释放；尽力 close。
            // ignore: avoid_dynamic_calls
            (input as dynamic).close?.call();
          } catch (_) {}
          try {
            await File(tmpGz).delete();
          } catch (_) {}
        }""",
        )
    ],
)

print("done apply")
