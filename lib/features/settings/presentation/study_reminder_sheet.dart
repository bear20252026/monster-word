// 学习提醒弹窗：微信提醒开关（遗留假语义，待用户决策）+ 系统提醒真调度 + 提醒时间选择。
// 系统提醒走 StudyReminderService（flutter_local_notifications），失败诚实提示。
import 'package:flutter/material.dart';

import 'package:word_app/features/settings/application/study_reminder_service.dart';
import 'package:word_app/features/settings/domain/reminder_time.dart';
import 'package:word_app/features/settings/presentation/learning_preferences_state.dart';
import 'package:word_app/features/settings/presentation/settings_bottom_sheet.dart';
import 'package:word_app/theme/skin_system.dart';

Future<void> showStudyReminderSheet(
  BuildContext context, {
  required LearningPreferencesState preferences,
  required StudyReminderService service,
}) {
  return showSettingsBottomSheet(
    context,
    title: '学习提醒',
    child: StatefulBuilder(
      builder: (ctx, setSheetState) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SettingsSheetSwitchRow(
            title: '微信提醒',
            value: preferences.wechatReminder,
            onChanged: (v) async {
              await preferences.setWechatReminder(v);
              if (ctx.mounted) setSheetState(() {});
            },
          ),
          SettingsSheetSwitchRow(
            title: '系统提醒',
            value: preferences.systemReminder,
            onChanged: (v) async {
              final message = await _applySystemReminder(preferences, service, v);
              if (ctx.mounted) setSheetState(() {});
              if (ctx.mounted && message != null) {
                ScaffoldMessenger.maybeOf(ctx)?.showSnackBar(SnackBar(content: Text(message)));
              }
            },
          ),
          _SheetTimeRow(
            title: '提醒时间',
            value: preferences.reminderTime,
            enabled: preferences.systemReminder,
            onTap: () => _pickReminderTime(
              ctx,
              preferences: preferences,
              service: service,
              onChanged: () {
                if (ctx.mounted) setSheetState(() {});
              },
            ),
          ),
        ],
      ),
    ),
  );
}

/// 开/关系统提醒：权限申请 + 调度/取消，返回提示语（null 不提示）。
/// 权限被拒时回滚开关，保证开关状态与事实一致。
Future<String?> _applySystemReminder(
  LearningPreferencesState preferences,
  StudyReminderService service,
  bool enabled,
) async {
  await preferences.setSystemReminder(enabled);
  if (!enabled) {
    await service.cancelDaily();
    return '已关闭每日学习提醒';
  }
  final granted = await service.requestPermission();
  if (!granted) {
    await preferences.setSystemReminder(false);
    return '通知权限被拒绝，请到系统设置开启通知';
  }
  final (hour, minute) = parseReminderTime(preferences.reminderTime);
  try {
    await service.scheduleDaily(hour: hour, minute: minute);
  } catch (error) {
    await preferences.setSystemReminder(false);
    return '提醒设置失败：$error';
  }
  return '已开启每日 ${preferences.reminderTime} 提醒';
}

/// 选择提醒时间（24 小时制），改动后若系统提醒开启则以新时间重新调度。
Future<void> _pickReminderTime(
  BuildContext context, {
  required LearningPreferencesState preferences,
  required StudyReminderService service,
  required VoidCallback onChanged,
}) async {
  final (hour, minute) = parseReminderTime(preferences.reminderTime);
  final picked = await showTimePicker(
    context: context,
    initialTime: TimeOfDay(hour: hour, minute: minute),
  );
  if (!context.mounted || picked == null) return;
  final value = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
  await preferences.setReminderTime(value);
  if (!context.mounted) return;
  if (preferences.systemReminder) {
    try {
      await service.scheduleDaily(hour: picked.hour, minute: picked.minute);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text('提醒设置失败：$error')));
        return;
      }
    }
  }
  onChanged();
}

/// 弹窗提醒时间行（系统提醒关闭时置灰不可点）。
class _SheetTimeRow extends StatelessWidget {
  final String title;
  final String value;
  final bool enabled;
  final VoidCallback onTap;
  const _SheetTimeRow({required this.title, required this.value, required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final skin = context.skin.colors;
    return GestureDetector(
      onTap: enabled ? onTap : null,
      behavior: HitTestBehavior.opaque,
      child: Opacity(
        opacity: enabled ? 1.0 : 0.45,
        child: SizedBox(
          height: 52,
          child: Row(
            children: [
              Expanded(
                child: Text(title, style: TextStyle(fontSize: 15, color: enabled ? skin.text1 : skin.text3)),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(value, style: TextStyle(fontSize: 14, color: skin.accent)),
              ),
              Icon(Icons.chevron_right, size: 20, color: skin.text3),
            ],
          ),
        ),
      ),
    );
  }
}
