import 'package:flutter/foundation.dart';

import 'package:word_app/features/checkin/application/check_in_history_reader.dart';

/// 签到历史页面的状态管理。
class CheckinHistoryState extends ChangeNotifier {
  CheckinHistoryState({required this._reader});

  final CheckInHistoryReader _reader;

  Set<String> _checkedDates = {};
  int _streak = 0;
  int _reward = 0;
  bool _loading = true;

  Set<String> get checkedDates => _checkedDates;
  int get streak => _streak;
  int get reward => _reward;
  bool get loading => _loading;

  /// 加载签到历史数据。
  Future<void> load() async {
    _loading = true;
    notifyListeners();

    final results = await Future.wait([
      _reader.getCheckedDates(),
      _reader.getStreak(),
    ]);

    _checkedDates = results[0] as Set<String>;
    _streak = results[1] as int;
    _reward = _reader.checkInReward;
    _loading = false;
    notifyListeners();
  }
}
