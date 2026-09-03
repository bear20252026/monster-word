// 网络诊断：真实检测网络连接、DNS 解析与关键服务可达性
// （数据源为 NetworkDiagnosisService，dart:io 实现，非硬编码结果）。
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:word_app/features/settings/application/network_diagnosis_service.dart';
import 'package:word_app/features/settings/domain/diagnosis_result.dart';
import 'package:word_app/theme/skin_system.dart';
import 'package:word_app/tokens/design_tokens.dart';

class NetDiagnosisPage extends StatefulWidget {
  const NetDiagnosisPage({super.key, this.serviceOverride});

  final NetworkDiagnosisService? serviceOverride;

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

    final service = widget.serviceOverride ?? context.read<NetworkDiagnosisService>();
    try {
      // 逐步回调：每个真实步骤完成即上屏，无模拟延迟。
      await service.runDiagnosis(
        onStep: (DiagnosisResult step) {
          if (mounted) setState(() => _results.add(step));
        },
      );
    } finally {
      if (mounted) setState(() => _isRunning = false);
    }
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
                padding: EdgeInsets.all(16),
                children: [
                  ..._results.map((r) => _buildResultItem(skin, r)),
                  if (_results.isEmpty && !_isRunning)
                    Center(
                      child: Padding(
                        padding: EdgeInsets.only(top: 80),
                        child: Text('点击"开始诊断"检测网络状态', style: MwTypography.body.copyWith(color: skin.colors.text3)),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isRunning ? null : _startDiagnosis,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MwColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(context.design.radius.pill)),
                  ),
                  child: _isRunning
                      ? SizedBox(
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
      padding: EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
            color: skin.colors.text1,
            tooltip: '返回',
            onPressed: () => Navigator.pop(context),
          ),
          SizedBox(width: 4),
          Text('网络诊断', style: MwTypography.heading5.copyWith(color: skin.colors.text1)),
        ],
      ),
    );
  }

  Widget _buildResultItem(SkinSystem skin, DiagnosisResult r) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: skin.colors.cardBgAlt,
        borderRadius: BorderRadius.circular(context.design.radius.lg),
        border: Border.all(color: skin.colors.divider),
      ),
      child: Row(
        children: [
          Icon(
            r.success ? Icons.check_circle : Icons.error,
            color: r.success ? MwColors.success : MwColors.danger,
            size: 24,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.name, style: MwTypography.bodyBold.copyWith(color: skin.colors.text1)),
                Text(r.detail, style: MwTypography.bodySm.copyWith(color: skin.colors.text3)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
