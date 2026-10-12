// MW-78：协议正文页（用户协议 / 隐私政策）。
//
// 此前登录页的「用户协议 / 隐私政策」只是不可点击的文字——用户无从查看。
// 本页以纯 Flutter 渲染随包正文（不走 WebView，离线可用、无外部依赖），
// 并显式标注当前政策版本号，与同意留痕记录中的 policyVersion 对应。

import 'package:flutter/material.dart';

import 'package:word_app/features/account/domain/legal_documents.dart';
import 'package:word_app/theme/skin_system.dart';
import 'package:word_app/tokens/design_tokens.dart';
import 'package:word_app/widgets/mw_nav_bar.dart';

class LegalDocumentPage extends StatelessWidget {
  const LegalDocumentPage({super.key, required this.document});

  final LegalDocument document;

  static Route<void> route(LegalDocument document) {
    return MaterialPageRoute<void>(builder: (_) => LegalDocumentPage(document: document));
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;

    return Scaffold(
      backgroundColor: skin.colors.pageBg,
      body: SafeArea(
        child: Column(
          children: [
            MwNavBar(title: document.title, onBack: () => Navigator.pop(context), backTooltip: '返回'),
            Container(height: 1, color: skin.colors.divider),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl, vertical: AppSpacing.lg),
                children: [
                  Text('版本 ${document.version}', style: MwTypography.micro.copyWith(color: skin.colors.text3)),
                  const SizedBox(height: AppSpacing.lg),
                  for (final section in document.sections) ...[
                    Text(section.heading, style: MwTypography.heading5.copyWith(color: skin.colors.text1)),
                    const SizedBox(height: AppSpacing.xs),
                    for (final paragraph in section.paragraphs) ...[
                      Text(paragraph, style: MwTypography.body.copyWith(color: skin.colors.text2)),
                      const SizedBox(height: AppSpacing.xs),
                    ],
                    const SizedBox(height: AppSpacing.md),
                  ],
                  const SizedBox(height: AppSpacing.xl),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
