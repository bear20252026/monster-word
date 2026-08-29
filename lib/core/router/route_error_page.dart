import 'package:flutter/material.dart';

import 'package:word_app/core/router/nav_utils.dart';

/// 未知路由或必要参数缺失时显示的友好错误页。
class RouteErrorPage extends StatelessWidget {
  final String routeName;
  final String message;

  const RouteErrorPage({super.key, required this.routeName, required this.message});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF7F4EF),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.warning_amber_rounded, size: 56, color: Color(0xFFB0885A)),
              const SizedBox(height: 16),
              Text(
                '无法打开 $routeName',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF3D3630)),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: Color(0xFF8A8078)),
              ),
              const SizedBox(height: 24),
              Builder(
                builder: (ctx) => ElevatedButton.icon(
                  onPressed: () => NavUtils.goHome(ctx),
                  icon: const Icon(Icons.home_outlined, size: 18),
                  label: const Text('返回首页'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF006241),
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
