import 'package:flutter/material.dart';

import 'package:word_app/core/router/nav_utils.dart';
import 'package:word_app/theme/skin_system.dart';
import 'package:word_app/tokens/design_tokens.dart';
import 'package:word_app/tokens/starbucks_tokens.dart';

/// 未知路由或必要参数缺失时显示的友好错误页。
///
/// M5（v2.7.43）：原 5 处硬编码色改语义 token——底色/文字跟主题（暗色自适应），
/// 图标金与按钮绿用品牌常量；与词典按名深链页（dictionary_by_name_page）的
/// 错误态视觉同源，避免双写漂移。
class RouteErrorPage extends StatelessWidget {
  final String routeName;
  final String message;

  const RouteErrorPage({super.key, required this.routeName, required this.message});

  @override
  Widget build(BuildContext context) {
    final skin = context.skin.colors;
    return Material(
      color: skin.pageBg,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.warning_amber_rounded, size: 56, color: MistralColors.mutedGold),
              const SizedBox(height: 16),
              Text(
                '无法打开 $routeName',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: skin.text1),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: skin.text3),
              ),
              const SizedBox(height: 24),
              Builder(
                builder: (ctx) => ElevatedButton.icon(
                  onPressed: () => NavUtils.goHome(ctx),
                  icon: const Icon(Icons.home_outlined, size: 18),
                  label: const Text('返回首页'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: StarbucksCreamColors.greenHouse,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
