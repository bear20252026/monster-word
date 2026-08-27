// 由 Claude 团队生成 | Monster Word App

// 由 Claude 团队生成 | 移植自 v3.2 mediabutton/（4个类）+ download/（3个类）
// 媒体按钮 + 下载管理：1:1 翻译自 v3.2 反编译源码
//
// 包含：
//   mediabutton/HeadSetUtils.java       → HeadSetUtils
//   mediabutton/MediaButtonReceiver.java → MediaButtonReceiver（Flutter 中由 MethodChannel 代替）
//   mediabutton/MediaButtonManager.java  → MediaButtonManager
//   mediabutton/MediaSessionManager.java → MediaSessionManager
//   download/DownloadResourceTask.java   → DownloadResourceTask
//   download/SentenceDownloadTask.java   → SentenceDownloadTask
//   download/TextSpeechDownloadTask.java → TextSpeechDownloadTask

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

// ============================================================
// 常量（原版 PublicConstants 中的音频 URL）
// ============================================================

/// 基础音频 URL（原版 PublicConstants.BASE_AUDIO_URL）
const String _kBaseAudioUrl = 'https://audio.beingfine.cn/';

/// 七牛资源 URL（原版 PublicConstants.QINIU_RESOURCE_URL）
const String _kQiniuResourceUrl = 'https://7ncdn.beingfine.cn/';

/// TTS 音频 URL 1（原版 TextSpeechDownloadTask.getDownloadUrlPath1）
const String _kTtsAudioUrl1 = 'https://audio.beingfine.cn/';

/// TTS 音频 URL 2（原版 TextSpeechDownloadTask.getDownloadURlPath2）
const String _kTtsAudioUrl2 = 'https://7ncdn.beingfine.cn/';

// ============================================================
// HeadSetUtils（翻译自 HeadSetUtils.java）
// 原版通过 AudioManager.isWiredHeadsetOn() 检测有线耳机
// Flutter 中通过 MethodChannel 或 audio_session 包实现
// ============================================================

class HeadSetUtils {
  HeadSetUtils._();

  static const _channel = MethodChannel('com.monsterword/audio');

  /// 检测有线耳机是否连接（原版 isWiredHeadsetOn）
  static Future<bool> isWiredHeadsetOn() async {
    try {
      final result = await _channel.invokeMethod<bool>('isWiredHeadsetOn');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }
}

// ============================================================
// MediaButtonReceiver（翻译自 MediaButtonReceiver.java）
// 原版是 Android BroadcastReceiver，接收媒体按钮广播
// Flutter 中由 MethodChannel 回调代替，逻辑合入 MediaButtonManager
// ============================================================

// 原版 MediaButtonReceiver.onReceive → MediaButtonManager.handleMediaButtonIntent
// 在 Flutter 中，媒体按钮事件通过 MethodChannel 传入，
// MediaButtonManager._handleMethodCall 即为等价逻辑。

// ============================================================
// MediaButtonManager（翻译自 MediaButtonManager.java）
// 处理耳机/蓝牙媒体按钮的单击、双击、三击事件
// 原版使用 Handler.postDelayed 实现 500ms 延迟判断点击次数
// ============================================================

/// 媒体按钮监听接口（原版 MediaButtonManager.MediaButtonListener）
abstract class MediaButtonListener {
  void onClick();
  void onDoubleClick();
  void onTripleClick();
}

/// 媒体按钮管理器（原版 MediaButtonManager 单例）
class MediaButtonManager {
  static final MediaButtonManager _instance = MediaButtonManager._();
  factory MediaButtonManager() => _instance;
  MediaButtonManager._();

  static const _channel = MethodChannel('com.monsterword/media_button');

  /// 播放状态变化广播 action（原版 BROADCAST_ACTION_PLAYBACK_STATE_CHANGE）
  static const String broadcastActionPlaybackStateChange =
      'cn.com.langeasy.LangEasyLexis.broadcast_action_playback_state_change';

  MediaButtonListener? _listener;
  int _clickNum = 0;
  Timer? _clickTimer;
  bool _hasProcessDown = false;
  Timer? _autoClearTimer;
  bool _isRegistered = false;

  /// 设置媒体按钮监听（原版 setInterceptMediaButtonListener）
  void setListener(MediaButtonListener? listener) {
    _listener = listener;
  }

  /// 注册媒体按钮（原版构造函数中的 registerMediaButtonEventReceiver）
  Future<void> register() async {
    if (_isRegistered) return;
    _isRegistered = true;
    try {
      _channel.setMethodCallHandler(_handleMethodCall);
      await _channel.invokeMethod('registerMediaButton');
    } catch (_) {}
  }

  /// 注销媒体按钮
  Future<void> unregister() async {
    _isRegistered = false;
    try {
      await _channel.invokeMethod('unregisterMediaButton');
    } catch (_) {}
  }

  /// 重置媒体按钮（原版 resetMediaButton）
  /// 注销后重新注册，确保按钮事件路由正确
  Future<void> resetMediaButton() async {
    try {
      await _channel.invokeMethod('unregisterMediaButton');
      await _channel.invokeMethod('registerMediaButton');
    } catch (_) {}
  }

  /// 处理来自 MethodChannel 的媒体按钮事件
  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onMediaButton':
        final int? keyCode = call.arguments['keyCode'];
        final int? action = call.arguments['action'];
        if (keyCode != null && action != null) {
          _handleKeyEvent(keyCode, action);
        }
        break;
    }
  }

  /// 处理媒体按钮 Intent（原版 handleMediaButtonIntent）
  /// 原版从 Intent 中提取 KeyEvent，Flutter 中直接传入 keyCode 和 action
  void _handleKeyEvent(int keyCode, int action) {
    // action == 1 即 KeyEvent.ACTION_UP
    if (action != 1) return;

    switch (keyCode) {
      case 79: // KEYCODE_HEADSETHOOK
      case 85: // KEYCODE_MEDIA_PLAY_PAUSE
      case 126: // KEYCODE_MEDIA_PLAY
      case 127: // KEYCODE_MEDIA_PAUSE
        if (!_hasProcessDown) {
          _doAction();
        }
        setHasProcessDown(false);
        break;
      case 87: // KEYCODE_MEDIA_NEXT
        _clickNum = 2;
        _fireClickAction();
        break;
      case 88: // KEYCODE_MEDIA_PREVIOUS
        _clickNum = 3;
        _fireClickAction();
        break;
    }
  }

  /// 处理按键按下（原版 handleKeyDown）
  /// 返回 true 表示已处理
  bool handleKeyDown(int keyCode) {
    switch (keyCode) {
      case 79:
      case 85:
      case 126:
      case 127:
        setHasProcessDown(true);
        _doAction();
        return true;
      case 87:
        _clickNum = 2;
        _fireClickAction();
        return true;
      case 88:
        _clickNum = 3;
        _fireClickAction();
        return true;
      default:
        return false;
    }
  }

  /// 累加点击次数并延迟 500ms 判断（原版 doAction）
  void _doAction() {
    _clickNum++;
    _clickTimer?.cancel();
    _clickTimer = Timer(const Duration(milliseconds: 500), _fireClickAction);
  }

  /// 触发点击回调（原版 mClickRunnable）
  void _fireClickAction() {
    _clickTimer?.cancel();
    if (_listener != null) {
      switch (_clickNum) {
        case 1:
          _listener?.onClick();
          break;
        case 2:
          _listener?.onDoubleClick();
          break;
        case 3:
          _listener?.onTripleClick();
          break;
      }
    }
    _clickNum = 0;
  }

  /// 设置是否已处理按下事件（原版 setHasProcessDown）
  /// 防止 ACTION_DOWN 和 ACTION_UP 重复触发
  void setHasProcessDown(bool value) {
    _hasProcessDown = value;
    _autoClearTimer?.cancel();
    if (value) {
      _autoClearTimer = Timer(const Duration(seconds: 1), () {
        _hasProcessDown = false;
      });
    }
  }

  void dispose() {
    _clickTimer?.cancel();
    _autoClearTimer?.cancel();
    unregister();
  }
}

// ============================================================
// MediaSessionManager（翻译自 MediaSessionManager.java）
// 管理 Android MediaSession，显示锁屏控制和通知栏信息
// Flutter 中通过 MethodChannel 调用原生 MediaSession API
// ============================================================

/// 播放状态枚举（原版 PlaybackState 状态码）
enum MediaPlayState {
  none, // 0
  stopped, // 1
  paused, // PlaybackState.STATE_PAUSED = 2
  playing, // PlaybackState.STATE_PLAYING = 3
  buffering, // PlaybackState.STATE_BUFFERING = 6
}

/// MediaSession 管理器（原版 MediaSessionManager 单例）
class MediaSessionManager {
  static final MediaSessionManager _instance = MediaSessionManager._();
  factory MediaSessionManager() => _instance;
  MediaSessionManager._();

  static const _channel = MethodChannel('com.monsterword/media_session');

  bool _isActive = false;

  /// 激活 MediaSession（原版 setActive）
  Future<void> setActive() async {
    _isActive = true;
    try {
      await _channel.invokeMethod('setActive');
    } catch (_) {}
    MediaButtonManager().resetMediaButton();
  }

  /// 设置播放状态（原版 setPlaying）
  Future<void> setPlaying(int positionMs, double speed) async {
    if (!_isActive) await setActive();
    try {
      await _channel.invokeMethod('setPlaybackState', {
        'state': MediaPlayState.playing.index,
        'position': positionMs,
        'speed': speed,
      });
    } catch (_) {}
  }

  /// 设置缓冲状态（原版 setBuffering）
  Future<void> setBuffering(int positionMs, double speed) async {
    try {
      await _channel.invokeMethod('setPlaybackState', {
        'state': MediaPlayState.buffering.index,
        'position': positionMs,
        'speed': speed,
      });
    } catch (_) {}
  }

  /// 设置暂停状态（原版 setPausing）
  Future<void> setPausing(int positionMs, double speed) async {
    try {
      await _channel.invokeMethod('setPlaybackState', {
        'state': MediaPlayState.paused.index,
        'position': positionMs,
        'speed': speed,
      });
    } catch (_) {}
  }

  /// 设置标题信息（原版 setTitle）
  /// [album] 专辑/分类名，[title] 标题/单词
  Future<void> setTitle(String album, String title) async {
    try {
      await _channel.invokeMethod('setMetadata', {'album': album, 'title': title});
    } catch (_) {}
  }

  /// 设置封面图片（原版 setCover）
  Future<void> setCover(Uint8List imageBytes) async {
    try {
      await _channel.invokeMethod('setCover', {'imageBytes': imageBytes});
    } catch (_) {}
  }

  /// 设置失活
  Future<void> setInactive() async {
    _isActive = false;
    try {
      await _channel.invokeMethod('setInactive');
    } catch (_) {}
  }
}

// ============================================================
// 下载回调接口（翻译自 FileHttpReponseHandler）
// ============================================================

/// 下载回调（原版 FileHttpReponseHandler 接口）
abstract class FileDownloadCallback {
  void onSuccess(File file);
  void onFailure(String message, int errorCode);
}

/// 空实现，用于不需要回调的场景
class NoopDownloadCallback implements FileDownloadCallback {
  @override
  void onSuccess(File file) {}
  @override
  void onFailure(String message, int errorCode) {}
}

// ============================================================
// DownloadResourceTask（翻译自 DownloadResourceTask.java）
// 抽象下载任务基类：双 URL 容错 + 临时文件 + 回调通知
// ============================================================

/// 下载错误码（原版自定义错误码）
class DownloadErrorCode {
  static const int unknown = 0;
  static const int networkError = 10001;
  static const int fileError = 10002;
  static const int serverError = 10003;
  static const int cancelled = 10005;
}

/// 资源下载任务基类（原版 DownloadResourceTask 抽象类）
///
/// 核心逻辑：
/// 1. 先用 URL1 下载，失败后用 URL2 重试（双 CDN 容错）
/// 2. 下载到 .temp 文件，成功后重命名为正式文件
/// 3. 文件已存在时直接返回成功（缓存）
abstract class DownloadResourceTask {
  static const String _logTag = 'DownloadResourceTask';

  String? downloadUrl;
  FileDownloadCallback? _callback;
  bool _isFirstDownload = true;

  // ---- 子类必须实现 ----

  /// 执行下载（原版 execute）
  void execute();

  /// 获取保存目录路径（原版 getSaveFilePath）
  Future<String> getSaveFilePath();

  /// 获取第一下载 URL（原版 getDownloadUrlPath1）
  String getDownloadUrlPath1();

  /// 获取备用下载 URL（原版 getDownloadURlPath2）
  String getDownloadUrlPath2();

  // ---- 公开方法 ----

  /// 设置下载回调（原版 setListenr）
  void setCallback(FileDownloadCallback callback) {
    _callback = callback;
  }

  // ---- 内部下载逻辑 ----

  /// 开始下载（原版 startDownload）
  void startDownload() {
    _isFirstDownload = true;
    _downloadInternal(downloadUrl ?? '');
  }

  /// 内部下载实现（原版 downLoadTextAudioPlay_internal）
  void _downloadInternal(String url) async {
    if (url.isEmpty) {
      _notifyFail('URL is empty', DownloadErrorCode.unknown);
      return;
    }

    final fileName = p.basename(url);
    final savePath = p.join(await getSaveFilePath(), fileName);
    final targetFile = File(savePath);
    final tempFile = File('$savePath.temp');

    // 缓存命中
    if (await targetFile.exists()) {
      _log('file already exists: $savePath');
      _notifySuccess(targetFile);
      return;
    }

    // 选择 URL（首次用 URL1，重试用 URL2）
    final downloadUrlStr = _isFirstDownload ? getDownloadUrlPath1() : getDownloadUrlPath2();

    _log('downloading: $downloadUrlStr');

    try {
      // 确保目录存在
      await Directory(await getSaveFilePath()).create(recursive: true);

      // HTTP GET 下载
      final response = await http.get(Uri.parse(downloadUrlStr)).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        // 写入临时文件
        await tempFile.writeAsBytes(response.bodyBytes);

        // 重命名为正式文件
        if (!await targetFile.exists()) {
          await tempFile.rename(savePath);
        }

        _log('download success: $downloadUrlStr');
        _notifySuccess(targetFile);
      } else {
        _log('download failed with status: ${response.statusCode}');
        // 首次失败且非取消错误，尝试备用 URL
        if (_isFirstDownload && response.statusCode != DownloadErrorCode.cancelled) {
          _isFirstDownload = false;
          _downloadInternal(url);
          return;
        }
        _notifyFail('HTTP ${response.statusCode}', response.statusCode);
      }
    } catch (e) {
      _log('download error: $e');
      // 首次失败，尝试备用 URL
      if (_isFirstDownload) {
        _isFirstDownload = false;
        _downloadInternal(url);
        return;
      }
      _notifyFail(e.toString(), DownloadErrorCode.networkError);
    }
  }

  /// 成功通知（原版 notifySucc）— 确保在主线程回调
  void _notifySuccess(File file) {
    // Flutter 中回调默认在主线程（dart:isolate 除外）
    _callback?.onSuccess(file);
  }

  /// 失败通知（原版 notifyFail）
  void _notifyFail(String message, int errorCode) {
    _callback?.onFailure(message, errorCode);
  }

  void _log(String msg) {
    debugPrint('$_logTag: $msg');
  }
}

// ============================================================
// SentenceDownloadTask（翻译自 SentenceDownloadTask.java）
// 例句音频下载任务
// URL1: http://audio.beingfine.cn/{path}
// URL2: http://7ncdn.beingfine.cn/{path}
// ============================================================

/// 例句音频下载（原版 SentenceDownloadTask）
class SentenceDownloadTask extends DownloadResourceTask {
  SentenceDownloadTask(String url) {
    downloadUrl = url;
  }

  @override
  Future<String> getSaveFilePath() async {
    final localPath = await _getLocalFilePath();
    if (downloadUrl == null || downloadUrl!.isEmpty) {
      return p.join(localPath, '/');
    }
    return p.join(localPath, p.dirname(downloadUrl!));
  }

  @override
  String getDownloadUrlPath1() {
    return '$_kBaseAudioUrl$downloadUrl';
  }

  @override
  String getDownloadUrlPath2() {
    return '$_kQiniuResourceUrl$downloadUrl';
  }

  @override
  void execute() {
    if (downloadUrl == null || downloadUrl!.isEmpty) return;
    startDownload();
  }

  /// 获取本地存储路径（原版 PublicConstants.localFilePath）
  Future<String> _getLocalFilePath() async {
    final dir = await getApplicationDocumentsDirectory();
    return p.join(dir.path, 'audio');
  }

  /// 静态便捷方法：下载例句音频并返回 File
  static Future<File?> download(String url) async {
    final task = SentenceDownloadTask(url);
    final completer = Completer<File?>();
    task.setCallback(
      _SimpleCallback(
        onSuccess: (file) => completer.complete(file),
        onFailure: (msg, code) => completer.complete(null),
      ),
    );
    task.execute();
    return completer.future;
  }
}

// ============================================================
// TextSpeechDownloadTask（翻译自 TextSpeechDownloadTask.java）
// TTS 语音下载任务
// 先请求服务端获取音频路径，再下载文件
// ============================================================

/// TTS 语音下载（原版 TextSpeechDownloadTask）
///
/// 流程：
/// 1. 请求 GetAudioWithTextService 获取音频 URL
/// 2. 将 text→audioUrl 映射存入本地缓存（TTSAudioDao）
/// 3. 下载音频文件到 TTS 目录
class TextSpeechDownloadTask extends DownloadResourceTask {
  final String ttsText;
  final int type;
  final String word;

  /// [ttsText] TTS 文本内容
  /// [type] 类型（原版参数）
  /// [word] 关联单词
  TextSpeechDownloadTask(this.ttsText, this.type, this.word);

  @override
  Future<String> getSaveFilePath() async {
    // 原版 LexisFileSystem.getTTSDir()
    return _ttsDir;
  }

  @override
  String getDownloadUrlPath1() {
    return '$_kTtsAudioUrl1$downloadUrl';
  }

  @override
  String getDownloadUrlPath2() {
    return '$_kTtsAudioUrl2$downloadUrl';
  }

  /// TTS 目录（同步版本，使用延迟初始化）
  static String _ttsDir = '';

  /// 初始化 TTS 目录（必须在使用前调用）
  static Future<void> initTtsDir() async {
    final dir = await getApplicationDocumentsDirectory();
    _ttsDir = p.join(dir.path, 'tts');
  }

  @override
  void execute() async {
    if (ttsText.isEmpty) return;

    // 确保 TTS 目录已初始化
    if (_ttsDir.isEmpty) await initTtsDir();

    // 先查询本地缓存是否有该文本的音频 URL
    final cachedUrl = await TTSAudioCache.getAudioUrl(ttsText);
    _log('execute: ttsText=$ttsText, cachedUrl=$cachedUrl');

    if (cachedUrl != null && cachedUrl.isNotEmpty) {
      final fileName = p.basename(cachedUrl);
      final file = File(p.join(_ttsDir, fileName));

      if (await file.exists()) {
        _log('file exists: ${file.path}');
        _callback?.onSuccess(file);
        return;
      }
    }

    // 本地无缓存，请求服务端获取音频 URL
    try {
      final audioUrl = await _requestAudioUrl(ttsText, type, word);
      _log('requestAudio result: $audioUrl');

      if (audioUrl == null || audioUrl.isEmpty) {
        _notifyFail(ttsText, DownloadErrorCode.serverError);
        return;
      }

      // 缓存映射关系
      await TTSAudioCache.setAudioUrl(ttsText, audioUrl);

      // 设置下载 URL 并开始下载
      downloadUrl = audioUrl;
      startDownload();
    } catch (e) {
      _log('requestAudio error: $e');
      _notifyFail(ttsText, DownloadErrorCode.networkError);
    }
  }

  /// 请求服务端获取音频 URL（原版 GetAudioWithTextService.reuqestAudio）
  Future<String?> _requestAudioUrl(String text, int type, String word) async {
    try {
      // 原版 API: GetAudioWithTextService
      // POST 请求，参数: text, type, word
      final response = await http
          .post(
            Uri.parse('${_kBaseAudioUrl}getAudioWithText'),
            body: {'text': text, 'type': type.toString(), 'word': word},
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        // 原版解析: data_body.path
        final jsonBody = _parseJson(response.body);
        if (jsonBody != null) {
          final dataBody = jsonBody['data_body'];
          if (dataBody is Map) {
            final path = dataBody['path'] as String?;
            return path;
          }
        }
      }
    } catch (e) {
      _log('_requestAudioUrl error: $e');
    }
    return null;
  }

  Map<String, dynamic>? _parseJson(String body) {
    try {
      return jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  @override
  void _log(String msg) {
    debugPrint('TextSpeechDownloadTask: $msg');
  }

  /// 静态便捷方法：下载 TTS 音频并返回 File
  static Future<File?> download(String text, int type, String word) async {
    final task = TextSpeechDownloadTask(text, type, word);
    final completer = Completer<File?>();
    task.setCallback(
      _SimpleCallback(
        onSuccess: (file) => completer.complete(file),
        onFailure: (msg, code) => completer.complete(null),
      ),
    );
    task.execute();
    return completer.future;
  }
}

// ============================================================
// TTS 音频缓存（原版 TTSAudioDao）
// 本地缓存 text→audioUrl 映射，避免重复请求服务端
// ============================================================

/// TTS 音频 URL 缓存（原版 TTSAudioDao）
class TTSAudioCache {
  static final Map<String, String> _cache = {};

  /// 查询缓存（原版 getTTsAudio）
  static Future<String?> getAudioUrl(String text) async {
    return _cache[text];
  }

  /// 写入缓存（原版 insertTTSAudio）
  static Future<void> setAudioUrl(String text, String audioUrl) async {
    _cache[text] = audioUrl;
  }

  /// 清除缓存
  static void clear() {
    _cache.clear();
  }
}

// ============================================================
// 工具类
// ============================================================

/// 简单回调实现（内部使用）
class _SimpleCallback implements FileDownloadCallback {
  final void Function(File file) _onSuccess;
  final void Function(String message, int errorCode) _onFailure;

  _SimpleCallback({required this._onSuccess, required this._onFailure});

  @override
  void onSuccess(File file) => _onSuccess(file);
  @override
  void onFailure(String message, int errorCode) => _onFailure(message, errorCode);
}
