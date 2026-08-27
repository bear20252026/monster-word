// 由 Claude 团队生成 | Monster Word App

// 移植自 v3.2 SmsActivity
// 短信页：手机号验证码登录辅助页
import 'package:flutter/material.dart';

import '../theme/skin_system.dart';
import '../tokens/design_tokens.dart';

class SmsPage extends StatefulWidget {
  final String phoneNumber;

  const SmsPage({super.key, required this.phoneNumber});

  static const routeName = '/sms';

  @override
  State<SmsPage> createState() => _SmsPageState();
}

class _SmsPageState extends State<SmsPage> {
  final _codeController = TextEditingController();
  int _countdown = 60;
  bool _canResend = false;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  void _startCountdown() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() {
        _countdown--;
        if (_countdown <= 0) _canResend = true;
      });
      return _countdown > 0;
    });
  }

  void _resendCode() {
    if (!_canResend) return;
    setState(() {
      _countdown = 60;
      _canResend = false;
    });
    _startCountdown();
    // TODO: 调用发送验证码 API
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
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 32),
                    Text('验证码已发送至', style: MistralTypography.body.copyWith(color: skin.colors.text3)),
                    const SizedBox(height: 8),
                    Text(widget.phoneNumber, style: MistralTypography.heading4.copyWith(color: skin.colors.text1)),
                    const SizedBox(height: 32),
                    TextField(
                      controller: _codeController,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      style: MistralTypography.heading3.copyWith(color: skin.colors.text1, letterSpacing: 8),
                      maxLength: 6,
                      decoration: InputDecoration(
                        hintText: '请输入验证码',
                        hintStyle: MistralTypography.body.copyWith(color: skin.colors.text3, letterSpacing: 0),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          borderSide: BorderSide(color: skin.colors.divider),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          borderSide: BorderSide(color: MistralColors.primary, width: 2),
                        ),
                        counterText: '',
                      ),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: _canResend
                          ? TextButton(
                              onPressed: _resendCode,
                              child: Text('重新发送', style: TextStyle(color: MistralColors.primary)),
                            )
                          : Text(
                              '${_countdown}s 后可重新发送',
                              style: MistralTypography.bodySm.copyWith(color: skin.colors.text3),
                            ),
                    ),
                    const Spacer(),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () {
                          // TODO: 验证验证码
                          Navigator.pop(context, _codeController.text.trim());
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: MistralColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.pill)),
                        ),
                        child: const Text('确认'),
                      ),
                    ),
                  ],
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
          Text('短信验证', style: MistralTypography.heading5.copyWith(color: skin.colors.text1)),
        ],
      ),
    );
  }
}
