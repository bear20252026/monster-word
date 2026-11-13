import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:word_app/app/router/app_router.dart';
import 'package:word_app/app/router/route_error_page.dart';
import 'package:word_app/features/account/presentation/my_space_page.dart';
import 'package:word_app/features/book/presentation/memory_beast_gallery_page.dart';
import 'package:word_app/features/checkin/presentation/check_in_history_page.dart';
import 'package:word_app/features/learning/presentation/dashboard_page.dart';
import 'package:word_app/features/learning/presentation/learn_page.dart';
import 'package:word_app/features/scare_coin/presentation/redemption_center_page.dart';
import 'package:word_app/features/search/presentation/search_page.dart';
import 'package:word_app/features/settings/presentation/more_settings_page.dart';
import 'package:word_app/features/settings/presentation/settings_page.dart';
import 'package:word_app/features/learning/presentation/review_page.dart';
import 'package:word_app/features/word_browse/presentation/foot_mark_page.dart';

void main() {
  group('AppRouter 功能域委托', () {
    test('学习、内容和账户路由保持原页面类型', () {
      expect(AppRouter.buildPage(const RouteSettings(name: RouteNames.learn)), isA<LearnPage>());
      expect(AppRouter.buildPage(const RouteSettings(name: RouteNames.search)), isA<SearchPage>());
      expect(AppRouter.buildPage(const RouteSettings(name: RouteNames.settings)), isA<SettingsPage>());
    });

    test('历史复习深链和未知路由保持各自的兼容结果', () {
      expect(AppRouter.buildPage(const RouteSettings(name: RouteNames.reviewSession)), isA<ReviewPage>());
      expect(AppRouter.buildPage(const RouteSettings(name: '/not-a-route')), isA<RouteErrorPage>());
    });

    // P3-1（架构审计 2026-11-12）：AccountRoutes 杂物桶按域拆分后，
    // 各域代表页面仍须经总路由器正确解析（拆分只挪 case，不改路由名/页面）。
    test('P3-1 拆分后各域路由仍正确解析', () {
      expect(AppRouter.buildPage(const RouteSettings(name: RouteNames.mySpace)), isA<MySpacePage>());
      expect(AppRouter.buildPage(const RouteSettings(name: RouteNames.moreSettings)), isA<MoreSettingsPage>());
      expect(AppRouter.buildPage(const RouteSettings(name: RouteNames.redemption)), isA<RedemptionCenterPage>());
      expect(AppRouter.buildPage(const RouteSettings(name: RouteNames.checkInHistory)), isA<CheckInHistoryPage>());
      expect(AppRouter.buildPage(const RouteSettings(name: RouteNames.dashboard)), isA<DashboardPage>());
      expect(
        AppRouter.buildPage(const RouteSettings(name: RouteNames.memoryBeastGallery)),
        isA<MemoryBeastGalleryPage>(),
      );
      expect(AppRouter.buildPage(const RouteSettings(name: RouteNames.footMark)), isA<FootMarkPage>());
    });
  });
}
