import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'package:word_app/features/settings/application/study_reminder_service.dart';
import 'package:word_app/features/settings/domain/reminder_time.dart';

/// 学习提醒的本地通知真实现（Android + Windows，随主包默认实现分发）。
///
/// - Android：AlarmManager 每日提醒（inexactAllowWhileIdle，免精确闹钟权限），
///   POST_NOTIFICATIONS 运行时权限在 [requestPermission] 申请。
/// - Windows：toast 通知；未打包 MSIX 时系统能力受限（取消/查询可能无效），
///   调度失败由调用方 try/catch 诚实提示。
class LocalStudyReminderService implements StudyReminderService {
  LocalStudyReminderService({
    @visibleForTesting this.pluginOverride,
    @visibleForTesting this.timezoneNameOverride,
    @visibleForTesting this.nowOverride,
  });

  /// 测试注入插件替身（避免平台通道）。
  final FlutterLocalNotificationsPlugin? pluginOverride;

  /// 测试注入 IANA 时区名（跳过 flutter_timezone 平台通道）。
  final String? timezoneNameOverride;

  /// 测试注入"当前时间"，验证下一次触发时刻计算。
  final DateTime? nowOverride;

  static const int _notificationId = 1001;
  static const String _channelId = 'study_reminder';
  static const String _channelName = '学习提醒';

  FlutterLocalNotificationsPlugin? _plugin;
  bool _initialized = false;

  FlutterLocalNotificationsPlugin get _client => pluginOverride ?? (_plugin ??= FlutterLocalNotificationsPlugin());

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    tzdata.initializeTimeZones();
    await _ensureLocalLocation();
    final settings = switch (defaultTargetPlatform) {
      TargetPlatform.android => const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      TargetPlatform.windows => const InitializationSettings(
        windows: WindowsInitializationSettings(
          appName: 'Monster Word',
          appUserModelId: 'com.monsterword.word_app',
          guid: '7C1E4F2A-9B6D-4E53-A1C8-52F0B7D9E4A1',
        ),
      ),
      _ => const InitializationSettings(),
    };
    await _client.initialize(settings: settings);
    _initialized = true;
  }

  /// 优先 flutter_timezone 原生取本地时区；平台不支持（如部分桌面）时
  /// 回退到 UTC 固定偏移的 Etc/GMT±N，保证调度永远可用。
  Future<void> _ensureLocalLocation() async {
    try {
      final name = timezoneNameOverride ?? (await FlutterTimezone.getLocalTimezone()).identifier;
      tz.setLocalLocation(tz.getLocation(name));
    } catch (_) {
      final offset = (nowOverride ?? DateTime.now()).timeZoneOffset;
      final hours = offset.inHours;
      final name = hours == 0 ? 'UTC' : 'Etc/GMT-${hours > 0 ? -hours : '+${-hours}'}';
      final location = tz.getLocation(name);
      tz.setLocalLocation(location);
    }
  }

  @override
  Future<bool> requestPermission() async {
    if (defaultTargetPlatform != TargetPlatform.android) return true;
    await _ensureInitialized();
    final android = _client.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return true;
    final granted = await android.requestNotificationsPermission();
    // Android 12 及以下无需运行时权限，插件返回 null，视为已授权。
    return granted ?? true;
  }

  @override
  Future<void> scheduleDaily({required int hour, required int minute}) async {
    await _ensureInitialized();
    final now = nowOverride ?? DateTime.now();
    final next = nextReminderOccurrence(now, hour, minute);
    final scheduled = tz.TZDateTime(tz.local, next.year, next.month, next.day, next.hour, next.minute);
    await _client.zonedSchedule(
      id: _notificationId,
      title: '该背单词啦',
      body: '今天的单词还没背完，坚持就是胜利！',
      scheduledDate: scheduled,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: '每日定时提醒背单词',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  @override
  Future<void> cancelDaily() async {
    if (!_initialized) return; // 从未调度过，无需取消
    await _client.cancel(id: _notificationId);
  }
}
