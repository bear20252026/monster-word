// 第四轮审计 M11（2026-11-18）：PresentationPrefs 收口方法单测。
//
// 兑换中心收藏章标记 / 小屋天色 / 生日年度标记原在 presentation 直读写 SP，
// 第一批收口于本门面。这里验证读写口径与关键语义：收藏章/生日写返回底层
// setBool 结果（false=写失败，调用方据此补偿退款/不庆祝）；天色无记录返 null。
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:word_app/core/application/presentation_prefs.dart';
import 'package:word_app/core/infrastructure/app_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PresentationPrefs prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppPreferences().init();
    prefs = PresentationPrefs();
  });

  group('收藏章标记（兑换中心）', () {
    test('未兑换默认 false，标记后 true，键前缀单一事实来源', () async {
      expect(prefs.isBadgeRedeemed('badge_warm'), isFalse);
      final ok = await prefs.markBadgeRedeemed('badge_warm');
      expect(ok, isTrue);
      expect(prefs.isBadgeRedeemed('badge_warm'), isTrue);
      // 键落在 AppPreferences.redeemedBadgePrefix 前缀下（与 redeemedBadgeCount 同源）。
      final sp = await SharedPreferences.getInstance();
      expect(sp.getBool('${AppPreferences.redeemedBadgePrefix}badge_warm'), isTrue);
      expect(prefs.redeemedBadgeCount, 1);
    });

    test('不同徽章互不影响', () async {
      await prefs.markBadgeRedeemed('badge_warm');
      expect(prefs.isBadgeRedeemed('badge_midnight'), isFalse);
    });
  });

  group('小屋天色', () {
    test('无记录返回 null（页面走自动模式）', () {
      expect(prefs.skyScene(), isNull);
    });

    test('写入后读回，0 值可区分于无记录', () async {
      await prefs.setSkyScene(0);
      expect(prefs.skyScene(), 0);
      await prefs.setSkyScene(2);
      expect(prefs.skyScene(), 2);
    });
  });

  group('生日年度标记', () {
    test('未庆祝默认 false，标记后 true，按年隔离', () async {
      expect(prefs.birthdayCelebrated(2026), isFalse);
      final ok = await prefs.markBirthdayCelebrated(2026);
      expect(ok, isTrue);
      expect(prefs.birthdayCelebrated(2026), isTrue);
      expect(prefs.birthdayCelebrated(2027), isFalse, reason: '不同年份互不影响');
    });

    test('写成功才返回 true（页面据此决定是否庆祝）', () async {
      expect(await prefs.markBirthdayCelebrated(2026), isTrue);
    });
  });

  group('写失败语义（返回 false，调用方补偿/不庆祝）', () {
    test('markBadgeRedeemed 底层写失败返回 false', () async {
      final failing = PresentationPrefs(prefs: _FailingSetPrefs());
      expect(await failing.markBadgeRedeemed('badge_warm'), isFalse);
    });

    test('markBirthdayCelebrated 底层写失败返回 false', () async {
      final failing = PresentationPrefs(prefs: _FailingSetPrefs());
      expect(await failing.markBirthdayCelebrated(2026), isFalse);
    });
  });
}

/// setBool 恒返回 false 的假底层（模拟磁盘满/SP 写失败），验证门面如实返回。
/// AppPreferences 是 factory 构造不可继承，用 implements；写失败用例只触发
/// setBool（已 override），ensureReady 经 noSuchMethod 空转即可。
class _FailingSetPrefs implements AppPreferences {
  @override
  Future<void> init() async {}

  @override
  Future<bool> setBool(String key, bool value) async => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
