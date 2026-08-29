import 'package:flutter/material.dart';

import '../../../hooks/responsive.dart';
import '../../../theme/skin_system.dart';
import '../../../tokens/design_tokens.dart';

/// 帮助与反馈页面（遵循星巴克设计规范）
class FeedbackPage extends StatefulWidget {
  static const String routeName = '/feedback';
  const FeedbackPage({super.key});

  @override
  State<FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends State<FeedbackPage> {
  final _controller = TextEditingController();
  final _contactController = TextEditingController();
  bool _submitted = false;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _controller.dispose();
    _contactController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_controller.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请填写反馈内容')));
      return;
    }
    setState(() => _isSubmitting = true);
    // 模拟提交延迟
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    setState(() {
      _isSubmitting = false;
      _submitted = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final skin = SkinProvider.of(context);
    final resp = context.responsive;
    final colors = skin.colors;

    return PopScope(
      canPop: true,
      child: Scaffold(
        backgroundColor: colors.pageBg,
        appBar: AppBar(
          backgroundColor: colors.pageBg,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new, color: colors.text1),
            tooltip: '返回',
            onPressed: () => Navigator.pop(context),
          ),
          title: Text('帮助与反馈', style: MistralTypography.heading5.copyWith(color: colors.text1)),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(height: 1, color: colors.divider),
          ),
        ),
        body: _submitted ? _buildThankYou(skin, resp) : _buildForm(skin, resp),
      ),
    );
  }

  Widget _buildForm(SkinSystem skin, AppResponsive resp) {
    final colors = skin.colors;
    return SingleChildScrollView(
      padding: EdgeInsets.all(resp.pageMargin),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题
          Text('我们很乐意听取您的意见', style: MistralTypography.heading4.copyWith(color: colors.text1)),
          SizedBox(height: 8),
          Text('请告诉我们您遇到的问题或建议', style: MistralTypography.body.copyWith(color: colors.text2)),
          SizedBox(height: 24),

          // 反馈内容输入框
          Text('反馈内容', style: MistralTypography.bodyBold.copyWith(color: colors.text1)),
          SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: colors.cardBg,
              borderRadius: BorderRadius.circular(context.design.radius.md),
              border: Border.all(color: colors.divider),
            ),
            child: TextField(
              controller: _controller,
              maxLines: 6,
              maxLength: 500,
              style: MistralTypography.body.copyWith(color: colors.text1),
              decoration: InputDecoration(
                hintText: '请详细描述您的问题或建议...',
                hintStyle: MistralTypography.body.copyWith(color: colors.text3),
                border: InputBorder.none,
                contentPadding: EdgeInsets.all(context.design.spacing.md),
              ),
            ),
          ),
          SizedBox(height: 20),

          // 联系方式（可选）
          Text('联系方式（可选）', style: MistralTypography.bodyBold.copyWith(color: colors.text1)),
          SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: colors.cardBg,
              borderRadius: BorderRadius.circular(context.design.radius.md),
              border: Border.all(color: colors.divider),
            ),
            child: TextField(
              controller: _contactController,
              style: MistralTypography.body.copyWith(color: colors.text1),
              decoration: InputDecoration(
                hintText: '邮箱或手机号，方便我们回复您',
                hintStyle: MistralTypography.body.copyWith(color: colors.text3),
                border: InputBorder.none,
                contentPadding: EdgeInsets.all(context.design.spacing.md),
              ),
            ),
          ),
          SizedBox(height: 32),

          // 提交按钮
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.accent,
                foregroundColor: colors.onGlassAccent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(context.design.radius.pill)),
                elevation: 0,
              ),
              onPressed: _isSubmitting ? null : _submit,
              child: _isSubmitting
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(colors.onGlassAccent),
                      ),
                    )
                  : Text('提交反馈', style: MistralTypography.buttonMd.copyWith(color: colors.onGlassAccent)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThankYou(SkinSystem skin, AppResponsive resp) {
    final colors = skin.colors;
    return Center(
      child: Padding(
        padding: EdgeInsets.all(resp.pageMargin * 2),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(color: colors.success.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: Icon(Icons.check_circle, size: 48, color: colors.success),
            ),
            SizedBox(height: 24),
            Text('感谢你的反馈！', style: MistralTypography.heading3.copyWith(color: colors.text1)),
            SizedBox(height: 12),
            Text(
              '我们会认真阅读您的建议，持续改进产品',
              style: MistralTypography.body.copyWith(color: colors.text2),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.accent,
                  foregroundColor: colors.onGlassAccent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(context.design.radius.pill)),
                ),
                onPressed: () => Navigator.pop(context),
                child: Text('返回', style: MistralTypography.buttonMd.copyWith(color: colors.onGlassAccent)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
