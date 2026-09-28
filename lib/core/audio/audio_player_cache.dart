part of 'audio_players.dart';

// 音频缓存目录管理
// ============================================================
// 缓存目录工具（LexisFileSystem / FileUtils 的简化替代）
// ============================================================

/// 音频缓存目录管理
class _AudioCacheDir {
  static String? _cachePath;

  /// 获取音频缓存根目录。
  /// 审计 I25：改用系统缓存目录（Android cache/、Windows %LOCALAPPDATA% 缓存位）——
  /// 此前放 Documents 会随 iOS 备份、且永不回收。缓存内容均可重下，
  /// 旧 Documents/audio_cache 残留不做迁移（一次性空间残留，可接受）。
  static Future<String> getCachePath() async {
    if (_cachePath != null) return _cachePath!;
    final cacheBase = await getApplicationCacheDirectory();
    _cachePath = p.join(cacheBase.path, 'audio_cache');
    final dir = Directory(_cachePath!);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    return _cachePath!;
  }

  /// 单词发音缓存路径（美音）
  static Future<String> wordUsSpeechPath(String word) async {
    final base = await getCachePath();
    return p.join(base, 'phonetic', 'us', '${word.toLowerCase()}.mp3');
  }

  /// 单词发音缓存路径（英音）
  static Future<String> wordUkSpeechPath(String word) async {
    final base = await getCachePath();
    return p.join(base, 'phonetic', 'uk', '${word.toLowerCase()}.mp3');
  }

  /// 例句音频缓存路径
  static Future<String> sentenceAudioPath(String url) async {
    final base = await getCachePath();
    // 从 URL 中提取文件名
    final fileName = _getFileName(url);
    return p.join(base, 'sentence', fileName);
  }

  /// TTS 音频缓存路径
  static Future<String> ttsAudioPath(String url) async {
    final base = await getCachePath();
    final fileName = _getFileName(url);
    return p.join(base, 'tts', fileName);
  }

  /// 从 URL/路径中提取文件名（安全审计 S4：防路径遍历）
  ///
  /// 网络返回的文件名不可信：%2e%2e 等编码可解码为 ../ 逃出缓存目录。
  /// 取末段后仅保留安全字符白名单，其余替换为下划线。
  static String _getFileName(String path) {
    String name;
    final uri = Uri.tryParse(path);
    if (uri != null && uri.pathSegments.isNotEmpty) {
      name = uri.pathSegments.last;
    } else {
      name = path.split('/').last;
    }
    name = p.basename(name); // 双保险：剥离任何目录成分
    if (name.isEmpty || name == '.' || name == '..') name = 'unnamed_audio';
    return name.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
  }
}
