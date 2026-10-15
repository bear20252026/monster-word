// 路由 → 模块标识映射的断言。
//
// 这些断言是**纯 Dart**（被测代码不 import flutter），所以除了 CI，也能在本机
// 用 dart.exe 直接执行 —— 本仓 flutter test 受 365vpn 影响不可用，这一点很重要。
import 'package:flutter_test/flutter_test.dart';

import 'package:word_app/app/router/route_names.dart';
import 'package:word_app/features/telemetry/application/usage_module_map.dart';
import 'package:word_app/features/telemetry/domain/usage_daily_stats.dart';

void main() {
  group('moduleForRoute', () {
    test('主要入口映射到预期模块', () {
      expect(moduleForRoute(RouteNames.learn), 'learn');
      expect(moduleForRoute(RouteNames.review), 'review');
      expect(moduleForRoute(RouteNames.wordListen), 'listen');
      expect(moduleForRoute(RouteNames.dictionary), 'dict');
      expect(moduleForRoute(RouteNames.libSelect), 'book');
      expect(moduleForRoute(RouteNames.myContent), 'content');
      expect(moduleForRoute(RouteNames.moreSettings), 'profile');
    });

    test('每个映射值都必须是 knownModules 白名单内的键', () {
      // 白名单是「不把用户可见字符串带上服务端」的保证；映射表写错一个键就会
      // 让整条记录在模型层被静默丢弃，这条断言就是防这个。
      for (final entry in moduleRoutes.entries) {
        expect(UsageDailyStats.knownModules, contains(entry.value), reason: '路由 ${entry.key} 映射到了非法模块 ${entry.value}');
      }
    });

    test('未收录的路由返回 null（宁可少记，不要记错）', () {
      expect(moduleForRoute(null), isNull);
      expect(moduleForRoute(''), isNull);
      expect(moduleForRoute('/'), isNull);
      expect(moduleForRoute(RouteNames.splash), isNull);
      expect(moduleForRoute(RouteNames.login), isNull);
      expect(moduleForRoute('/not_a_real_route'), isNull);
    });

    test('带查询串或锚点的深链仍能命中（按去掉 ? / # 后的路径匹配）', () {
      expect(moduleForRoute('${RouteNames.dictionaryByName}?word=apple'), 'dict');
      expect(moduleForRoute('${RouteNames.bookWords}#top'), 'book');
      expect(moduleForRoute('${RouteNames.dictionary}?x=1#y'), 'dict');
    });

    test('主要入口必须都被收录（漏一个就等于该模块永远记不到）', () {
      const mustCover = [
        RouteNames.learn,
        RouteNames.learnSession,
        RouteNames.review,
        RouteNames.reviewingWords,
        RouteNames.examQuickReview,
        RouteNames.spellSession,
        RouteNames.dictationSession,
        RouteNames.wordListen,
        RouteNames.listeningPlayer,
        RouteNames.dictionary,
        RouteNames.wordDetail,
        RouteNames.libSelect,
        RouteNames.bookWords,
        RouteNames.myContent,
        RouteNames.myFav,
        RouteNames.mySpace,
        RouteNames.settings,
        RouteNames.moreSettings,
        RouteNames.treasureCheckIn,
        RouteNames.scareCoinHistory,
      ];
      for (final route in mustCover) {
        expect(moduleRoutes.containsKey(route), isTrue, reason: '路由 $route 未被收录');
      }
    });
  });
}
