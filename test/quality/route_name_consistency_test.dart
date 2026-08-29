// 路由名一致性回归守卫（XP P0-1）。
//
// 背景：`/book-words`（BookWordsPage.routeName）与 `/book_words`（RouteNames.bookWords）
// 曾出现分歧，导致 lib_select 跳转词书页时走到 RouteErrorPage（词书打不开）。
// 本测试锁定「页面 routeName 必须与 RouteNames 注册名一致」，防止任何页面 routeName
// 与注册名再次分歧（即「前进即失败」类 bug 的通用回归守卫）。
import 'package:flutter_test/flutter_test.dart';

import 'package:word_app/core/router/route_names.dart';
import 'package:word_app/features/book/presentation/book_words_page.dart';

void main() {
  group('页面 routeName 与 RouteNames 注册名一致性', () {
    test('BookWordsPage.routeName 必须等于 RouteNames.bookWords（词书跳转不再 404）', () {
      expect(BookWordsPage.routeName, RouteNames.bookWords);
    });
  });
}
