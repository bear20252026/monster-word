import 'package:flutter/material.dart';

import '../../features/account/presentation/splash_page.dart';
import '../../features/content/presentation/my_content_page.dart';
import '../../features/content/presentation/my_fav_page.dart';
import '../../features/content/presentation/my_fav_sentence_page.dart';
import '../../features/content/presentation/sentence_detail_page.dart';
import '../../features/dictionary/presentation/word_detail_page.dart';
import '../../features/learning/presentation/immersive_swipe_page.dart';
import '../../features/search/presentation/search_page.dart';
import '../../features/dictionary/presentation/dictionary_by_name_page.dart';
import '../../features/dictionary/presentation/dictionary_page.dart';
import '../../models/word.dart';
import '../../screens/home_screen.dart';
import 'route_error_page.dart';
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
        return _buildWordDetailPage(args);
      case RouteNames.dictionary:
        return _buildDictionaryPage(args);
      case RouteNames.dictionaryByName:
        return _buildDictionaryByNamePage(args);
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

  static Widget _buildWordDetailPage(Object? args) {
    // args 可能为 Word 对象（正常路径）或 Map（深链/序列化路径）；做安全回退
    bool fromLearn = false;
    if (args is Map<String, dynamic>) {
      fromLearn = args['fromLearn'] == true;
    }
    return WordDetailPage(fromLearn: fromLearn);
  }

  static Widget _buildDictionaryPage(Object? args) {
    // 正常路径：直接携带 Word 对象；否则尝试从 Map / String 提取单词名走按名解析
    if (args is Word) {
      return DictionaryPage(word: args);
    }
    final name = _extractWordName(args);
    if (name != null) {
      return DictionaryByNamePage(wordName: name);
    }
    return RouteErrorPage(
      routeName: RouteNames.dictionary,
      message: '缺少单词参数',
    );
  }

  static Widget _buildDictionaryByNamePage(Object? args) {
    final name = _extractWordName(args);
    if (name != null) {
      return DictionaryByNamePage(wordName: name);
    }
    return RouteErrorPage(
      routeName: RouteNames.dictionaryByName,
      message: '缺少单词名参数',
    );
  }

  /// 从 [args] 中稳健地提取单词原文；支持 Word / String / Map 三种形态。
  static String? _extractWordName(Object? args) {
    if (args is Word) {
      return args.word.trim().isEmpty ? null : args.word.trim();
    }
    if (args is String) {
      final t = args.trim();
      return t.isEmpty ? null : t;
    }
    if (args is Map<String, dynamic>) {
      final v = args['word'] ?? args['text'];
      if (v is String) {
        final t = v.trim();
        return t.isEmpty ? null : t;
      }
    }
    return null;
  }
}
