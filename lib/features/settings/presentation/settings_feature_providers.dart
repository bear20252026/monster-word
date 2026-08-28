import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/learning_preferences_repository.dart';
import 'learning_preferences_state.dart';

/// 为设置功能创建一个 MultiProvider 作用域。
///
/// 该作用域在 App 生命周期内仅初始化一次（见 [MaterialApp.builder]），
/// 并通过 [InheritedProvider] 将当前学习偏好状态下发给设置功能域内的所有子树。
Widget buildSettingsFeatureScope({required Widget child}) {
  final repository = LearningPreferencesRepository();
  return MultiProvider(
    providers: [
      Provider<LearningPreferencesRepository>.value(value: repository),
      ChangeNotifierProvider<LearningPreferencesState>(
        create: (_) => LearningPreferencesState(
          reader: repository,
          writer: repository,
        ),
      ),
    ],
    child: _SettingsFeatureInitializer(child: child),
  );
}

/// 在首帧之后触发偏好加载，避免在 build 阶段调用 notifyListeners。
class _SettingsFeatureInitializer extends StatefulWidget {
  const _SettingsFeatureInitializer({required this.child});
  final Widget child;

  @override
  State<_SettingsFeatureInitializer> createState() => _SettingsFeatureInitializerState();
}

class _SettingsFeatureInitializerState extends State<_SettingsFeatureInitializer> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<LearningPreferencesState>().initialize();
      }
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
