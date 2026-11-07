import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import 'package:word_app/features/missions/application/daily_mission_store.dart';
import 'package:word_app/features/missions/data/daily_mission_dao.dart';

/// 每日任务功能域装配。
///
/// 必须位于学习功能域**外层**：学习/复习会话状态（learning scope 内创建）
/// 要向下查找本 Store 记录进度；首页任务条与结算页同样消费同一实例。
Widget buildDailyMissionFeatureScope({required Widget child}) {
  return ChangeNotifierProvider<DailyMissionStore>(
    create: (_) => DailyMissionStore(repository: DailyMissionDao.instance),
    child: child,
  );
}
