// 由 Claude 团队生成 | Monster Word App

// 移植自 v3.2 MyWordsActivity
// 我的单词：显示所有已学单词
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:word_app/features/learning/presentation/learning_queue_word_lists_state.dart';
import 'package:word_app/models/word.dart';
import 'package:word_app/features/learning/presentation/list_words_page.dart';

class MyWordsPage extends ListWordsPage {
  const MyWordsPage({super.key});

  static const routeName = '/my_words';

  @override
  State<MyWordsPage> createState() => _MyWordsPageState();
}

class _MyWordsPageState extends ListWordsPageState<MyWordsPage> {
  @override
  String get pageTitle => '全部已学单词';

  @override
  Future<List<Word>> loadWordsForContext(BuildContext context) async {
    return context.read<LearningQueueWordListsState>().learnedWords;
  }
}
