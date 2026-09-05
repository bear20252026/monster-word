// 风格系统回归测试：6 精选风格收敛（颜色主题 + 设计语言一次绑定）
//
// 背景：历史上外观页暴露 11 主题 × 6 设计语言的双轴组合（66 种），
// 用户选择灾难。收敛后用户只做 6 选 1，旧主题 id 自动迁移到最近风格。
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:word_app/core/infrastructure/app_preferences.dart';
import 'package:word_app/theme/skin_system.dart';
import 'package:word_app/tokens/design_language.dart';

void main() {
  // SkinSystem 构造器读取系统亮度（platformDispatcher），需先初始化绑定
  TestWidgetsFlutterBinding.ensureInitialized();

  group('REG-STYLE: 精选风格收敛', () {
    test('REG-STYLE-001: 恰好 6 个精选风格，且绑定均有效', () {
      expect(kMwStyles, hasLength(6), reason: '用户要求最多 6 个风格');
      final styleIds = <String>{};
      for (final s in kMwStyles) {
        expect(themes.containsKey(s.themeId), isTrue, reason: '${s.id} 绑定的颜色主题不存在');
        expect(DesignLanguages.all.containsKey(s.languageId), isTrue, reason: '${s.id} 绑定的设计语言不存在');
        expect(styleIds.add(s.id), isTrue, reason: '风格 id 重复: ${s.id}');
      }
      // 每个精选风格的主题/语言不得重叠成同一组合
      final combos = kMwStyles.map((s) => '${s.themeId}+${s.languageId}').toSet();
      expect(combos, hasLength(kMwStyles.length), reason: '存在重复的风格组合');
    });

    test('REG-STYLE-002: setStyle 同时切换 A 档颜色与 B 档形态', () async {
      SharedPreferences.setMockInitialValues({});
      await AppPreferences().init();
      final skin = SkinSystem();
      expect(skin.currentStyleId, 'starbucks_cream', reason: '默认风格应为星巴克奶油');
      expect(skin.themeId, 'starbucks_cream');

      skin.setStyle('nike_mono');
      expect(skin.themeId, 'nike_mono');
      expect(skin.designLanguageId, 'nike');
      expect(skin.currentStyleId, 'nike_mono');

      skin.setStyle('claude_cream');
      expect(skin.themeId, 'claude_cream');
      expect(skin.designLanguageId, 'claude');
      expect(skin.currentStyleId, 'claude_cream');

      // 未知风格 id：静默忽略，不破坏当前状态
      skin.setStyle('not_exist');
      expect(skin.currentStyleId, 'claude_cream');
    });

    test('REG-STYLE-003: 旧主题偏好迁移表覆盖全部非精选主题', () {
      // themes 里不在 6 精选风格中的主题，必须都有迁移去向
      final styleThemes = kMwStyles.map((s) => s.themeId).toSet();
      final retired = themes.keys.where((id) => !styleThemes.contains(id)).toSet();
      expect(retired, isNotEmpty, reason: '应存在被 retirement 的旧主题（否则本断言无意义）');
      for (final id in retired) {
        expect(SkinSystem.legacyThemeMigration.containsKey(id), isTrue, reason: '旧主题 $id 缺少迁移映射，老用户会落在非精选主题上');
        expect(themes.containsKey(SkinSystem.legacyThemeMigration[id]), isTrue);
      }
      // 迁移目标必须是精选主题
      for (final target in SkinSystem.legacyThemeMigration.values) {
        expect(styleThemes.contains(target), isTrue, reason: '迁移目标 $target 不是精选风格主题');
      }
    });
  });
}
