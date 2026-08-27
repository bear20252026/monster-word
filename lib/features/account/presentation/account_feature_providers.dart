import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import 'app_session_state.dart';

/// 账号功能域的根状态装配入口。
Widget buildAccountFeatureScope({required Widget child}) {
  return ChangeNotifierProvider(create: (_) => AppSessionState(), child: child);
}
