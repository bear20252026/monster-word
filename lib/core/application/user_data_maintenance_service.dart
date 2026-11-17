// P2-12（架构审计 2026-11-12）：用户数据维护服务（备份恢复入口）。
//
// 口径对齐 WordBookMaintenanceService（REG-ARCH-005）：presentation 消费维护操作
// 的唯一应用层入口，页面经 Provider 注入，不得直接 import infrastructure 的
// 备份服务/数据库实现。本服务编排「关闭双库 → 校验 → 安全替换 → SP 快照回放
// → 重开双库」。
//
// 第四轮审计 M3/M18（2026-11-17）：
// - M3：恢复面扩到 SP 全量快照（sp_prefs-<stamp>.json，凭证键排除）——此前
//   只恢复两个 db，保护卡/兑换章/奖励队列等 SP 独有数据与恢复库不同步。
//   旧备份（无 SP 快照）按「仅恢复 db」降级处理并在结果文案如实说明。
// - M18：UserDatabase.close 广播失效（各 DAO 已订阅作废缓存句柄），恢复后
//   就地重开双库 + 复位应用层缓存，不再强制 exit(0) 重启。
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:word_app/core/infrastructure/user_data_backup_service.dart';
import 'package:word_app/core/infrastructure/user_data_sp_registry.dart';
import 'package:word_app/core/infrastructure/user_database.dart';
import 'package:word_app/core/utils/swallowed_error_report.dart';

/// 备份恢复结果。
class RestoreResult {
  const RestoreResult({required this.success, required this.message});
  final bool success;
  final String message;
}

/// 用户数据维护服务：列出备份 + 从备份恢复用户库与复习库。
class UserDataMaintenanceService {
  UserDataMaintenanceService({
    required this.closeReviewStore,
    required this.reopenReviewStore,
    this.resetFeatureCaches,
  });

  /// 关闭复习库句柄的回调（由组合根注入 `sl<ReviewScheduleRepository>().close`）。
  /// core 层不依赖 features（R-core），故经回调而非直接 import 复习仓储。
  final Future<void> Function() closeReviewStore;

  /// M18：重开复习库的回调（组合根注入 initialize）——恢复后就地重载，
  /// 不再依赖进程重启刷新句柄。
  final Future<void> Function() reopenReviewStore;

  /// M18：应用层缓存复位回调（组合根注入：金币降级态/收藏与掌握快照/
  /// 今日进度/任务与经验 store 等）。DAO 层句柄失效由库关闭广播负责，
  /// 本回调只处理 Provider 树内的内存态。失败只上报不阻断恢复结果。
  final Future<void> Function()? resetFeatureCaches;

  /// 列出可用备份（新→旧），供恢复选择对话框消费。
  Future<List<Map<String, Object?>>> listBackups() => UserDataBackupService.listBackups();

  /// 从指定日期戳的备份恢复 user_data.db、review_schedule.db 与 SP 快照。
  ///
  /// [stamp] 形如 `20261113`（备份文件名中的日期段）。两库都须有对应备份且
  /// 通过完整性校验才执行；任一缺失/损坏即整体拒绝，绝不半恢复。
  /// SP 快照缺失（M3 之前的旧备份）按「仅恢复 db」降级，文案如实说明。
  /// 恢复成功后就地重开双库并复位应用层缓存，无需重启。
  Future<RestoreResult> restoreFromStamp(String stamp) async {
    try {
      final root = (await getApplicationSupportDirectory()).path;
      final backupDir = p.join(root, 'backups');
      final userBackup = p.join(backupDir, 'user_data.db-$stamp.bak');
      final reviewBackup = p.join(backupDir, 'review_schedule.db-$stamp.bak');
      final spBackup = p.join(backupDir, 'sp_prefs-$stamp.json');

      // 先校验两库备份（只读打开 + quick_check），任一不合格即拒绝。
      if (!await UserDataBackupService.validateBackup(userBackup)) {
        return const RestoreResult(success: false, message: '用户库备份缺失或已损坏，无法恢复。');
      }
      if (!await UserDataBackupService.validateBackup(reviewBackup)) {
        return const RestoreResult(success: false, message: '复习库备份缺失或已损坏，无法恢复。');
      }
      // SP 快照先读先校验（在关库之前）：损坏即整体拒绝，绝不动现库。
      final spSnapshot = await UserDataBackupService.readSpSnapshot(spBackup);
      final hasSpSnapshot = spSnapshot != null;

      // 关闭双库句柄（替换文件前必须释放，否则 Windows 文件占用 / 边车撕裂）。
      // M18：close 广播失效——各 DAO 缓存句柄/内存索引随广播作废。
      await UserDatabase.instance.close();
      await closeReviewStore();

      // 安全替换：现库留档 + 边车随行 + 复制备份（见 restoreBackupFile）。
      await UserDataBackupService.restoreBackupFile(backupPath: userBackup, targetDbPath: p.join(root, 'user_data.db'));
      await UserDataBackupService.restoreBackupFile(
        backupPath: reviewBackup,
        targetDbPath: p.join(root, 'review_schedule.db'),
      );

      // M3：SP 快照回放（先清后写、凭证键保留）。失败按恢复失败处理——
      // db 已替换但 SP 未回放 = 不同步态，必须如实告知并引导重试/人工回退。
      if (hasSpSnapshot) {
        final spOk = await UserDataSpRegistry.restore(spSnapshot);
        if (!spOk) {
          return const RestoreResult(success: false, message: '数据库已恢复，但偏好快照写入失败（SP 与库可能不同步）。原数据已留档，请重启后重试或人工回退。');
        }
        // SP 进程级缓存重载：各 BaseSharedPreferences 门面持有的 prefs 实例
        // 与 getInstance 同源，reload 后全部读侧即时看到恢复值。
        final prefs = await SharedPreferences.getInstance();
        await prefs.reload();
      }

      // M18：就地重开双库 + 复位应用层缓存（不再 exit(0)）。
      await UserDatabase.instance.initialize();
      await reopenReviewStore();
      final reset = resetFeatureCaches;
      if (reset != null) {
        try {
          await reset();
        } catch (e, s) {
          // 缓存复位失败不推翻恢复结果：DAO 句柄已是新库，内存态最迟
          // 下次页面刷新自愈；如实上报供观测。
          reportSwallowedError('恢复后应用层缓存复位失败（数据已恢复，UI 可能短暂陈旧）', e, s);
        }
      }

      return RestoreResult(
        success: true,
        message: hasSpSnapshot
            ? '恢复完成，学习进度、收藏、复习计划与偏好设置均已回到备份时刻，无需重启。'
            : '恢复完成（该备份较早，不含偏好快照：仅恢复了学习进度与复习计划，偏好设置保持现状），无需重启。',
      );
    } catch (e) {
      return RestoreResult(success: false, message: '恢复失败：$e\n原数据已留档，可重启后重试或人工回退。');
    }
  }
}
