// ============================================================
// 回归测试 — 品牌换肤联动（REG-SKIN-xxx）
// 台账：docs/regression_ledger.md
// ============================================================
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:word_app/core/infrastructure/app_preferences.dart';
import 'package:word_app/theme/skin_system.dart';
import 'package:word_app/tokens/design_language.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  TestWidgetsFlutterBinding.ensureInitialized();

  group('REG-SKIN 换肤联动回归', () {
    test('REG-SKIN-001: 6 品牌设计语言均有颜色主题映射，映射全部有效', () {
      // 症状预防：设计语言选择页一键换肤依赖 brandThemeMap，
      // 新增品牌（B 档）忘记配套 A 档颜色会导致"切了形态不换色"。
      expect(SkinSystem.brandThemeMap.keys, hasLength(6));
      for (final entry in SkinSystem.brandThemeMap.entries) {
        expect(DesignLanguages.all.containsKey(entry.key), isTrue,
            reason: 'brandThemeMap 引用了不存在的 B 档设计语言: ${entry.key}');
        expect(themes.containsKey(entry.value), isTrue,
            reason: 'brandThemeMap 引用了不存在的 A 档颜色主题: ${entry.value}');
      }
    });

    test('REG-SKIN-002: setBrandStyle 同时切换 A 档颜色与 B 档形态', () async {
      await AppPreferences().init(); // setBrandStyle 持久化需要 prefs 就绪
      final skin = SkinSystem();
      skin.setBrandStyle('claude');
      expect(skin.designLanguageId, 'claude', reason: 'B 档（形态）必须随品牌切换');
      expect(skin.effectiveThemeId, 'claude_cream', reason: 'A 档（颜色）必须随品牌切换');
      skin.setBrandStyle('nike');
      expect(skin.designLanguageId, 'nike');
      expect(skin.effectiveThemeId, 'nike_mono');
    });

    test('REG-SKIN-003: 6 套设计语言的 radius/spacing 关键值互有差异', () {
      // 预防：校准 B 档时误把所有品牌值改平（换风格无感知 = bug）
      final radii = DesignLanguages.all.values.map((l) => l.radius.card).toSet();
      expect(radii.length, greaterThanOrEqualTo(4),
          reason: '各品牌 card 圆角应保持差异化（Nike 0 / Starbucks 12 / Apple 18 等）');
    });
  });
}
