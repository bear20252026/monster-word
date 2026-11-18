// 第四轮审计 M4（2026-11-18）：共享会话完成报告器单测。
//
// 报告器从 LearningSessionState / ReviewSessionState 的同构上报收敛而来，
// 这里整表驱动验证：答对数口径、一局一报幂等、reset 清闸、正确率任务 floor、
// 无答题不判定、空端口静默。两会话页的集成行为另由各自 state_test 守卫。
import 'package:flutter_test/flutter_test.dart';
import 'package:word_app/features/learning/application/session_completion_reporter.dart';
import 'package:word_app/features/missions/application/daily_mission_repository.dart';
import 'package:word_app/features/missions/application/daily_mission_store.dart';

import '../../telemetry/test_helpers/spy_usage_stats_recorder.dart';

class _MemoryRepository implements DailyMissionRepository {
  final Map<String, Map<DailyMissionId, DailyMissionRecord>> rows = {};

  @override
  Future<Map<DailyMissionId, DailyMissionRecord>> load(String day) async =>
      Map<DailyMissionId, DailyMissionRecord>.from(rows[day] ?? const {});

  @override
  Future<void> save(String day, DailyMissionId id, DailyMissionRecord record) async {
    rows.putIfAbsent(day, () => {})[id] = record;
  }
}

/// 等 unawaited 的埋点/任务写落定（内存假件均为微任务级）。
Future<void> _flush() => Future<void>.delayed(Duration.zero);

void main() {
  late _MemoryRepository repo;
  late DateTime now;

  DailyMissionStore buildStore() => DailyMissionStore(repository: repo, clock: () => now);

  int accuracyProgress(DailyMissionStore store) =>
      store.missions.firstWhere((m) => m.definition.id == DailyMissionId.sessionAccuracy).progress;

  setUp(() {
    repo = _MemoryRepository();
    now = DateTime(2026, 11, 18, 9);
  });

  test('上报一次：会话数+1，答对数=答数-错数（钳制），正确率任务按 floor 登记', () async {
    final spy = SpyUsageStatsRecorder();
    final store = buildStore();
    await store.ensureLoaded(dueNow: 0);
    final reporter = SessionCompletionReporter(usageStats: spy, dailyMissions: store);

    reporter.report(answered: 3, wrong: 1);
    await _flush();

    expect(spy.studySessions, 1);
    expect(spy.reviewed, 3);
    expect(spy.correct, 2);
    expect(accuracyProgress(store), 66); // (2/3*100).floor()=66
    expect(reporter.hasReported, isTrue);
  });

  test('幂等：同一局重复 report 只生效一次（走完队列与中途收工共用触发点）', () async {
    final spy = SpyUsageStatsRecorder();
    final reporter = SessionCompletionReporter(usageStats: spy);

    reporter.report(answered: 5, wrong: 0);
    reporter.report(answered: 5, wrong: 0);
    reporter.report(answered: 9, wrong: 1); // 即便参数不同也被幂等闸挡下
    await _flush();

    expect(spy.studySessions, 1);
    expect(spy.reviewed, 5);
    expect(spy.correct, 5);
  });

  test('reset 清闸：开新局后可再上报一次', () async {
    final spy = SpyUsageStatsRecorder();
    final reporter = SessionCompletionReporter(usageStats: spy);

    reporter.report(answered: 2, wrong: 0);
    await _flush();
    expect(reporter.hasReported, isTrue);

    reporter.reset();
    expect(reporter.hasReported, isFalse);
    reporter.report(answered: 4, wrong: 1);
    await _flush();

    expect(spy.studySessions, 2);
    expect(spy.reviewed, 6); // 2 + 4
    expect(spy.correct, 5); // 2 + 3
  });

  test('无答题（answered=0）：仍记会话与 0 词次，但正确率任务不判定（null）', () async {
    final spy = SpyUsageStatsRecorder();
    final store = buildStore();
    await store.ensureLoaded(dueNow: 0);
    final reporter = SessionCompletionReporter(usageStats: spy, dailyMissions: store);

    reporter.report(answered: 0, wrong: 0);
    await _flush();

    expect(spy.studySessions, 1);
    expect(spy.reviewed, 0);
    expect(spy.correct, 0);
    expect(accuracyProgress(store), 0); // sessionAccuracyPercent(0,..)=null，不登记
  });

  test('错数大于答数：答对数钳到 0，正确率 0', () async {
    final spy = SpyUsageStatsRecorder();
    final store = buildStore();
    await store.ensureLoaded(dueNow: 0);
    final reporter = SessionCompletionReporter(usageStats: spy, dailyMissions: store);

    reporter.report(answered: 2, wrong: 5);
    await _flush();

    expect(spy.correct, 0); // (2-5).clamp(0,2)=0
    expect(accuracyProgress(store), 0);
  });

  test('全对：正确率 100，任务达成', () async {
    final store = buildStore();
    await store.ensureLoaded(dueNow: 0);
    final reporter = SessionCompletionReporter(dailyMissions: store);

    reporter.report(answered: 4, wrong: 0);
    await _flush();

    expect(accuracyProgress(store), 100);
    final accuracy = store.missions.firstWhere((m) => m.definition.id == DailyMissionId.sessionAccuracy);
    expect(accuracy.completed, isTrue);
  });

  test('空端口：无埋点无任务时静默，不抛异常', () async {
    final reporter = SessionCompletionReporter();
    reporter.report(answered: 3, wrong: 1);
    await _flush();
    expect(reporter.hasReported, isTrue);
  });
}
