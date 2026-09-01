// 由 Claude 团队生成 | Monster Word App

// REG-REM-001：学习提醒开关真实现——开启时真实申请权限并调度（SnackBar 诚实
// 反馈），权限被拒或调度失败时开关回滚，保证 UI 状态与调度事实一致；
// 旧版开关为空转假语义（切换无任何效果），本测试钉死该假语义不得回归。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:word_app/features/settings/application/study_reminder_service.dart';
import 'package:word_app/features/settings/data/learning_preferences_repository.dart';
import 'package:word_app/features/settings/presentation/learning_preferences_state.dart';
import 'package:word_app/features/settings/presentation/study_reminder_sheet.dart';
import 'package:word_app/theme/skin_system.dart';

class _FakeReminderService implements StudyReminderService {
  _FakeReminderService({this.granted = true, this.throwOnSchedule = false});

  bool granted;
  bool throwOnSchedule;
  int scheduleCount = 0;
  int cancelCount = 0;

  @override
  Future<bool> requestPermission() async => granted;

  @override
  Future<void> scheduleDaily({required int hour, required int minute}) async {
    if (throwOnSchedule) throw StateError('scheduler unavailable');
    scheduleCount++;
  }

  @override
  Future<void> cancelDaily() async => cancelCount++;
}

Future<LearningPreferencesState> _state() async {
  final repo = LearningPreferencesRepository();
  final state = LearningPreferencesState(reader: repo, writer: repo);
  await state.initialize();
  return state;
}

Widget _wrap(LearningPreferencesState preferences, StudyReminderService service) {
  return SkinProvider(
    skin: SkinSystem(),
    child: MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () => showStudyReminderSheet(context, preferences: preferences, service: service),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
}

Finder _switchOf(String title) => find.descendant(
  of: find.ancestor(of: find.text(title), matching: find.byType(Row)),
  matching: find.byType(Switch),
);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('REG-REM-001a: 开启系统提醒 → 真实调度并诚实提示，时间行解除置灰', (tester) async {
    final service = _FakeReminderService();
    final preferences = await _state();
    await tester.pumpWidget(_wrap(preferences, service));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // 默认关闭，时间行置灰。
    expect(preferences.systemReminder, isFalse);

    await tester.tap(_switchOf('系统提醒'));
    await tester.pumpAndSettle();

    // 真实调度一次 + 开关保持开启 + SnackBar 诚实反馈。
    expect(service.scheduleCount, 1);
    expect(preferences.systemReminder, isTrue);
    expect(find.text('已开启每日 20:00 提醒'), findsOneWidget);
  });

  testWidgets('REG-REM-001b: 权限被拒 → 开关回滚为关，不调度', (tester) async {
    final service = _FakeReminderService(granted: false);
    final preferences = await _state();
    await tester.pumpWidget(_wrap(preferences, service));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(_switchOf('系统提醒'));
    await tester.pumpAndSettle();

    expect(service.scheduleCount, 0);
    expect(preferences.systemReminder, isFalse);
    expect(find.text('通知权限被拒绝，请到系统设置开启通知'), findsOneWidget);
  });

  testWidgets('REG-REM-001c: 调度失败 → 开关回滚为关并诚实提示', (tester) async {
    final service = _FakeReminderService(throwOnSchedule: true);
    final preferences = await _state();
    await tester.pumpWidget(_wrap(preferences, service));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(_switchOf('系统提醒'));
    await tester.pumpAndSettle();

    expect(preferences.systemReminder, isFalse);
    expect(find.textContaining('提醒设置失败'), findsOneWidget);
  });

  testWidgets('REG-REM-001d: 关闭系统提醒 → 真实取消调度', (tester) async {
    final service = _FakeReminderService();
    final preferences = await _state();
    await preferences.setSystemReminder(true);
    await tester.pumpWidget(_wrap(preferences, service));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(_switchOf('系统提醒'));
    await tester.pumpAndSettle();

    expect(service.cancelCount, 1);
    expect(preferences.systemReminder, isFalse);
    expect(find.text('已关闭每日学习提醒'), findsOneWidget);
  });
}
