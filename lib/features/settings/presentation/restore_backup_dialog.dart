// P2-12（架构审计 2026-11-12）：从自动备份恢复用户数据的对话框。
//
// 从 more_settings_page 抽出为独立 widget（守 900 行 part 家族聚合上限）。
// 范式对齐词库重建对话框：选择备份 → 二次确认 → 不可取消进度 → 结果弹窗。
// 恢复经应用层 UserDataMaintenanceService 编排（关闭双库 → 校验 → 安全替换
// → SP 快照回放 → 重开双库 → 应用层缓存复位）。
//
// 第四轮审计 M18（2026-11-17）：恢复成功后**不再强制 exit(0)**——库关闭
// 广播已让各 DAO 作废缓存句柄，维护服务就地重开双库并经复位总线刷新
// Provider 树内存态，用户点「好的」即回到已恢复的数据，无需重启。
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:word_app/core/application/user_data_maintenance_service.dart';
import 'package:word_app/theme/skin_system.dart';
import 'package:word_app/widgets/common/mw_feedback.dart';

/// 弹出备份恢复流程（选择 → 确认 → 进度 → 结果）。
Future<void> showRestoreBackupDialog(BuildContext context) async {
  final service = context.read<UserDataMaintenanceService>();
  final backups = await service.listBackups();
  if (!context.mounted) return;

  // 只列出用户库备份（恢复以 user_data.db 的日期戳为准，复习库同戳配套）。
  final userBackups = backups.where((b) => '${b['name']}'.startsWith('user_data.db-')).toList();
  if (userBackups.isEmpty) {
    showMwSnackBar(context, const SnackBar(content: Text('暂无可用备份。应用会每日自动备份，请稍后再试。')));
    return;
  }

  final stamp = await showDialog<String>(
    context: context,
    builder: (ctx) => SimpleDialog(
      title: const Text('选择要恢复的备份'),
      children: [
        for (final b in userBackups)
          SimpleDialogOption(
            onPressed: () {
              final name = '${b['name']}';
              // user_data.db-YYYYMMDD.bak → YYYYMMDD
              final s = name.replaceFirst('user_data.db-', '').replaceFirst('.bak', '');
              Navigator.pop(ctx, s);
            },
            child: Text('${b['name']}（${b['bytes']} 字节）'),
          ),
      ],
    ),
  );
  if (stamp == null || !context.mounted) return;

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('确认恢复'),
      content: Text('将用 $stamp 的备份覆盖当前学习进度、收藏、复习计划与偏好设置。当前数据会先留档。确定继续吗？'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('立即恢复')),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;

  final rootNavigator = Navigator.of(context, rootNavigator: true);
  unawaited(
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const PopScope(canPop: false, child: Center(child: CircularProgressIndicator())),
    ),
  );

  RestoreResult result;
  try {
    result = await service.restoreFromStamp(stamp);
  } catch (e) {
    result = RestoreResult(success: false, message: '恢复失败: $e');
  }
  rootNavigator.pop();
  if (!context.mounted) return;
  // M18：成功与失败都可正常关闭——成功时数据已就地生效（双库重开 + 缓存
  // 复位），失败时原数据已留档、现库未被破坏性覆盖（校验前置）。
  unawaited(
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(
          result.success ? Icons.check_circle_outline : Icons.error_outline,
          color: result.success ? ctx.skin.colors.success : ctx.skin.colors.danger,
          size: 48,
        ),
        title: Text(result.success ? '恢复成功' : '恢复失败'),
        content: Text(result.message),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('好的'))],
      ),
    ),
  );
}
