// 由 Claude 团队生成 | Monster Word App

// 移植自 v3.2 ReViewingWordsActivity
// 复习中单词：显示正在复习周期中的单词
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/learning_state.dart';
import '../models/word.dart';
import '../theme/skin_system.dart';
import 'list_words_page.dart';

class ReviewingWordsPage extends ListWordsPage {
  const ReviewingWordsPage({super.key});

  static const routeName = '/reviewing_words';

  @override
  State<ReviewingWordsPage> createState() => _ReviewingWordsPageState();
}

class _ReviewingWordsPageState extends ListWordsPageState<ReviewingWordsPage> {
  @override
  String get pageTitle => '复习中单词';

  @override
  Future<List<Word>> loadWords(LearningState state) async {
    return state.getReviewingWords();
  }
}
