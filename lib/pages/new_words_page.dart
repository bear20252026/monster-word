// 由 Claude 团队生成 | Monster Word App

// 移植自 v3.2 NewWordsActivity
// 生词本：显示标记为生词的单词
import 'package:flutter/material.dart';

import '../state/learning_state.dart';
import '../models/word.dart';
import 'list_words_page.dart';

class NewWordsPage extends ListWordsPage {
  const NewWordsPage({super.key});

  static const routeName = '/new_words';

  @override
  State<NewWordsPage> createState() => _NewWordsPageState();
}

class _NewWordsPageState extends ListWordsPageState<NewWordsPage> {
  @override
  String get pageTitle => '生词本';

  @override
  Future<List<Word>> loadWords(LearningState state) async {
    return state.getNewWords();
  }
}
