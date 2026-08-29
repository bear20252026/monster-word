// 由 Claude 团队生成 | Monster Word App

// 移植自 v3.2 NotLearnedWordsActivity
// 未学习单词：显示尚未开始学习的单词
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'learning_queue_word_lists_state.dart';
import '../../../models/word.dart';
import 'list_words_page.dart';

class NotLearnedWordsPage extends ListWordsPage {
  const NotLearnedWordsPage({super.key});

  static const routeName = '/not_learned_words';

  @override
  State<NotLearnedWordsPage> createState() => _NotLearnedWordsPageState();
}

class _NotLearnedWordsPageState extends ListWordsPageState<NotLearnedWordsPage> {
  @override
  String get pageTitle => '未学习单词';

  @override
  Future<List<Word>> loadWordsForContext(BuildContext context) async {
    return context.read<LearningQueueWordListsState>().notLearnedWords;
  }
}
