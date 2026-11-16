import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import 'package:word_app/app/service_locator.dart';
import 'package:word_app/core/repositories/word_repository.dart';
import 'package:word_app/features/book/application/book_catalog_reader.dart';
import 'package:word_app/features/quick_review/application/quick_review_word_reader.dart';
import 'package:word_app/features/quick_review/data/repository_quick_review_word_reader.dart';

/// 装配考试速刷功能域。
Widget buildQuickReviewFeatureScope({required Widget child}) {
  return Provider<QuickReviewWordReader>(
    // 审计 R12：注入词书目录端口——按考试类型匹配词书取词。目录适配器由
    // 组合根注册（R4 禁跨域 data import，I6 同口径），此处只经端口取用。
    create: (_) => RepositoryQuickReviewWordReader(sl<WordRepository>(), catalog: sl<BookCatalogReader>()),
    child: child,
  );
}
