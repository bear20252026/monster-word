import 'package:flutter/material.dart';

import '../../../../theme/skin_system.dart';
import '../../../../tokens/design_tokens.dart';

/// 正式复习加载中的统一页面。
class FormalReviewLoadingView extends StatelessWidget {
  const FormalReviewLoadingView({super.key});

  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: CircularProgressIndicator()));
}

/// 正式复习加载失败页面。
class FormalReviewLoadErrorView extends StatelessWidget {
  const FormalReviewLoadErrorView({super.key, required this.error, required this.onRetry});

  final Object? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin.colors;
    return Scaffold(
      backgroundColor: skin.pageBg,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, color: skin.quizWrongText, size: 56),
              const SizedBox(height: 16),
              Text('复习数据加载失败', style: MistralTypography.heading3.copyWith(color: skin.text1)),
              const SizedBox(height: 8),
              Text(
                '$error',
                textAlign: TextAlign.center,
                style: MistralTypography.bodySm.copyWith(color: skin.text3),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('重试')),
            ],
          ),
        ),
      ),
    );
  }
}

/// 正式复习完成页面。
class FormalReviewCompleteView extends StatelessWidget {
  const FormalReviewCompleteView({super.key, required this.done, required this.onReturnHome});

  final int done;
  final VoidCallback onReturnHome;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin.colors;
    return Scaffold(
      backgroundColor: skin.pageBg,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, color: skin.success, size: 72),
            const SizedBox(height: 16),
            Text(
              '今日复习完成！',
              style: MistralTypography.heading3.copyWith(fontWeight: FontWeight.bold, color: skin.text1),
            ),
            const SizedBox(height: 8),
            Text('共复习 $done 个单词', style: MistralTypography.bodySm.copyWith(color: skin.text3)),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: onReturnHome,
              style: FilledButton.styleFrom(backgroundColor: skin.success),
              child: const Text('返回首页'),
            ),
          ],
        ),
      ),
    );
  }
}
