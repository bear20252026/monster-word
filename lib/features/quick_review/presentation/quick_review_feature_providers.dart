import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../../core/di/service_locator.dart';
import '../../../repositories/word_repository.dart';
import '../application/quick_review_word_reader.dart';
import '../data/repository_quick_review_word_reader.dart';

/// 装配考试速刷功能域。
Widget buildQuickReviewFeatureScope({required Widget child}) {
  return Provider<QuickReviewWordReader>(
    create: (_) => RepositoryQuickReviewWordReader(repository: sl<WordRepository>()),
    child: child,
  );
}
