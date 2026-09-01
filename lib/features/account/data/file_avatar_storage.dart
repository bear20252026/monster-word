// Monster Word App
//
// 头像本地存储实现（data 层）：file_selector 选图 + path_provider 落盘。
// Windows / Android 双端统一走 file_selector（官方维护，两端均有插件实现）。

import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:word_app/features/account/application/avatar_storage.dart';

/// 基于系统文件选择器与应用私有目录的头像存储实现。
class FileAvatarStorage implements AvatarStorage {
  static const _avatarDirName = 'avatars';
  static const _acceptedExtensions = ['jpg', 'jpeg', 'png', 'webp'];

  @override
  Future<String?> pickAndSave() async {
    const typeGroup = XTypeGroup(
      label: '图片',
      extensions: _acceptedExtensions,
      mimeTypes: ['image/jpeg', 'image/png', 'image/webp'],
    );
    final file = await openFile(acceptedTypeGroups: [typeGroup]);
    if (file == null) return null; // 用户取消

    final ext = p.extension(file.path).replaceFirst('.', '').toLowerCase();
    final safeExt = _acceptedExtensions.contains(ext) ? ext : 'png';
    final dir = await _ensureAvatarDir();
    final dest = File(p.join(dir.path, 'avatar_${DateTime.now().millisecondsSinceEpoch}.$safeExt'));
    // XFile 无 copy 方法，经 path 落盘（Windows/Android 均有真实路径）。
    await File(file.path).copy(dest.path);
    return dest.path;
  }

  @override
  Future<void> delete(String? path) async {
    if (path == null || path.isEmpty) return;
    final dir = await _ensureAvatarDir();
    // 仅删除应用私有头像目录内的文件，防误删用户外部文件。
    if (!p.isWithin(dir.path, path)) return;
    final f = File(path);
    if (await f.exists()) {
      await f.delete();
    }
  }

  Future<Directory> _ensureAvatarDir() async {
    final docDir = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docDir.path, _avatarDirName));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }
}
