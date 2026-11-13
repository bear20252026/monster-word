// P2-12（架构审计 2026-11-12）：用户数据维护服务（备份恢复入口）。
//
// 口径对齐 WordBookMaintenanceService（REG-ARCH-005）：presentation 消费维护操作
// 的唯一应用层入口，页面经 Provider 注入，不得直接 import infrastructure 的
// 备份服务/数据库实现。本服务编排「关闭双库 → 校验 → 安全替换」，恢复成功后
// 由 UI 引导重启刷新 DAO 缓存句柄。
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:word_app/core/infrastructure/user_data_backup_service.dart';
import 'package:word_app/core/infrastructure/user_database.dart';

/// 备份恢复结果。
class RestoreResult {
  const RestoreResult({required this.success, required this.message});
  final bool success;
  final String message;
}

/// 用户数据维护服务：列出备份 + 从备份恢复用户库与复习库。
class UserDataMaintenanceService {
  UserDataMaintenanceService({required this.closeReviewStore});

  /// 关闭复习库句柄的回调（由组合根注入 `sl<ReviewScheduleRepository>().close`）。
  /// core 层不依赖 features（R-core），故经回调而非直接 import 复习仓储。
  final Future<void> Function() closeReviewStore;

  /// 列出可用备份（新→旧），供恢复选择对话框消费。
  Future<List<Map<String, Object?>>> listBackups() => UserDataBackupService.listBackups();

  /// 从指定日期戳的备份恢复 user_data.db 与 review_schedule.db。
  ///
  /// [stamp] 形如 `20261113`（备份文件名中的日期段）。两库都须有对应备份且
  /// 通过完整性校验才执行；任一缺失/损坏即整体拒绝，绝不半恢复。
  /// 恢复成功后调用方应引导用户重启应用（DAO 缓存句柄需重启刷新）。
  Future<RestoreResult> restoreFromStamp(String stamp) async {
    try {
      final root = (await getApplicationSupportDirectory()).path;
      final backupDir = p.join(root, 'backups');
      final userBackup = p.join(backupDir, 'user_data.db-$stamp.bak');
      final reviewBackup = p.join(backupDir, 'review_schedule.db-$stamp.bak');

      // 先校验两库备份（只读打开 + quick_check），任一不合格即拒绝。
      if (!await UserDataBackupService.validateBackup(userBackup)) {
        return const RestoreResult(success: false, message: '用户库备份缺失或已损坏，无法恢复。');
      }
      if (!await UserDataBackupService.validateBackup(reviewBackup)) {
        return const RestoreResult(success: false, message: '复习库备份缺失或已损坏，无法恢复。');
      }

      // 关闭双库句柄（替换文件前必须释放，否则 Windows 文件占用 / 边车撕裂）。
      await UserDatabase.instance.close();
      await closeReviewStore();

      // 安全替换：现库留档 + 边车随行 + 复制备份（见 restoreBackupFile）。
      await UserDataBackupService.restoreBackupFile(backupPath: userBackup, targetDbPath: p.join(root, 'user_data.db'));
      await UserDataBackupService.restoreBackupFile(
        backupPath: reviewBackup,
        targetDbPath: p.join(root, 'review_schedule.db'),
      );

      return const RestoreResult(success: true, message: '恢复完成。请重启应用以使全部数据生效。');
    } catch (e) {
      return RestoreResult(success: false, message: '恢复失败：$e\n原数据已留档，可重启后重试或人工回退。');
    }
  }
}
