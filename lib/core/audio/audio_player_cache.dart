part of 'audio_players.dart';

// 音频缓存目录管理
// ============================================================
// 缓存目录工具（LexisFileSystem / FileUtils 的简化替代）
// ============================================================

/// 音频缓存目录管理
class _AudioCacheDir {
  static String? _cachePath;

  /// MW-52：缓存总量上限。音频单文件 <1MB，200MB 足以覆盖常用词与例句；
  /// 此前缓存只增不减（虽位于系统缓存目录、可被 OS 回收，但用户态无上限，
  /// 长期使用会持续占用磁盘）。
  static const int maxCacheBytes = 200 * 1024 * 1024;

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

  /// MW-52 缓存自愈：播放前判定缓存文件是否真的可用。
  ///
  /// 覆盖三类历史坏缓存：①下载中断留下的半写文件；②CDN 返回 HTML 错误页被
  /// 当音频缓存（迁移前无文件头校验）；③磁盘层面损坏。判定不可用时**删除**
  /// 该文件并返回 false，调用方走正常下载路径——此前只要 `existsSync()` 为真
  /// 就直接播放，坏文件会永久占据该词的缓存位且每次都静默播不出。
  static Future<bool> isUsable(String path) async {
    try {
      final file = File(path);
      if (!file.existsSync()) return false;
      if (await file.length() < 4) {
        _deleteQuietly(file);
        return false;
      }
      if (await AudioDownloader._hasAudioMagic(file)) return true;
      reportSwallowedError(
        '音频缓存文件头非法，已删除待重下（${p.basename(path)}）',
        StateError('invalid audio magic'),
        StackTrace.current,
      );
      _deleteQuietly(file);
      return false;
    } catch (e, s) {
      reportSwallowedError('音频缓存可用性检查失败（按不可用处理）', e, s);
      return false;
    }
  }

  /// MW-52 缓存回收：目录总量超上限时按 mtime 由旧到新删除（LRU 近似）。
  ///
  /// 正在播放的文件删除会失败，直接跳过——下一次回收再处理。
  static Future<void> enforceLimit() async {
    try {
      final dir = Directory(await getCachePath());
      if (!dir.existsSync()) return;

      final entries = <({File file, int size, DateTime modified})>[];
      var total = 0;
      await for (final entity in dir.list(recursive: true, followLinks: false)) {
        if (entity is! File) continue;
        try {
          final stat = await entity.stat();
          total += stat.size;
          entries.add((file: entity, size: stat.size, modified: stat.modified));
        } catch (_) {
          // 单个文件 stat 失败（正被删除/占用）跳过，不影响整体回收
        }
      }
      if (total <= maxCacheBytes) return;

      entries.sort((a, b) => a.modified.compareTo(b.modified));
      var removed = 0;
      for (final entry in entries) {
        if (total <= maxCacheBytes) break;
        try {
          await entry.file.delete();
          total -= entry.size;
          removed++;
        } catch (_) {
          // 占用中的文件跳过（可能正在播放）
        }
      }
      if (removed > 0) {
        reportSwallowedError(
          '音频缓存超上限（${maxCacheBytes ~/ (1024 * 1024)}MB），LRU 回收 $removed 个文件',
          StateError('audio cache eviction'),
          StackTrace.current,
        );
      }
    } catch (e, s) {
      reportSwallowedError('音频缓存 LRU 回收失败', e, s);
    }
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

  static void _deleteQuietly(File file) {
    try {
      if (file.existsSync()) file.deleteSync();
    } catch (_) {
      // 删除失败可忽略：下次下载会覆盖，LRU 也会回收
    }
  }
}
