import 'package:flutter/material.dart';
import 'package:word_app/tokens/design_tokens.dart';
import 'package:word_app/tokens/starbucks_tokens.dart';

/// 用于替代默认错误屏的应用级构建错误页。
class AppBuildErrorPage extends StatelessWidget {
  const AppBuildErrorPage({super.key, required this.exception});

  final Object exception;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: StarbucksCreamColors.pageBg,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 56, color: MistralColors.mutedGold),
              const SizedBox(height: 16),
              const Text(
                '页面出了一点小问题',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: StarbucksCreamColors.text1),
              ),
              const SizedBox(height: 8),
              const Text(
                '我们已记录此问题，请尝试返回或重新进入该页面。',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: StarbucksCreamColors.text2),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  final navigator = Navigator.of(context);
                  if (navigator.canPop()) {
                    navigator.popUntil((route) => route.isFirst);
                  }
                },
                icon: const Icon(Icons.home_outlined, size: 18),
                label: const Text('返回首页'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: StarbucksCreamColors.greenHouse,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
