// 学习提醒本地通知服务单测：Fake 插件替身，验证调度时刻计算与幂等取消。
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'package:word_app/features/settings/data/local_study_reminder_service.dart';

/// 插件主类为工厂单例（私有构造，不可继承），用 implements + noSuchMethod 兜底。
class _FakePlugin implements FlutterLocalNotificationsPlugin {
  InitializationSettings? initSettings;
  ({int id, tz.TZDateTime scheduledDate, AndroidScheduleMode mode, DateTimeComponents? match})? lastSchedule;
  int cancelCount = 0;

  @override
  Future<bool?> initialize({
    required InitializationSettings settings,
    DidReceiveNotificationResponseCallback? onDidReceiveNotificationResponse,
    DidReceiveBackgroundNotificationResponseCallback? onDidReceiveBackgroundNotificationResponse,
  }) async {
    initSettings = settings;
    return true;
  }

  @override
  Future<void> zonedSchedule({
    required int id,
    required tz.TZDateTime scheduledDate,
    required NotificationDetails notificationDetails,
    required AndroidScheduleMode androidScheduleMode,
    String? title,
    String? body,
    String? payload,
    DateTimeComponents? matchDateTimeComponents,
  }) async {
    lastSchedule = (id: id, scheduledDate: scheduledDate, mode: androidScheduleMode, match: matchDateTimeComponents);
  }

  @override
  Future<void> cancel({required int id, String? tag}) async {
    cancelCount++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

LocalStudyReminderService _service(_FakePlugin plugin, DateTime now) =>
    LocalStudyReminderService(pluginOverride: plugin, timezoneNameOverride: 'UTC', nowOverride: now);

void main() {
  setUpAll(() {
    tzdata.initializeTimeZones();
  });

  test('scheduleDaily：今天未到提醒时刻 → 排今天，每日重复匹配', () async {
    final plugin = _FakePlugin();
    final service = _service(plugin, DateTime(2026, 9, 2, 10, 0)); // UTC 10:00

    await service.scheduleDaily(hour: 20, minute: 0);

    expect(plugin.lastSchedule, isNotNull);
    expect(plugin.lastSchedule!.id, 1001);
    expect(plugin.lastSchedule!.scheduledDate.isAtSameMomentAs(tz.TZDateTime(tz.UTC, 2026, 9, 2, 20, 0)), isTrue);
    expect(plugin.lastSchedule!.mode, AndroidScheduleMode.inexactAllowWhileIdle);
    expect(plugin.lastSchedule!.match, DateTimeComponents.time);
  });

  test('scheduleDaily：今天已过提醒时刻 → 排明天', () async {
    final plugin = _FakePlugin();
    final service = _service(plugin, DateTime(2026, 9, 2, 21, 0));

    await service.scheduleDaily(hour: 20, minute: 0);

    expect(plugin.lastSchedule!.scheduledDate.isAtSameMomentAs(tz.TZDateTime(tz.UTC, 2026, 9, 3, 20, 0)), isTrue);
  });

  test('scheduleDaily 重复调用 → 以同一 id 覆盖（幂等，不产生重复提醒）', () async {
    final plugin = _FakePlugin();
    final service = _service(plugin, DateTime(2026, 9, 2, 10, 0));

    await service.scheduleDaily(hour: 20, minute: 0);
    await service.scheduleDaily(hour: 7, minute: 30);

    expect(plugin.lastSchedule!.id, 1001);
    expect(plugin.lastSchedule!.scheduledDate.isAtSameMomentAs(tz.TZDateTime(tz.UTC, 2026, 9, 3, 7, 30)), isTrue);
  });

  test('cancelDaily：从未调度过 → 不调用插件取消', () async {
    final plugin = _FakePlugin();
    final service = _service(plugin, DateTime(2026, 9, 2, 10, 0));

    await service.cancelDaily();

    expect(plugin.cancelCount, 0);
  });

  test('cancelDaily：已调度 → 取消一次', () async {
    final plugin = _FakePlugin();
    final service = _service(plugin, DateTime(2026, 9, 2, 10, 0));

    await service.scheduleDaily(hour: 20, minute: 0);
    await service.cancelDaily();

    expect(plugin.cancelCount, 1);
  });

  test('非 Android 平台 requestPermission → 直接视为已授权', () async {
    final plugin = _FakePlugin();
    final service = _service(plugin, DateTime(2026, 9, 2, 10, 0));

    expect(await service.requestPermission(), isTrue);
  });
}
