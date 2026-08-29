import 'package:flutter/material.dart';

import '../../models/book.dart';
import '../../models/word.dart';
import '../../features/book/presentation/book_words_page.dart';
import '../../features/book/presentation/courses_page.dart';
import '../../features/book/presentation/extensive_model_select_page.dart';
import '../../features/book/presentation/lib_select_page.dart';
import '../../features/book/presentation/word_export_page.dart';
import '../../features/learning/presentation/dictation_session_page.dart';
import '../../features/learning/presentation/learn_page.dart';
import '../../features/learning/presentation/list_word_listen_page.dart';
import '../../features/learning/presentation/listening_player_page.dart';
import '../../features/learning/presentation/mastered_words_page.dart';
import '../../features/learning/presentation/my_words_page.dart';
import '../../features/learning/presentation/new_words_page.dart';
import '../../features/learning/presentation/not_learned_words_page.dart';
import '../../features/learning/presentation/quick_spell_page.dart';
import '../../features/learning/presentation/review_page.dart';
import '../../features/learning/presentation/reviewing_words_page.dart';
import '../../features/learning/presentation/sentence_quiz_page.dart';
import '../../features/learning/presentation/spell_check_page.dart';
import '../../features/learning/presentation/spell_session_page.dart';
import '../../features/learning/presentation/word_machine_page.dart';
import '../../screens/learn_session.dart';
import 'route_error_page.dart';
import 'route_names.dart';

/// 学习功能域的页面映射和参数解析。
///
/// 该模块只返回自己拥有的页面；不识别的名称返回 `null`，由总路由器继续交给其他
/// 功能域或显示未知路由错误页。
abstract final class LearningRoutes {
  static Widget? build(String? name, Object? args) {
    switch (name) {
      case RouteNames.learn:
        return const LearnPage();
      case RouteNames.libSelect:
        return const LibSelectPage();
      case RouteNames.bookWords:
        return _buildBookWordsPage(args);
      case RouteNames.review:
      // 保留历史深链，但不再允许它进入独立的旧会话实现。
      case RouteNames.reviewSession:
        return const ReviewPage();
      case RouteNames.learnSession:
        return const LearnSession();
      case RouteNames.course:
        return const CoursesPage();
      case RouteNames.myWords:
        return const MyWordsPage();
      case RouteNames.newWords:
        return const NewWordsPage();
      case RouteNames.masteredWords:
        return const MasteredWordsPage();
      case RouteNames.notLearnedWords:
        return const NotLearnedWordsPage();
      case RouteNames.reviewingWords:
        return const ReviewingWordsPage();
      case RouteNames.wordListen:
        return const ListWordListenPage();
      case RouteNames.listenModeSelect:
        return _buildListenModeSelectPage(args);
      case RouteNames.sentenceQuiz:
        return const SentenceQuizPage();
      case RouteNames.wordMachine:
        return const WordMachinePage();
      case RouteNames.spellCheck:
        return _buildSpellCheckPage(args);
      case RouteNames.spellSession:
        return const SpellSessionPage();
      case RouteNames.listeningPlayer:
        return _buildListeningPlayerPage(args);
      case RouteNames.dictationSession:
        return _buildDictationSessionPage(args);
      case RouteNames.quickSpell:
        return _buildQuickSpellPage(args);
      case RouteNames.wordExport:
        return _buildWordExportPage(args);
      default:
        return null;
    }
  }

  static Widget _buildBookWordsPage(Object? args) {
    if (args is Book) {
      return BookWordsPage(book: args);
    }
    final map = args is Map<String, dynamic> ? args : const <String, dynamic>{};
    final book = Book(
      id: (map['bookId'] as num?)?.toInt() ?? 0,
      name: (map['bookName'] as String?) ?? '词书',
      wordCount: 0,
      code: '',
    );
    return BookWordsPage(book: book);
  }

  static Widget _buildListenModeSelectPage(Object? args) {
    final map = args is Map<String, dynamic> ? args : null;
    if (map == null) {
      return const RouteErrorPage(routeName: 'listen_mode_select', message: '缺少必要参数');
    }
    final bookId = (map['bookId'] as String?) ?? '';
    return ExtensiveModelSelectPage(bookId: bookId, bookName: map['bookName'] as String? ?? '');
  }

  static Widget _buildSpellCheckPage(Object? args) {
    final map = args is Map<String, dynamic> ? args : null;
    return SpellCheckPage(word: map?['word'] as String? ?? '', phonetic: map?['phonetic'] as String?);
  }

  static Widget _buildListeningPlayerPage(Object? args) {
    final map = args is Map<String, dynamic> ? args : null;
    if (map == null) {
      return const RouteErrorPage(routeName: 'listening_player', message: '缺少必要参数');
    }
    final words = (map['words'] as List?)?.map((entry) => entry as Word).toList() ?? [];
    final modeIndex = (map['mode'] as num?)?.toInt() ?? 0;
    final mode = modeIndex >= 0 && modeIndex < ListeningMode.values.length
        ? ListeningMode.values[modeIndex]
        : ListeningMode.wordOnly;
    return ListeningPlayerPage(words: words, mode: mode, bookName: map['bookName'] as String? ?? '');
  }

  static Widget _buildDictationSessionPage(Object? args) {
    // 页面构造后自身从 LearningSessionState 读取词表队列
    return const DictationSessionPage();
  }

  static Widget _buildQuickSpellPage(Object? args) {
    // 页面构造后自身从 LearningSessionState 读取词表队列
    return const QuickSpellPage();
  }

  static Widget _buildWordExportPage(Object? args) {
    final map = args is Map<String, dynamic> ? args : null;
    if (map == null) {
      return const RouteErrorPage(routeName: 'word_export', message: '缺少必要参数');
    }
    final bookId = (map['bookId'] as num?)?.toInt() ?? 0;
    return WordExportPage(bookId: bookId, bookName: map['bookName'] as String? ?? '');
  }
}
