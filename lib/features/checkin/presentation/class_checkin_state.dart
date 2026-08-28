import 'package:flutter/foundation.dart';

import '../application/checkin_status_reader.dart';
import '../application/checkin_writer.dart';
import '../domain/checkin_status.dart';

/// 班级签到页面的状态管理。
class ClassCheckinState extends ChangeNotifier {
  ClassCheckinState({
    required this._statusReader,
    required this._writer,
  });

  final CheckinStatusReader _statusReader;
  final CheckinWriter _writer;

  CheckinStatus _status = CheckinStatus.empty();
  Set<String> _checkedDates = {};
  bool _loading = true;
  bool _checking = false;

  CheckinStatus get status => _status;
  Set<String> get checkedDates => _checkedDates;
  bool get loading => _loading;
  bool get checking => _checking;

  /// 加载签到状态。
  Future<void> load() async {
    _loading = true;
    notifyListeners();

    final results = await Future.wait([
      _statusReader.getStatus(),
      _statusReader.getCheckinDates(),
    ]);

    _status = results[0] as CheckinStatus;
    _checkedDates = results[1] as Set<String>;
    _loading = false;
    notifyListeners();
  }

  /// 执行签到。
  Future<bool> checkIn() async {
    if (_checking || _status.todayChecked) return false;

    _checking = true;
    notifyListeners();

    final success = await _writer.checkIn();

    if (success) {
      // 刷新状态
      await load();
    }

    _checking = false;
    notifyListeners();
    return success;
  }
}
