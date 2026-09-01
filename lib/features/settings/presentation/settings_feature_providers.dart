import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:word_app/features/settings/application/network_diagnosis_service.dart';
import 'package:word_app/features/settings/application/study_reminder_service.dart';
import 'package:word_app/features/settings/data/io_network_diagnosis_service.dart';
import 'package:word_app/features/settings/data/local_study_reminder_service.dart';
import 'package:word_app/features/settings/data/learning_preferences_repository.dart';
import 'package:word_app/features/settings/domain/reminder_time.dart';
import 'package:word_app/features/settings/presentation/learning_preferences_state.dart';

/// 为设置功能创建一个 MultiProvider 作用域。
///
/// 该作用域在 App 生命周期内仅初始化一次（见 [MaterialApp.builder]），
/// 并通过 [InheritedProvider] 将当前学习偏好状态下发给设置功能域内的所有子树。
Widget buildSettingsFeatureScope({required Widget child}) {
  final repository = LearningPreferencesRepository();
  return MultiProvider(
    providers: [
      Provider<LearningPreferencesRepository>.value(value: repository),
      // 网络诊断：真实 dart:io 检测（DNS + HTTP 可达性）。
      Provider<NetworkDiagnosisService>(create: (_) => IoNetworkDiagnosisService()),
      // 学习提醒：本地通知真实现（Android + Windows）。
      Provider<StudyReminderService>(create: (_) => LocalStudyReminderService()),
      ChangeNotifierProvider<LearningPreferencesState>(
        create: (_) => LearningPreferencesState(reader: repository, writer: repository),
      ),
    ],
    child: _SettingsFeatureInitializer(child: child),
  );
}

/// 在首帧之后触发偏好加载，避免在 build 阶段调用 notifyListeners。
class _SettingsFeatureInitializer extends StatefulWidget {
  const _SettingsFeatureInitializer({required this.child});
  final Widget child;

  @override
  State<_SettingsFeatureInitializer> createState() => _SettingsFeatureInitializerState();
}

class _SettingsFeatureInitializerState extends State<_SettingsFeatureInitializer> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final state = context.read<LearningPreferencesState>();
      state.initialize().then((_) => _rescheduleIfEnabled(state));
    });
  }

  /// 启动幂等补挂：系统提醒已开启但本地调度可能因重启丢失（Android 重启
  /// 由 ScheduledNotificationBootReceiver 恢复，桌面端无此机制），
  /// 以同一通知 id 重复调度等价于更新，不会产生重复提醒。
  Future<void> _rescheduleIfEnabled(LearningPreferencesState state) async {
    if (!state.systemReminder) return;
    final (hour, minute) = parseReminderTime(state.reminderTime);
    try {
      await context.read<StudyReminderService>().scheduleDaily(hour: hour, minute: minute);
    } catch (_) {
      // 补挂失败静默：用户下次进入设置页开关时会看到诚实提示并重试。
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
