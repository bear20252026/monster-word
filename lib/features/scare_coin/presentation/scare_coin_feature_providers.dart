import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import 'package:word_app/features/scare_coin/application/scare_coin_store.dart';
import 'package:word_app/features/scare_coin/data/preferences_scare_coin_store.dart';

/// 装配尖叫币功能域的账本端口。
Widget buildScareCoinFeatureScope({required Widget child}) {
  return Provider<ScareCoinStore>(create: (_) => PreferencesScareCoinStore(), child: child);
}
