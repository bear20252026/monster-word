// Monster Word App
//
// 头像本地存储实现（data 层）：file_selector 选图 + path_provider 落盘。
// Windows / Android 双端统一走 file_selector（官方维护，两端均有插件实现）。

import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:word_app/features/account/application/avatar_storage.dart';
import 'package:word_app/core/utils/swallowed_error_report.dart';

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
    // 先写 tmp 再原子改名：直写目标路径时复制中断会留下损坏头像被永久展示。
    final tmp = File('${dest.path}.tmp');
    await File(file.path).copy(tmp.path);
    await tmp.rename(dest.path);
    // MW-54：此处【不再清理旧头像】——「保存新文件」与「提交新头像」是两个
    // 职责。旧实现先删旧头像、后保存资料，资料保存失败时旧文件已永久丢失。
    // 旧头像由调用方在资料 durable 保存成功后经 [delete] 显式清理；
    // 孤儿文件由启动清理（cleanOrphans）兜底，不会无界增长。
    return dest.path;
  }

  /// MW-54：清理头像目录内的孤儿文件（保留 [keepPaths] 中的文件）。
  /// 启动/进入资料页时调用，兜住「保存失败回滚后残留的新文件」与历史遗留。
  @override
  Future<void> cleanOrphans(Set<String> keepPaths) async {
    try {
      final dir = await _ensureAvatarDir();
      for (final entity in dir.listSync()) {
        final name = p.basename(entity.path);
        if (entity is! File || !name.startsWith('avatar_') || name.endsWith('.tmp')) continue;
        if (keepPaths.contains(entity.path)) continue;
        try {
          await entity.delete();
        } catch (_) {
          // 单个删除失败不阻断（下次再清）。
        }
      }
    } catch (e, s) {
      // 清理失败只影响磁盘占用。
      reportSwallowedError('头像孤儿文件清理失败', e, s);
    }
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
