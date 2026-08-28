import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../../core/scare_coin/scare_coin_store.dart';
import '../data/preferences_scare_coin_store.dart';

/// 装配尖叫币功能域的账本端口。
Widget buildScareCoinFeatureScope({required Widget child}) {
  return Provider<ScareCoinStore>(create: (_) => PreferencesScareCoinStore(), child: child);
}
