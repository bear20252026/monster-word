import 'package:flutter/material.dart';

import '../../pages/immersive_swipe_page.dart';
import '../../pages/my_content_page.dart';
import '../../pages/my_fav_page.dart';
import '../../pages/my_fav_sentence_page.dart';
import '../../pages/search_page.dart';
import '../../pages/sentence_detail_page.dart';
import '../../pages/splash_page.dart';
import '../../pages/word_detail_page.dart';
import '../../screens/home_screen.dart';
import 'route_names.dart';

/// 内容与词典功能域的页面映射和参数解析。
abstract final class ContentRoutes {
  static Widget? build(String? name, Object? args) {
    switch (name) {
      case RouteNames.home:
        return const HomeScreen();
      case RouteNames.search:
        return const SearchPage();
      case RouteNames.splash:
        return const SplashPage();
      case RouteNames.sentenceDetail:
        return _buildSentenceDetailPage(args);
      case RouteNames.myFav:
        return const MyFavPage();
      case RouteNames.myFavSentence:
        return const MyFavSentencePage();
      case RouteNames.myContent:
        return const MyContentPage();
      case RouteNames.immersiveSwipe:
        return const ImmersiveSwipePage();
      case RouteNames.wordDetail:
        return const WordDetailPage();
      default:
        return null;
    }
  }

  static Widget _buildSentenceDetailPage(Object? args) {
    final map = args is Map<String, dynamic> ? args : null;
    return SentenceDetailPage(
      word: map?['word'] as String? ?? '',
      sentence: map?['sentence'] as String? ?? '',
      translation: map?['translation'] as String?,
      source: map?['source'] as String?,
    );
  }
}
