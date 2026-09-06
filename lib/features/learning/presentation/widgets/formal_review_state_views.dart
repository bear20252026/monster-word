import 'package:flutter/material.dart';

import 'package:word_app/core/presentation/responsive.dart';
import 'package:word_app/theme/skin_system.dart';
import 'package:word_app/tokens/design_tokens.dart';
import 'package:word_app/widgets/mw_button.dart';

/// 正式复习加载中的统一页面：品牌话术 + 主题化加载环。
class FormalReviewLoadingView extends StatelessWidget {
  const FormalReviewLoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    final skin = context.skin.colors;
    return Scaffold(
      backgroundColor: skin.pageBg,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(width: 30, height: 30, child: CircularProgressIndicator(strokeWidth: 3, color: skin.accent)),
            const SizedBox(height: 20),
            Text('正在准备今天的复习…', style: MwTypography.bodySm.copyWith(color: skin.text3)),
          ],
        ),
      ),
    );
  }
}

/// 正式复习加载失败页面：品牌化错误 + 胶囊重试。
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
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(color: skin.danger.withValues(alpha: 0.10), shape: BoxShape.circle),
                child: Icon(Icons.refresh_rounded, color: skin.danger, size: 30),
              ),
              const SizedBox(height: 20),
              Text('复习数据加载失败', style: MwTypography.heading4.copyWith(color: skin.text1)),
              const SizedBox(height: 8),
              Text(
                '别担心，稍后重试即可。',
                textAlign: TextAlign.center,
                style: MwTypography.bodySm.copyWith(color: skin.text3),
              ),
              const SizedBox(height: 24),
              MwButton(label: '重试', onTap: onRetry, minWidth: 160),
            ],
          ),
        ),
      ),
    );
  }
}

/// 正式复习完成页面：情绪收尾瞬间——绿色完成环 + 衬线大数字 + 胶囊返回。
class FormalReviewCompleteView extends StatelessWidget {
  const FormalReviewCompleteView({super.key, required this.done, required this.onReturnHome});

  final int done;
  final VoidCallback onReturnHome;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin.colors;
    final resp = context.responsive;
    return Scaffold(
      backgroundColor: skin.pageBg,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 完成环 + 衬线完成数
            SizedBox(
              width: 128,
              height: 128,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 116,
                    height: 116,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: skin.success.withValues(alpha: 0.08),
                      border: Border.all(color: skin.success.withValues(alpha: 0.35), width: 1),
                    ),
                  ),
                  Icon(Icons.check_rounded, color: skin.success, size: 40),
                  Positioned(
                    bottom: 18,
                    child: Text(
                      '$done',
                      style: TextStyle(
                        fontFamily: 'Charter',
                        fontSize: 24,
                        fontStyle: FontStyle.italic,
                        color: skin.success,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              '今日复习完成！',
              style: TextStyle(
                fontFamily: 'Charter',
                fontSize: 30 * resp.fontScale,
                fontWeight: FontWeight.w400,
                letterSpacing: -0.5,
                color: skin.text1,
              ),
            ),
            const SizedBox(height: 8),
            Text('已把今天到期的单词又牢牢记住了一遍', style: MwTypography.bodySm.copyWith(color: skin.text3)),
            const SizedBox(height: 28),
            MwButton(label: '返回首页', onTap: onReturnHome, minWidth: 180),
          ],
        ),
      ),
    );
  }
}
