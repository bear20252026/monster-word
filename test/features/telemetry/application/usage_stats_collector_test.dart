// 使用统计累计与上报决策的行为断言。
//
// 这些断言是**纯 Dart**（被测代码不 import flutter），所以除了 CI，也能在本机
// 用 dart.exe 直接执行 —— 本仓 flutter test 受 365vpn 影响不可用，这一点很重要。
import 'package:flutter_test/flutter_test.dart';

import 'package:word_app/features/telemetry/application/usage_stats_collector.dart';
import 'package:word_app/features/telemetry/application/usage_stats_ports.dart';
import 'package:word_app/features/telemetry/domain/usage_daily_stats.dart';

class _FakeStore implements UsageStatsStore {
  final Map<String, UsageDailyStats> days = {};
  final Set<String> uploaded = {};
  DateTime? lastUploadAt;
  DateTime? nextAttemptAt;
  int clearCount = 0;
  final List<DateTime> prunedBefore = [];

  @override
  Future<UsageDailyStats?> readDay(String day) async => days[day];

  @override
  Future<void> writeDay(UsageDailyStats stats) async => days[stats.day] = stats;

  @override
  Future<List<UsageDailyStats>> readPending({int limit = 31}) async {
    final list = days.values.where((d) => !uploaded.contains(d.day) && d.hasActivity).toList()
      ..sort((a, b) => a.day.compareTo(b.day));
    return list.length > limit ? list.sublist(0, limit) : list;
  }

  @override
  Future<void> markUploaded(Iterable<String> days) async => uploaded.addAll(days);

  @override
  Future<void> pruneUploadedBefore(DateTime before) async => prunedBefore.add(before);

  @override
  Future<DateTime?> readLastUploadAt() async => lastUploadAt;

  @override
  Future<void> writeLastUploadAt(DateTime at) async => lastUploadAt = at;

  @override
  Future<DateTime?> readNextAttemptAt() async => nextAttemptAt;

  @override
  Future<void> writeNextAttemptAt(DateTime? at) async => nextAttemptAt = at;

  @override
  Future<void> clearAll() async {
    clearCount++;
    days.clear();
    uploaded.clear();
  }
}

class _FakeUploader implements UsageStatsUploader {
  _FakeUploader({this.succeed = true});
  bool succeed;
  final List<UsageStatsReport> sent = [];

  @override
  Future<bool> upload(UsageStatsReport report) async {
    sent.add(report);
    return succeed;
  }
}

class _FakeEnvironment implements UsageStatsEnvironment {
  @override
  Future<String> deviceId() async => 'dev-abc';
  @override
  Future<String> appVersion() async => '9.9.9';
  @override
  Future<int> appBuild() async => 999;
  @override
  String platform() => 'windows';
  @override
  String osVersion() => 'test-os';
  @override
  String locale() => 'zh_CN';
}

class _FakeSettings implements UsageStatsSettings {
  _FakeSettings({this.enabled = true});
  bool enabled;

  @override
  Future<bool> isEnabled() async => enabled;
  @override
  Future<void> setEnabled(bool value) async => enabled = value;
}

void main() {
  late _FakeStore store;
  late _FakeUploader uploader;
  late _FakeSettings settings;
  late DateTime now;

  UsageStatsCollector build({bool enabled = true}) {
    settings = _FakeSettings(enabled: enabled);
    store = _FakeStore();
    uploader = _FakeUploader();
    return UsageStatsCollector(
      store: store,
      uploader: uploader,
      environment: _FakeEnvironment(),
      settings: settings,
      clock: () => now,
    );
  }

  setUp(() {
    now = DateTime(2026, 10, 14, 10, 0);
  });

  group('日期键', () {
    test('补零成定长 YYYY-MM-DD（字典序 = 时间序）', () {
      expect(UsageStatsCollector.dayKey(DateTime(2026, 1, 5)), '2026-01-05');
      expect(UsageStatsCollector.dayKey(DateTime(2026, 12, 31)), '2026-12-31');
    });
  });

  group('开关关闭时不收集', () {
    test('各类记录都不落盘', () async {
      final c = build(enabled: false)..initialize();
      await c.initialize();
      await c.onForeground();
      await c.recordModuleOpen('learn');
      await c.recordStudySession();
      await c.recordAnswers(reviewed: 10, correct: 8);
      await c.recordNewWordsLearned(5);
      await c.recordCoinsEarned(3);
      expect(store.days, isEmpty);
    });

    test('maybeUpload 直接跳过', () async {
      final c = build(enabled: false);
      await c.initialize();
      await c.maybeUpload();
      expect(uploader.sent, isEmpty);
    });
  });

  group('前台时长', () {
    test('进入前台计一次启动，重复调用幂等', () async {
      final c = build();
      await c.initialize();
      await c.onForeground();
      await c.onForeground();
      await c.onForeground();
      expect(store.days['2026-10-14']!.sessionCount, 1);
    });

    test('离开前台结算时长', () async {
      final c = build();
      await c.initialize();
      await c.onForeground();
      now = now.add(const Duration(minutes: 30));
      await c.onBackground();
      expect(store.days['2026-10-14']!.foregroundMs, const Duration(minutes: 30).inMilliseconds);
    });

    test('跨午夜按本地午夜切成两天', () async {
      final c = build();
      await c.initialize();
      now = DateTime(2026, 10, 14, 23, 50);
      await c.onForeground();
      now = DateTime(2026, 10, 15, 0, 20);
      await c.onBackground();
      // 14 日 10 分钟 + 15 日 20 分钟
      expect(store.days['2026-10-14']!.foregroundMs, const Duration(minutes: 10).inMilliseconds);
      expect(store.days['2026-10-15']!.foregroundMs, const Duration(minutes: 20).inMilliseconds);
    });

    test('时钟回拨不写负数', () async {
      final c = build();
      await c.initialize();
      now = DateTime(2026, 10, 14, 10, 0);
      await c.onForeground();
      now = DateTime(2026, 10, 14, 9, 0); // 系统时间被往回调
      await c.onBackground();
      final day = store.days['2026-10-14'];
      expect(day, isNotNull);
      expect(day!.foregroundMs, 0);
      expect(day.foregroundMs, greaterThanOrEqualTo(0));
    });
  });

  group('行为计数', () {
    test('模块打开按次累加', () async {
      final c = build();
      await c.initialize();
      await c.recordModuleOpen('learn');
      await c.recordModuleOpen('learn');
      await c.recordModuleOpen('listen');
      expect(store.days['2026-10-14']!.moduleOpenCounts, {'learn': 2, 'listen': 1});
    });

    test('答对数被夹到复习词次以内', () async {
      final c = build();
      await c.initialize();
      await c.recordAnswers(reviewed: 5, correct: 99);
      expect(store.days['2026-10-14']!.wordsCorrect, 5);
    });

    test('词书进度是覆盖写而非累加', () async {
      final c = build();
      await c.initialize();
      await c.syncBookProgress(wordCount: 100, learned: 10);
      await c.syncBookProgress(wordCount: 100, learned: 25);
      expect(store.days['2026-10-14']!.bookLearnedCount, 25);
    });
  });

  group('上报决策（频率是这里的核心）', () {
    test('从没上报过 + 有数据 ⇒ 该报', () async {
      final c = build();
      await c.initialize();
      await c.recordStudySession();
      expect(await c.skipReason(), isNull);
    });

    test('距上次成功不足 24h ⇒ tooSoon（这就是「每日一次」）', () async {
      final c = build();
      await c.initialize();
      await c.recordStudySession();
      store.lastUploadAt = now.subtract(const Duration(hours: 23));
      expect(await c.skipReason(), 'tooSoon');
    });

    test('满 24h ⇒ 该报', () async {
      final c = build();
      await c.initialize();
      await c.recordStudySession();
      store.lastUploadAt = now.subtract(const Duration(hours: 24));
      expect(await c.skipReason(), isNull);
    });

    test('没有未上报数据 ⇒ nothingPending（不为空跑发请求）', () async {
      final c = build();
      await c.initialize();
      expect(await c.skipReason(), 'nothingPending');
    });

    test('在退避期内 ⇒ backoff', () async {
      final c = build();
      await c.initialize();
      await c.recordStudySession();
      store.nextAttemptAt = now.add(const Duration(minutes: 30));
      expect(await c.skipReason(), 'backoff');
    });

    test('上报成功后标记已传、记时间、清退避、清理过期明细', () async {
      final c = build();
      await c.initialize();
      await c.recordStudySession();
      await c.maybeUpload();
      expect(uploader.sent, hasLength(1));
      expect(store.uploaded, contains('2026-10-14'));
      expect(store.lastUploadAt, now);
      expect(store.nextAttemptAt, isNull);
      expect(store.prunedBefore, hasLength(1));
    });

    test('上报失败 ⇒ 写退避，且**不**标记已传（下一轮能补传）', () async {
      final c = build();
      await c.initialize();
      uploader.succeed = false;
      await c.recordStudySession();
      await c.maybeUpload();
      expect(store.uploaded, isEmpty);
      expect(store.lastUploadAt, isNull);
      expect(store.nextAttemptAt, isNotNull);
      expect(store.prunedBefore, isEmpty, reason: '失败时不该动数据');
      // 退避过后仍能补传
      store.nextAttemptAt = null;
      uploader.succeed = true;
      await c.maybeUpload();
      expect(store.uploaded, contains('2026-10-14'));
    });

    test('多天未上报时一次补传（补传不会退化成逐天请求）', () async {
      final c = build();
      await c.initialize();
      for (final day in ['2026-10-11', '2026-10-12', '2026-10-13', '2026-10-14']) {
        await store.writeDay(UsageDailyStats(day: day, foregroundMs: 60000, sessionCount: 1));
      }
      await c.maybeUpload();
      expect(uploader.sent, hasLength(1), reason: '4 天应合成 1 次请求');
      expect(uploader.sent.single.days.map((d) => d.day), ['2026-10-11', '2026-10-12', '2026-10-13', '2026-10-14']);
    });

    test('上报前先结算当前这段前台时长（进程被杀也不丢）', () async {
      final c = build();
      await c.initialize();
      await c.onForeground();
      now = now.add(const Duration(minutes: 15));
      await c.maybeUpload();
      expect(uploader.sent.single.days.single.foregroundMs, const Duration(minutes: 15).inMilliseconds);
    });
  });

  group('关掉开关会清掉本地未上报数据', () {
    test('setEnabled(false) 触发 clearAll', () async {
      final c = build();
      await c.initialize();
      await c.recordStudySession();
      expect(store.days, isNotEmpty);
      await c.setEnabled(false);
      expect(store.clearCount, 1);
      expect(store.days, isEmpty);
    });

    test('关掉后再打开不会把旧数据带回来', () async {
      final c = build();
      await c.initialize();
      await c.recordStudySession();
      await c.setEnabled(false);
      await c.setEnabled(true);
      expect(await c.skipReason(), 'nothingPending');
    });
  });

  group('报文夹紧', () {
    test('无活动的日子被丢弃', () {
      final report = UsageStatsReport(
        deviceId: 'd',
        appVersion: '1',
        appBuild: 1,
        platform: 'windows',
        osVersion: 'o',
        locale: 'zh_CN',
        days: [
          const UsageDailyStats(day: '2026-10-13'),
          UsageDailyStats(day: '2026-10-14', sessionCount: 1),
        ],
      ).sanitized();
      expect(report.days.map((d) => d.day), ['2026-10-14']);
    });

    test('前台时长被夹到 24h 以内', () {
      final clamped = const UsageDailyStats(day: '2026-10-14', foregroundMs: 99999999999).clamped();
      expect(clamped.foregroundMs, UsageDailyStats.maxForegroundMsPerDay);
    });

    test('未知模块标识被白名单丢弃', () {
      final clamped = const UsageDailyStats(day: '2026-10-14', moduleOpenCounts: {'learn': 1, '随便写的中文': 5}).clamped();
      expect(clamped.moduleOpenCounts.keys, ['learn']);
    });

    test('超过单次上限的日子只保留最近 N 天', () {
      // 用真实连续日期，别拼字符串 —— 拼出来的 key 字典序不保证等于时间序，
      // 断言会跟着一起歪。
      final start = DateTime(2026, 9, 1);
      final days = [
        for (var i = 0; i < 40; i++)
          UsageDailyStats(day: UsageStatsCollector.dayKey(start.add(Duration(days: i))), sessionCount: 1),
      ];
      final report = UsageStatsReport(
        deviceId: 'd',
        appVersion: '1',
        appBuild: 1,
        platform: 'windows',
        osVersion: 'o',
        locale: 'zh_CN',
        days: days,
      ).sanitized();
      expect(report.days, hasLength(UsageDailyStats.maxDaysPerReport));
      expect(report.days.first.day, '2026-09-10', reason: '丢掉最早的 9 天');
      expect(report.days.last.day, '2026-10-10', reason: '保留最近的一天');
    });
  });

  group('容错解析', () {
    test('字段类型不对或缺席一律退回默认值，不抛异常', () {
      final parsed = UsageDailyStats.fromJson({'day': '2026-10-14', 'foreground_ms': 'abc', 'session_count': null});
      expect(parsed.day, '2026-10-14');
      expect(parsed.foregroundMs, 0);
      expect(parsed.sessionCount, 0);
    });

    test('JSON 往返保持数值', () {
      const original = UsageDailyStats(
        day: '2026-10-14',
        foregroundMs: 1234,
        sessionCount: 2,
        wordsReviewed: 40,
        wordsCorrect: 33,
        moduleOpenCounts: {'learn': 3},
      );
      final back = UsageDailyStats.fromJson(original.toJson());
      expect(back.foregroundMs, 1234);
      expect(back.wordsReviewed, 40);
      expect(back.wordsCorrect, 33);
      expect(back.moduleOpenCounts, {'learn': 3});
    });
  });
}
