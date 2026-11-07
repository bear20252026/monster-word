import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import 'package:word_app/features/progress/application/xp_store.dart';
import 'package:word_app/features/progress/data/xp_dao.dart';

/// XP / 等级功能域装配。
///
/// 位于学习功能域外层：首页头部与学习/复习结算页都向下读取同一实例。
Widget buildProgressFeatureScope({required Widget child}) {
  return ChangeNotifierProvider<XpStore>(
    create: (_) {
      final store = XpStore(repository: XpDao.instance);
      unawaited(store.ensureLoaded());
      return store;
    },
    child: child,
  );
}
