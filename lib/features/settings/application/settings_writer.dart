import '../domain/learning_preferences.dart';

/// 写入学习偏好的抽象端口。
///
/// 由 [LearningPreferencesRepository] 提供具体实现；
/// 表示层只依赖此接口，不直接访问持久化层。
abstract class SettingsWriter {
  Future<void> save(LearningPreferences preferences);
}
