// 由 Claude 团队生成 | Monster Word App

// 翻译自 util/LexisFileSystem.dart, ZpkUtils.dart
// 文件系统路径管理 + ZPK 工具

import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// 文件系统路径管理（翻译自 LexisFileSystem.dart）
class LexisFileSystem {
  static const _ttsPath = '/tts/';
  static const _ukPath = '/speeches/UK/UK-speech/';
  static const _ukUrl = '/speeches/UK/UK-speech';
  static const _usPath = '/speeches/US/US-speech/';
  static const _usUrl = '/speeches/US/US-speech';
  static const _zpkPath = '/zpk/';
  static const _zpkSuffix = '.zpk';

  static String? _localFilePath;

  /// 获取本地文件根目录
  static Future<String> getLocalFilePath() async {
    if (_localFilePath != null) return _localFilePath!;
    final dir = await getApplicationDocumentsDirectory();
    _localFilePath = dir.path;
    return _localFilePath!;
  }

  /// 初始化目录
  static Future<void> initDir() async {
    final basePath = await getLocalFilePath();
    final dirs = [
      '$basePath$_usPath',
      '$basePath$_ukPath',
      '$basePath$_zpkPath',
      '$basePath$_ttsPath',
    ];
    for (final dir in dirs) {
      await Directory(dir).create(recursive: true);
    }
  }

  /// 美式发音文件路径
  static Future<String> wordUsSpeechMp3Path(String word) async {
    final basePath = await getLocalFilePath();
    final safeWord = word.contains('/') ? word.replaceAll('/', ' or ') : word;
    return '$basePath$_usPath$safeWord.mp3';
  }

  /// 英式发音文件路径
  static Future<String> wordUkSpeechMp3Path(String word) async {
    final basePath = await getLocalFilePath();
    final safeWord = word.contains('/') ? word.replaceAll('/', ' or ') : word;
    return '$basePath$_ukPath$safeWord.mp3';
  }

  /// 美式发音 URL
  static String wordUsSpeechMp3Url(String word, String baseUrl) {
    final safeWord = word.contains('/') ? word.replaceAll('/', ' or ') : word;
    return '$baseUrl$_usUrl/$safeWord.mp3';
  }

  /// 英式发音 URL
  static String wordUkSpeechMp3Url(String word, String baseUrl) {
    final safeWord = word.contains('/') ? word.replaceAll('/', ' or ') : word;
    return '$baseUrl$_ukUrl/$safeWord.mp3';
  }

  /// ZPK 文件路径
  static Future<String> wordZpkPath(String zpkName) async {
    final basePath = await getLocalFilePath();
    final intro = getZpkIntroFromZpkName(zpkName);
    if (intro == null) {
      return '$_zpkPath$zpkName$_zpkSuffix';
    }
    return '$basePath$_zpkPath${intro.bid}/$zpkName$_zpkSuffix';
  }

  /// ZPK 目录
  static Future<String> getWordZpkDir() async {
    final basePath = await getLocalFilePath();
    return '$basePath$_zpkPath';
  }

  /// ZPK 下载 URL
  static String wordZpkUrl(String zpkName) {
    return 'http://static.beingfine.cn/r/$zpkName$_zpkSuffix';
  }

  /// ZPK 备用下载 URL
  static String wordZpk7NUrl(String zpkName) {
    return 'http://7ncdn.beingfine.cn/r/$zpkName$_zpkSuffix';
  }

  /// TTS 目录
  static Future<String> getTTSDir() async {
    return _ttsPath;
  }

  /// 从 ZPK 文件名解析信息
  static ZpkIntroInfo? getZpkIntroFromZpkName(String name) {
    if (name.isEmpty) return null;
    try {
      final parts = name.split('/').last.split('_');
      if (parts.length != 4) return null;
      return ZpkIntroInfo(
        bid: int.parse(parts[0]),
        wid: int.parse(parts[1]),
        ver: int.parse(parts[2]),
      );
    } catch (_) {
      return null;
    }
  }
}

/// ZPK 信息（翻译自 ZpkUtils.ZpkIntroInfo）
class ZpkIntroInfo {
  final int bid;
  final int wid;
  final int ver;

  const ZpkIntroInfo({required this.bid, required this.wid, required this.ver});
}
