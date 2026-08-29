import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import 'package:word_app/core/di/service_locator.dart';
import 'package:word_app/features/checkin/data/checkin_service.dart';
import 'package:word_app/features/checkin/application/check_in_history_reader.dart';
import 'package:word_app/features/checkin/application/checkin_status_reader.dart';
import 'package:word_app/features/checkin/application/checkin_writer.dart';
import 'package:word_app/features/checkin/data/service_check_in_history_reader.dart';
import 'package:word_app/features/checkin/data/service_checkin_status_reader.dart';
import 'package:word_app/features/checkin/data/service_checkin_writer.dart';

/// 装配签到功能域所需的全部应用端口。
///
/// 按教科书垂直模块标准注入 reader / writer port，
/// presentation 层通过 Provider 获取，不绕过依赖方向。
Widget buildCheckInFeatureScope({required Widget child}) {
  final service = sl<CheckInService>();

  return MultiProvider(
    providers: [
      Provider<CheckInHistoryReader>(
        create: (_) => ServiceCheckInHistoryReader(service: service),
      ),
      Provider<CheckinStatusReader>(
        create: (_) => ServiceCheckinStatusReader(service: service),
      ),
      Provider<CheckinWriter>(
        create: (_) => ServiceCheckinWriter(service: service),
      ),
    ],
    child: child,
  );
}
