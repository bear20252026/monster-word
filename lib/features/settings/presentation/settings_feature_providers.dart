import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../data/learning_preferences_repository.dart';
import 'learning_preferences_state.dart';

/// 设置功能域的根 Provider 装配。
///
/// 应用根只组合该作用域；学习偏好的持久化细节留在设置功能域内部。
Widget buildSettingsFeatureScope({required Widget child}) {
  return MultiProvider(
    providers: [
      Provider(create: (_) => LearningPreferencesRepository()),
      ChangeNotifierProvider(
        create: (context) =>
            LearningPreferencesState(repository: context.read<LearningPreferencesRepository>())..initialize(),
      ),
    ],
    child: child,
  );
}
