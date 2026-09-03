// 由 Claude 团队生成 | Monster Word App

// 生词本：显示标记为生词的单词
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:word_app/features/learning/application/new_words_reader.dart';
import 'package:word_app/features/learning/presentation/new_words_state.dart';
import 'package:word_app/models/word.dart';
import 'package:word_app/features/learning/presentation/list_words_page.dart';

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
  Future<List<Word>> loadWordsForContext(BuildContext context) {
    return context.read<NewWordsReader>().loadWords();
  }

  @override
  Future<bool> removeWord(Word word) {
    return context.read<NewWordsState>().removeNewWord(word);
  }
}
