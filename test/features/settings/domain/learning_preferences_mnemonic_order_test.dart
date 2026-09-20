import 'package:flutter_test/flutter_test.dart';
import 'package:word_app/core/infrastructure/app_preferences.dart';
import 'package:word_app/features/settings/domain/learning_preferences.dart';

void main() {
  test('LearningPreferences.defaultMnemonicOrder 与 AppPreferences 常量一致（M3 单源语义）', () {
    expect(
      LearningPreferences.defaultMnemonicOrder,
      AppPreferences.defaultMnemonicOrder,
      reason: 'domain 字面量与 infrastructure 常量漂移将导致设置/详情排序不一致',
    );
  });
}
