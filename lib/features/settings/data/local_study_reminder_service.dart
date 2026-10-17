import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'package:word_app/features/settings/application/study_reminder_service.dart';
import 'package:word_app/features/settings/domain/reminder_time.dart';

/// 学习提醒的本地通知真实现（Android + Windows + iOS，随主包默认实现分发）。
///
/// - Android：AlarmManager 每日提醒（inexactAllowWhileIdle，免精确闹钟权限），
///   POST_NOTIFICATIONS 运行时权限在 [requestPermission] 申请。
/// - Windows：toast 通知；未打包 MSIX 时系统能力受限（取消/查询可能无效），
///   调度失败由调用方 try/catch 诚实提示。
/// - iOS（2026-10-17 补）：UNUserNotificationCenter；初始化时**不**自动申请权限
///   （交给 [requestPermission]），且 `zonedSchedule` 必须带 darwin 详情才显示。
///   ⚠️ 仍缺一步：`ios/Runner/AppDelegate.swift` 需设置
///   `UNUserNotificationCenter.current().delegate`，否则**前台**收到通知不呈现。
///   那一步只能在 macOS 上改并验证，本机做不到，已记为 iOS 上线前待办。
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
      // iOS（2026-10-17 补）：此前落到 `_ =>` 空设置 ⇒ initialize 不带 darwin
      // 配置，插件在 iOS 上拿不到 UNUserNotificationCenter 的 delegate，
      // 调度出去的提醒**不会显示**，而 requestPermission 又对非 Android 直接
      // 返回 true ⇒ 界面显示「已开启」、实际永远收不到。三个 request*Permission
      // 一律传 false：授权时机交给 requestPermission()，避免初始化即弹窗。
      TargetPlatform.iOS => const InitializationSettings(
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
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
      // 错误处理审计 P2：POSIX Etc/GMT 区域名为反号（UTC+8 → Etc/GMT-8），
      // 此前 hours>0 分支会生成 "Etc/GMT--8" 这类非法名，
      // 让 getLocation 在 catch 块内再抛 LocationException 逃逸到调用方。
      final offset = (nowOverride ?? DateTime.now()).timeZoneOffset;
      final hours = offset.inHours;
      final name = hours == 0 ? 'UTC' : (hours > 0 ? 'Etc/GMT-$hours' : 'Etc/GMT+${-hours}');
      try {
        tz.setLocalLocation(tz.getLocation(name));
      } catch (_) {
        // 半小时时区等被 inHours 截断后理论上仍可能产生未知名，最终兜底 UTC
        tz.setLocalLocation(tz.UTC);
      }
    }
  }

  @override
  Future<bool> requestPermission() async {
    // iOS（2026-10-17 补）：必须真的申请一次授权，否则 zonedSchedule 排进去的
    // 提醒会被系统静默丢弃。此前这里对非 Android 一律 `return true`，
    // 等于对 iOS 谎报「已授权」。
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      await _ensureInitialized();
      final ios = _client.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      if (ios == null) return false;
      final granted = await ios.requestPermissions(alert: true, badge: true, sound: true);
      return granted ?? false;
    }
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
        // iOS 必须给 Darwin 详情，否则前台/锁屏都不呈现（与 Android 分支不同，
        // 这里不是可选项）。注意 v22 的参数位叫 `iOS:`，类名才是 `Darwin*`。
        iOS: DarwinNotificationDetails(presentAlert: true, presentBanner: true, presentSound: true, presentBadge: true),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  @override
  Future<void> cancelDaily() async {
    // MW-53：OS 侧是否存在本应用的通知与「当前 Dart 实例是否初始化过」是
    // 两件事——应用昨天调度了提醒、今天新实例尚未 scheduleDaily，原实现
    // 直接 return 会让系统通知永远无法被取消。改为幂等初始化后必发 cancel
    // （无通知时 cancel 本身是 no-op，幂等安全）。
    await _ensureInitialized();
    await _client.cancel(id: _notificationId);
  }
}
