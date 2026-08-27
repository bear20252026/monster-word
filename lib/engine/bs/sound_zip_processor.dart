// 移植自 v3.2 bs/SoundZipProcessor.java
// 语音包下载处理器：下载离线语音 ZIP 包、解压、进度回调

import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';

import '../../data/app_preferences.dart';

/// 语音包下载回调（翻译自 SoundZipProcessor.Callback）
abstract class SoundZipCallback {
  void onStart();
  void onUpdateMessage(String message);
  void onUpdateProgress(int progress);
  void onSuccess();
  void onFailure();
}

/// 语音包下载处理器（翻译自 SoundZipProcessor.java）
///
/// 下载 US-UK-speech.zip 离线语音包到本地，支持断点续传、进度回调、解压。
/// 下载完成后自动解压到 dicts/US-UK-speech 目录。
class SoundZipProcessor {
  static const _soundZipUrl = 'https://static.beingfine.cn/dicts/US-UK-speech.zip';
  static const _soundZipPath = '/dicts/US-UK-speech.zip';
  static const _soundZipTmpPath = '/dicts/US-UK-speech.zip.tmp';

  SoundZipCallback? _callback;
  double _size = 0;
  bool _isDownloading = false;

  /// 设置回调
  void setCallback(SoundZipCallback callback) {
    _callback = callback;
  }

  /// 取消注册回调
  void unRegisterCallback() {
    _callback = null;
  }

  /// 获取已下载语音包大小（MB）
  double get size => _size;

  /// 是否正在下载
  bool get isDownloading => _isDownloading;

  /// 下载语音包（原版 downloadSoundZip）
  Future<void> downloadSoundZip() async {
    if (_isDownloading) return;
    _isDownloading = true;

    try {
      final appDir = await getApplicationDocumentsDirectory();
      final basePath = appDir.path;

      final tmpFile = File('$basePath$_soundZipTmpPath');
      final zipFile = File('$basePath$_soundZipPath');

      // 确保目录存在
      await tmpFile.parent.create(recursive: true);

      // 删除旧的 zip 文件
      if (await zipFile.exists()) {
        await zipFile.delete();
      }

      // 获取已缓存的大小（断点续传）
      int cacheSize = 0;
      if (await tmpFile.exists()) {
        cacheSize = await tmpFile.length();
      }

      _notifyOnStart();

      // 下载文件
      final client = HttpClient();
      try {
        final request = await client.getUrl(Uri.parse(_soundZipUrl));
        if (cacheSize > 0) {
          request.headers.set('Range', 'bytes=$cacheSize-');
        }
        final response = await request.close();

        if (response.statusCode == 200 || response.statusCode == 206) {
          final totalSize = response.contentLength + cacheSize;
          var downloaded = cacheSize;

          // 写入文件（追加模式）
          final sink = tmpFile.openWrite(mode: cacheSize > 0 ? FileMode.append : FileMode.write);

          await for (final chunk in response) {
            sink.add(chunk);
            downloaded += chunk.length;

            if (totalSize > 0) {
              final progress = ((downloaded * 100.0) / totalSize).round();
              _notifyProgress(progress);
            }
          }

          await sink.close();

          // 验证文件
          if (await tmpFile.length() <= 0) {
            _notifyMsg('数据包丢失，下载失败');
            _downloadFail(deleteTmp: true);
            return;
          }

          _notifyMsg('正在处理语音包，请稍候...');

          // 移动临时文件到最终位置
          await tmpFile.rename(zipFile.path);

          // 解压
          final extractPath = zipFile.path.substring(0, zipFile.path.lastIndexOf('.zip'));
          final success = await _unzipFile(zipFile.path, extractPath);

          if (success) {
            _downloadSuccess(extractPath);
          } else {
            _notifyMsg('音频包解压出错，请重新下载');
            _downloadFail(deleteTmp: false);
          }
        } else {
          _notifyMsg('下载失败');
          _downloadFail(deleteTmp: true);
        }
      } finally {
        client.close();
      }
    } catch (e) {
      _notifyMsg('处理出错，磁盘空间不足？');
      _downloadFail(deleteTmp: true);
    } finally {
      _isDownloading = false;
    }
  }

  /// 取消下载
  void cancelDownload() {
    _isDownloading = false;
  }

  /// 解压 ZIP 文件（原版 Unzip.unzip）
  Future<bool> _unzipFile(String zipPath, String extractPath) async {
    try {
      final bytes = await File(zipPath).readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      final dir = Directory(extractPath);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      for (final file in archive) {
        final filePath = '$extractPath/${file.name}';
        if (file.isFile) {
          final outFile = File(filePath);
          await outFile.parent.create(recursive: true);
          await outFile.writeAsBytes(file.content as List<int>);
        } else {
          await Directory(filePath).create(recursive: true);
        }
      }

      return true;
    } catch (_) {
      return false;
    }
  }

  /// 下载成功
  Future<void> _downloadSuccess(String extractPath) async {
    try {
      // 计算解压后文件夹大小
      final dir = Directory(extractPath);
      if (dir.existsSync()) {
        _size = _getFolderSize(dir) / (1024 * 1024);
        _size = double.parse(_size.toStringAsFixed(2));
      }

      // 保存离线语音标记
      await UserPreferences().setBool(UserPreferences.offlineSpeech, true);
      _notifySuccess();
    } catch (_) {
      _notifyFailure();
    }
  }

  /// 下载失败处理
  void _downloadFail({required bool deleteTmp}) {
    _isDownloading = false;
    if (deleteTmp) {
      // 清理临时文件
      _cleanupTmp();
    }
    _notifyFailure();
  }

  /// 清理临时文件
  Future<void> _cleanupTmp() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final tmpFile = File('${appDir.path}$_soundZipTmpPath');
      if (await tmpFile.exists()) {
        await tmpFile.delete();
      }
      final zipFile = File('${appDir.path}$_soundZipPath');
      if (await zipFile.exists()) {
        await zipFile.delete();
      }
    } catch (_) {
      // 忽略清理错误
    }
  }

  /// 计算文件夹大小（字节）
  static double _getFolderSize(Directory dir) {
    var size = 0.0;
    try {
      for (final entity in dir.listSync(recursive: true)) {
        if (entity is File) {
          size += entity.lengthSync();
        }
      }
    } catch (_) {
      // 忽略
    }
    return size;
  }

  // --- 回调通知 ---

  void _notifyOnStart() {
    _callback?.onStart();
  }

  void _notifyMsg(String msg) {
    _callback?.onUpdateMessage(msg);
  }

  void _notifyProgress(int progress) {
    _callback?.onUpdateProgress(progress);
  }

  void _notifySuccess() {
    _callback?.onSuccess();
  }

  void _notifyFailure() {
    _callback?.onFailure();
  }
}
