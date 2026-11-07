import 'package:flutter/foundation.dart';

import 'package:word_app/features/missions/application/daily_mission_repository.dart';
import 'package:word_app/features/missions/domain/daily_mission.dart';

// 跨功能消费方（learning 等）只允许 import 本 application 层（架构守卫 R4），
// 因此在这里转出任务口径/枚举，避免它们直接触 domain 层。
export 'package:word_app/features/missions/domain/daily_mission.dart';

/// 单条任务的展示快照（UI 只消费这个，不碰持久化细节）。
class DailyMissionView {
  const DailyMissionView({
    required this.definition,
    required this.progress,
    required this.target,
    required this.completed,
    required this.rewardClaimed,
  });

  final DailyMissionDefinition definition;
  final int progress;
  final int? target;
  final bool completed;
  final bool rewardClaimed;

  DailyMissionId get id => definition.id;

  String get progressLabel {
    final t = target;
    if (definition.id == DailyMissionId.sessionAccuracy) {
      return progress <= 0 ? '还没开局' : '最高 $progress%';
    }
    if (t == null) return '今日无到期词';
    return '$progress/$t';
  }
}

/// 每日任务状态（D1/D2）。
///
/// 单一事实源：三条任务的当日进度都写进 `daily_missions`，会话侧只调
/// [recordNewWordLearned] / [recordReviewedWord] / [recordSessionAccuracyPercent]。
/// 发币不在这里做（本类不依赖币账本），由 `DailyMissionRewardService` 结算。
class DailyMissionStore extends ChangeNotifier {
  DailyMissionStore({required this.repository, DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final DailyMissionRepository repository;
  final DateTime Function() _clock;

  String? _day;
  Map<DailyMissionId, DailyMissionRecord> _records = {};
  int? _reviewTarget;
  bool _loaded = false;

  /// 串行闸：学习/复习会话的进度回调是 unawaited 的，读改写必须排队，
  /// 否则两条 +1 可能同读旧值（丢进度）。
  Future<void> _writeQueue = Future<void>.value();

  Future<T> _serialized<T>(Future<T> Function() action) {
    final run = _writeQueue.then((_) => action());
    _writeQueue = run.then<void>((_) {}, onError: (Object _) {});
    return run;
  }

  bool get loaded => _loaded;

  String get day => _day ?? dailyMissionDayKey(_clock());

  /// 今日三条任务的展示数据（顺序固定）。
  List<DailyMissionView> get missions {
    final definitions = dailyMissionDefinitions(reviewTarget: _reviewTarget);
    return [for (final definition in definitions) _viewFor(definition)];
  }

  DailyMissionView _viewFor(DailyMissionDefinition definition) {
    final record = _records[definition.id] ?? const DailyMissionRecord();
    final target = switch (definition.id) {
      DailyMissionId.learnNew => dailyLearnNewWordsTarget,
      DailyMissionId.reviewDue => _reviewTarget,
      DailyMissionId.sessionAccuracy => dailyAccuracyTargetPercent,
    };
    final completed = record.completedAt != null || isDailyMissionComplete(progress: record.progress, target: target);
    return DailyMissionView(
      definition: definition,
      progress: record.progress,
      target: target,
      completed: completed,
      rewardClaimed: record.rewardClaimedAt != null,
    );
  }

  int _progressOf(DailyMissionId id) => (_records[id] ?? const DailyMissionRecord()).progress;

  int get completedCount => missions.where((m) => m.completed).length;

  bool get allCompleted => completedCount == DailyMissionId.values.length;

  int get claimedCount => missions.where((m) => m.rewardClaimed).length;

  int get dayCoinCap => dailyMissionDailyCoinCap;

  List<DailyMissionView> get completedUnclaimed =>
      missions.where((m) => m.completed && !m.rewardClaimed).toList(growable: false);

  /// 加载当天任务并刷新复习目标。可重复调用（同一天命中缓存）。
  Future<void> ensureLoaded({required int dueNow}) {
    return _serialized(() async {
      final changed = await _reloadIfDayChanged();
      final completedChanged = await _refreshTargetAndCompletion(dueNow: dueNow);
      if (changed || completedChanged) notifyListeners();
    });
  }

  /// 只刷新「到期数」→ 复习目标（首页每次到期数变化时调用）。
  Future<void> refreshDue({required int dueNow}) {
    return _serialized(() async {
      final changed = await _reloadIfDayChanged();
      final completedChanged = await _refreshTargetAndCompletion(dueNow: dueNow);
      if (changed || completedChanged) notifyListeners();
    });
  }

  Future<void> recordNewWordLearned() => _recordProgress(DailyMissionId.learnNew, delta: 1);

  Future<void> recordReviewedWord() => _recordProgress(DailyMissionId.reviewDue, delta: 1);

  /// 正确率任务记录「当日最高正确率」；低于历史最高时不变。
  Future<void> recordSessionAccuracyPercent(int percent) {
    final value = percent.clamp(0, 100);
    return _serialized(() async {
      await _reloadIfDayChanged();
      final record = _records[DailyMissionId.sessionAccuracy] ?? const DailyMissionRecord();
      if (value <= record.progress) return;
      var next = record.copyWith(progress: value);
      if (isDailyMissionComplete(progress: value, target: dailyAccuracyTargetPercent)) {
        next = next.copyWith(completedAt: _clock());
      }
      await _persist(DailyMissionId.sessionAccuracy, next);
      notifyListeners();
    });
  }

  /// 发币成功/已发过之后落「已结算」标记。
  Future<void> markRewardClaimed(DailyMissionId id) {
    return _serialized(() async {
      final record = _records[id] ?? const DailyMissionRecord();
      if (record.rewardClaimedAt != null) return;
      await _persist(id, record.copyWith(rewardClaimedAt: _clock()));
      notifyListeners();
    });
  }

  Future<void> _recordProgress(DailyMissionId id, {required int delta}) {
    return _serialized(() async {
      await _reloadIfDayChanged();
      final record = _records[id] ?? const DailyMissionRecord();
      final next = record.copyWith(progress: record.progress + delta);
      final target = _targetFor(id);
      final completed = next.completedAt != null || isDailyMissionComplete(progress: next.progress, target: target);
      final toSave = completed && next.completedAt == null ? next.copyWith(completedAt: _clock()) : next;
      await _persist(id, toSave);
      notifyListeners();
    });
  }

  int? _targetFor(DailyMissionId id) {
    switch (id) {
      case DailyMissionId.learnNew:
        return dailyLearnNewWordsTarget;
      case DailyMissionId.sessionAccuracy:
        return dailyAccuracyTargetPercent;
      case DailyMissionId.reviewDue:
        // 目标尚未确定（到期数未就绪）时先累计进度，完成判定留到 refreshDue。
        return _reviewTarget;
    }
  }

  Future<bool> _reloadIfDayChanged() async {
    final today = dailyMissionDayKey(_clock());
    if (_loaded && _day == today) return false;
    final loaded = await repository.load(today);
    _records = {for (final id in DailyMissionId.values) id: loaded[id] ?? const DailyMissionRecord()};
    _day = today;
    _loaded = true;
    _reviewTarget = null;
    return true;
  }

  Future<bool> _refreshTargetAndCompletion({required int dueNow}) async {
    final reviewed = _progressOf(DailyMissionId.reviewDue);
    final target = reviewMissionTarget(reviewedToday: reviewed, dueNow: dueNow);
    final targetChanged = target != _reviewTarget;
    _reviewTarget = target;

    final record = _records[DailyMissionId.reviewDue] ?? const DailyMissionRecord();
    if (record.completedAt != null) return targetChanged;
    if (!isDailyMissionComplete(progress: record.progress, target: target)) return targetChanged;
    await _persist(DailyMissionId.reviewDue, record.copyWith(completedAt: _clock()));
    return true;
  }

  Future<void> _persist(DailyMissionId id, DailyMissionRecord record) async {
    _records[id] = record;
    await repository.save(day, id, record);
  }
}
