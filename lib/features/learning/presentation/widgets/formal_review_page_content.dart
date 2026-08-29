import 'package:flutter/material.dart';

import 'package:word_app/models/bb_word_process.dart';
import 'package:word_app/features/learning/presentation/widgets/formal_review_state_views.dart';

/// 正式复习页面内容的当前阶段。
enum FormalReviewPagePhase { loading, failed, complete, reviewing }

/// 正式复习页面内容装配组件。
///
/// 该组件根据已经映射的纯展示数据决定加载、失败、完成或答题内容；路由页面
/// 保留 Provider 读取、会话启动、导航和 SnackBar 等框架副作用。
class FormalReviewPageContent extends StatelessWidget {
  const FormalReviewPageContent({
    super.key,
    required this.phase,
    required this.loadError,
    required this.done,
    required this.word,
    required this.onRetry,
    required this.onReturnHome,
    required this.reviewingBuilder,
  });

  final FormalReviewPagePhase phase;
  final Object? loadError;
  final int done;
  final BBWordProcess? word;
  final VoidCallback onRetry;
  final VoidCallback onReturnHome;
  final FormalReviewContentBuilder reviewingBuilder;

  @override
  Widget build(BuildContext context) => switch (phase) {
    FormalReviewPagePhase.loading => const FormalReviewLoadingView(),
    FormalReviewPagePhase.failed => FormalReviewLoadErrorView(error: loadError, onRetry: onRetry),
    FormalReviewPagePhase.complete => FormalReviewCompleteView(done: done, onReturnHome: onReturnHome),
    FormalReviewPagePhase.reviewing when word != null => reviewingBuilder(context, word!),
    // 防御性兜底：会话尚无题目时不渲染一个空的答题布局。
    FormalReviewPagePhase.reviewing => FormalReviewCompleteView(done: done, onReturnHome: onReturnHome),
  };
}

/// 注入进行中答题布局的构建器。
typedef FormalReviewContentBuilder = Widget Function(BuildContext context, BBWordProcess word);

/// 从会话快照映射页面内容阶段。
FormalReviewPagePhase formalReviewPagePhase({
  required bool isLoading,
  required bool hasLoadError,
  required bool hasWord,
}) {
  if (isLoading) return FormalReviewPagePhase.loading;
  if (hasLoadError) return FormalReviewPagePhase.failed;
  return hasWord ? FormalReviewPagePhase.reviewing : FormalReviewPagePhase.complete;
}
