import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../../core/di/service_locator.dart';
import '../../../services/checkin_service.dart';
import '../application/check_in_history_reader.dart';
import '../data/service_check_in_history_reader.dart';

/// 装配签到功能域所需的应用端口。
Widget buildCheckInFeatureScope({required Widget child}) {
  return Provider<CheckInHistoryReader>(
    create: (_) => ServiceCheckInHistoryReader(service: sl<CheckInService>()),
    child: child,
  );
}
