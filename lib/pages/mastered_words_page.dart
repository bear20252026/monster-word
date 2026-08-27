// 由 Claude 团队生成 | Monster Word App

// 移植自 v3.2 MasteredWordsActivity
// 已掌握单词：显示已标记为掌握的单词
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../features/learning/application/mastered_words_reader.dart';
import '../models/word.dart';
import 'list_words_page.dart';

class MasteredWordsPage extends ListWordsPage {
  const MasteredWordsPage({super.key});

  static const routeName = '/mastered_words';

  @override
  State<MasteredWordsPage> createState() => _MasteredWordsPageState();
}

class _MasteredWordsPageState extends ListWordsPageState<MasteredWordsPage> {
  @override
  String get pageTitle => '已掌握单词';

  @override
  Future<List<Word>> loadWordsForContext(BuildContext context) {
    return context.read<MasteredWordsReader>().loadWords();
  }
}
