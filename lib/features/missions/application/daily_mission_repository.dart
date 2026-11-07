import 'package:word_app/features/missions/domain/daily_mission.dart';

/// 一条每日任务的持久化快照。
class DailyMissionRecord {
  const DailyMissionRecord({this.progress = 0, this.completedAt, this.rewardClaimedAt});

  final int progress;

  /// 首次达成目标的时间；一旦写入不再回退（奖励只发一次）。
  final DateTime? completedAt;

  /// 奖励已结算的时间（本地额外保险；真正的发币幂等由 event_key 保证）。
  final DateTime? rewardClaimedAt;

  DailyMissionRecord copyWith({int? progress, DateTime? completedAt, DateTime? rewardClaimedAt}) {
    return DailyMissionRecord(
      progress: progress ?? this.progress,
      completedAt: completedAt ?? this.completedAt,
      rewardClaimedAt: rewardClaimedAt ?? this.rewardClaimedAt,
    );
  }
}

/// 每日任务存储端口（实现放 data 层，Store 只依赖本契约）。
abstract interface class DailyMissionRepository {
  Future<Map<DailyMissionId, DailyMissionRecord>> load(String day);

  Future<void> save(String day, DailyMissionId id, DailyMissionRecord record);
}
