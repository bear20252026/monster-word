// Monster Word App
//
// 头像存储端口（application 层）。
//
// 职责：选图 → 落盘到应用私有目录，返回本地路径供 profile.avatar 持久化。
// presentation 层只依赖本端口，不直接接触 file_selector / 文件系统。

/// 头像本地存储端口。
abstract interface class AvatarStorage {
  /// 打开系统选图器，将选中图片拷贝到应用私有目录并返回本地路径。
  ///
  /// 用户取消返回 null；选择失败或拷贝失败抛异常由调用方提示。
  Future<String?> pickAndSave();

  /// 删除旧头像文件。
  ///
  /// 仅删除位于应用私有头像目录内的文件（防误删外部文件）；路径为空或
  /// 文件不存在时静默忽略。
  Future<void> delete(String? path);
}
