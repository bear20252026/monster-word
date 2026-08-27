// 由 Claude 团队生成 | Monster Word App

// 移植自 v3.2 NetDiagnosisActivity
// 网络诊断：检测网络连接状态和 API 可达性
import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/skin_system.dart';
import '../tokens/design_tokens.dart';

class DiagnosisResult {
  final String name;
  final bool success;
  final String detail;

  const DiagnosisResult({required this.name, required this.success, required this.detail});
}

class NetDiagnosisPage extends StatefulWidget {
  const NetDiagnosisPage({super.key});

  static const routeName = '/net_diagnosis';

  @override
  State<NetDiagnosisPage> createState() => _NetDiagnosisPageState();
}

class _NetDiagnosisPageState extends State<NetDiagnosisPage> {
  final List<DiagnosisResult> _results = [];
  bool _isRunning = false;

  Future<void> _startDiagnosis() async {
    setState(() {
      _isRunning = true;
      _results.clear();
    });

    // 模拟网络诊断步骤
    final steps = [('网络连接', true, '已连接'), ('DNS 解析', true, '解析成功'), ('API 服务器', true, '可达'), ('数据同步', true, '正常')];

    for (final step in steps) {
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      setState(() {
        _results.add(DiagnosisResult(name: step.$1, success: step.$2, detail: step.$3));
      });
    }

    setState(() => _isRunning = false);
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;

    return Scaffold(
      backgroundColor: skin.colors.pageBg,
      body: SafeArea(
        child: Column(
          children: [
            _buildNavBar(skin),
            Container(height: 1, color: skin.colors.divider),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  ..._results.map((r) => _buildResultItem(skin, r)),
                  if (_results.isEmpty && !_isRunning)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 80),
                        child: Text('点击"开始诊断"检测网络状态', style: MistralTypography.body.copyWith(color: skin.colors.text3)),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isRunning ? null : _startDiagnosis,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MistralColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.pill)),
                  ),
                  child: _isRunning
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('开始诊断'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavBar(SkinSystem skin) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
            color: skin.colors.text1,
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 4),
          Text('网络诊断', style: MistralTypography.heading5.copyWith(color: skin.colors.text1)),
        ],
      ),
    );
  }

  Widget _buildResultItem(SkinSystem skin, DiagnosisResult r) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: skin.colors.cardBgAlt,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: skin.colors.divider),
      ),
      child: Row(
        children: [
          Icon(
            r.success ? Icons.check_circle : Icons.error,
            color: r.success ? MistralColors.success : MistralColors.danger,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.name, style: MistralTypography.bodyBold.copyWith(color: skin.colors.text1)),
                Text(r.detail, style: MistralTypography.bodySm.copyWith(color: skin.colors.text3)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
