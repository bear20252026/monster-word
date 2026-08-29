// 由 Claude 团队生成 | Monster Word App
// CheckInServiceImpl — 签到服务实现

import '../../../repositories/user_repository.dart';
import 'checkin_service.dart';

/// 签到服务实现
class CheckInServiceImpl implements CheckInService {
  final UserRepository _userRepo;

  CheckInServiceImpl({required this._userRepo});

  @override
  int get checkInReward => 10; // 签到奖励 10 尖叫币

  @override
  Future<bool> checkIn() async {
    final today = DateTime.now();
    final hasChecked = await hasCheckedInToday();
    if (hasChecked) return false;
    await _userRepo.addCheckIn(today);
    return true;
  }

  @override
  Future<bool> hasCheckedInToday() async {
    final records = await _userRepo.getCheckInRecords();
    final today = DateTime.now();
    return records.any((r) => r.year == today.year && r.month == today.month && r.day == today.day);
  }

  @override
  Future<int> getStreakDays() async {
    return await _userRepo.getStreakDays();
  }

  @override
  Future<List<DateTime>> getCheckInRecords() async {
    return await _userRepo.getCheckInRecords();
  }

  @override
  Future<Set<String>> getCheckinDates() async {
    final records = await _userRepo.getCheckInRecords();
    return records
        .map((r) => '${r.year}-${r.month.toString().padLeft(2, '0')}-${r.day.toString().padLeft(2, '0')}')
        .toSet();
  }

  @override
  Future<int> getStreak() async {
    return await getStreakDays();
  }
}
