import 'package:flutter/material.dart';

/// 用于替代默认错误屏的应用级构建错误页。
class AppBuildErrorPage extends StatelessWidget {
  const AppBuildErrorPage({super.key, required this.exception});

  final Object exception;

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
              const Icon(Icons.error_outline, size: 56, color: Color(0xFFB0885A)),
              const SizedBox(height: 16),
              const Text(
                '页面出了一点小问题',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF3D3630)),
              ),
              const SizedBox(height: 8),
              const Text(
                '我们已记录此问题，请尝试返回或重新进入该页面。',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Color(0xFF8A8078)),
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
                  backgroundColor: const Color(0xFF006241),
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
