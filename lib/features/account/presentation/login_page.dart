// 由 Claude 团队生成 | Monster Word App

// 移植自 v3.2 LoginActivity
// 登录页：支持手机号登录、账号密码登录
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:word_app/core/router/nav_utils.dart';
import 'package:word_app/theme/skin_system.dart';
import 'package:word_app/tokens/design_tokens.dart';
import 'package:word_app/widgets/animations.dart';
import 'package:word_app/features/account/presentation/app_session_state.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  static const routeName = '/login';

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with SingleTickerProviderStateMixin {
  // 0 = 主登录选择, 1 = 账号密码登录, 2 = 手机号登录
  int _loginMode = 0;

  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _codeController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isLoading = false;
  String? _lastLoginAccountInfo;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _fadeAnim = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _animController, curve: standardCurve));
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: fataleCurve));
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  // ─── 登录频率限制（防止暴力破解）───────────────────────────────────
  static final List<DateTime> _loginAttempts = [];
  static const int _maxAttemptsPerMinute = 5;

  bool _checkRateLimit() {
    final now = DateTime.now();
    // 清除 1 分钟前的记录
    _loginAttempts.removeWhere((t) => now.difference(t).inSeconds > 60);
    if (_loginAttempts.length >= _maxAttemptsPerMinute) {
      _showToast('登录过于频繁，请稍后再试');
      return false;
    }
    _loginAttempts.add(now);
    return true;
  }

  Future<void> _loginWithCoolID(String username, String password) async {
    // ✅ 输入验证：长度限制
    if (username.isEmpty) {
      _showToast('用户名不能为空');
      return;
    }
    if (username.length < 3 || username.length > 32) {
      _showToast('用户名长度应为 3-32 个字符');
      return;
    }
    if (password.isEmpty) {
      _showToast('密码不能为空');
      return;
    }
    if (password.length < 6 || password.length > 64) {
      _showToast('密码长度应为 6-64 个字符');
      return;
    }
    // ✅ 频率限制
    if (!_checkRateLimit()) return;

    setState(() => _isLoading = true);
    try {
      final session = context.read<AppSessionState>();
      final success = await session.login(username, password);
      if (success && mounted) {
        _onLoginSuccess();
      } else if (mounted) {
        _showToast('登录失败，请再次尝试！');
      }
    } catch (e) {
      if (mounted) _showToast('登录失败：$e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loginWithPhone(String phone, String code) async {
    // ✅ 输入验证：手机号格式
    if (phone.isEmpty) {
      _showToast('手机号不能为空');
      return;
    }
    if (!RegExp(r'^1[3-9]\d{9}$').hasMatch(phone)) {
      _showToast('请输入有效的手机号');
      return;
    }
    if (code.isEmpty) {
      _showToast('验证码不能为空');
      return;
    }
    if (code.length != 6 || !RegExp(r'^\d{6}$').hasMatch(code)) {
      _showToast('验证码应为 6 位数字');
      return;
    }
    // ✅ 频率限制
    if (!_checkRateLimit()) return;

    setState(() => _isLoading = true);
    try {
      final session = context.read<AppSessionState>();
      final success = await session.phoneLogin(phone, code);
      if (success && mounted) {
        _onLoginSuccess();
      } else if (mounted) {
        _showToast('登录失败，请再次尝试！');
      }
    } catch (e) {
      if (mounted) _showToast('登录失败：$e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onLoginSuccess() {
    Navigator.of(context).pushReplacementNamed('/');
  }

  void _showToast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 2)));
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;

    // 主视图按系统返回键显示退出确认
    final canExit = _loginMode != 0;
    return PopScope(
      canPop: canExit,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && !canExit) {
          _showExitConfirmDialog(context);
        }
      },
      child: Scaffold(
        backgroundColor: skin.colors.pageBg,
        body: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: SlideTransition(
              position: _slideAnim,
              child: _loginMode == 0 ? _buildMainLoginView(skin) : _buildInputLoginView(skin),
            ),
          ),
        ),
      ),
    );
  }

  void _showExitConfirmDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('退出应用'),
        content: const Text('确定要退出 Monster Word 吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              // 安全返回：若栈中仅此一页则不崩溃
              NavUtils.safePop(context);
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  /// 主登录选择页（对应原版底部第三方登录区域）
  Widget _buildMainLoginView(SkinSystem skin) {
    return Column(
      children: [
        const Spacer(flex: 2),
        // Logo 区域（对应原版 bubeidanci + logo）
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(colors: [MistralColors.cream, MistralColors.creamDeeper]),
          ),
          child: Icon(Icons.menu_book, size: 56, color: MistralColors.primary),
        ),
        SizedBox(height: 16),
        Text('不背单词', style: MistralTypography.heading3.copyWith(color: skin.colors.text1)),
        SizedBox(height: 8),
        // Slogan（对应原版 tv_slogan）
        Text('在语境中学习单词', style: MistralTypography.body.copyWith(color: skin.colors.text3)),
        const Spacer(flex: 1),
        // 上次登录信息（对应原版 mTvLastAccountInfoView）
        if (_lastLoginAccountInfo != null && _lastLoginAccountInfo!.isNotEmpty)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              '上次登录：$_lastLoginAccountInfo',
              style: MistralTypography.bodySm.copyWith(color: skin.colors.text3),
            ),
          ),
        SizedBox(height: 24),
        // 登录方式按钮组
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              // 手机号登录
              Semantics(
                label: '手机号登录',
                button: true,
                child: _buildSocialLoginButton(
                  skin: skin,
                  icon: Icons.phone_android,
                  label: '手机号登录',
                  color: MistralColors.primary,
                  onTap: () => setState(() => _loginMode = 2),
                ),
              ),
              SizedBox(height: 12),
              // 账号密码登录
              Semantics(
                label: '账号密码登录',
                button: true,
                child: _buildSocialLoginButton(
                  skin: skin,
                  icon: Icons.email_outlined,
                  label: '账号密码登录',
                  color: skin.colors.text1,
                  onTap: () => setState(() => _loginMode = 1),
                  outlined: true,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 16),
        // 用户协议（对应原版 tv_user_rule）
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 32),
          child: Text.rich(
            TextSpan(
              text: '登录即同意 ',
              style: MistralTypography.micro.copyWith(color: skin.colors.text3),
              children: [
                TextSpan(
                  text: '用户协议',
                  style: TextStyle(color: MistralColors.link),
                ),
                const TextSpan(text: ' 和 '),
                TextSpan(
                  text: '隐私政策',
                  style: TextStyle(color: MistralColors.link),
                ),
              ],
            ),
            textAlign: TextAlign.center,
          ),
        ),
        SizedBox(height: 24),
      ],
    );
  }

  /// 账号密码 / 手机号 登录输入页
  Widget _buildInputLoginView(SkinSystem skin) {
    final isPhone = _loginMode == 2;

    return Column(
      children: [
        // 顶部导航（对应原版 CustomHeadView）
        Container(
          height: 48,
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                color: skin.colors.text1,
                onPressed: () => setState(() => _loginMode = 0),
              ),
              const Spacer(),
              Text(isPhone ? '手机号登录' : '账号密码登录', style: MistralTypography.heading5.copyWith(color: skin.colors.text1)),
              const Spacer(),
              SizedBox(width: 48), // 占位，保持居中
            ],
          ),
        ),
        Container(height: 1, color: skin.colors.divider),
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 32),
                if (isPhone) ...[
                  _buildTextField(
                    controller: _phoneController,
                    hint: '请输入手机号',
                    icon: Icons.phone_android,
                    keyboardType: TextInputType.phone,
                    skin: skin,
                  ),
                  SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: _codeController,
                          hint: '请输入验证码',
                          icon: Icons.lock_outline,
                          keyboardType: TextInputType.number,
                          skin: skin,
                        ),
                      ),
                      SizedBox(width: 12),
                      SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          onPressed: () {
                            // TODO: 发送验证码
                            _showToast('验证码已发送');
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: MistralColors.primary,
                            foregroundColor: AppColors.white100,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(context.design.radius.md)),
                          ),
                          child: const Text('获取验证码'),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  _buildTextField(
                    controller: _phoneController,
                    hint: '请输入用户名/邮箱',
                    icon: Icons.person_outline,
                    skin: skin,
                  ),
                  SizedBox(height: 16),
                  _buildTextField(
                    controller: _passwordController,
                    hint: '请输入密码',
                    icon: Icons.lock_outline,
                    obscure: !_isPasswordVisible,
                    skin: skin,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                        color: skin.colors.text3,
                      ),
                      onPressed: () {
                        setState(() => _isPasswordVisible = !_isPasswordVisible);
                      },
                    ),
                  ),
                  SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        // TODO: 忘记密码
                      },
                      child: Text('忘记密码？', style: MistralTypography.bodySm.copyWith(color: MistralColors.link)),
                    ),
                  ),
                ],
                SizedBox(height: 24),
                // 登录按钮
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isLoading
                        ? null
                        : () {
                            if (isPhone) {
                              _loginWithPhone(_phoneController.text.trim(), _codeController.text.trim());
                            } else {
                              _loginWithCoolID(_phoneController.text.trim(), _passwordController.text.trim());
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: MistralColors.primary,
                      foregroundColor: AppColors.white100,
                      disabledBackgroundColor: MistralColors.muted,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(context.design.radius.pill)),
                    ),
                    child: _isLoading
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.white100),
                          )
                        : const Text('登录'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required SkinSystem skin,
    TextInputType? keyboardType,
    bool obscure = false,
    Widget? suffixIcon,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscure,
      style: MistralTypography.body.copyWith(color: skin.colors.text1),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: MistralTypography.body.copyWith(color: skin.colors.text3),
        prefixIcon: Icon(icon, color: skin.colors.text3, size: 20),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: skin.colors.cardBgAlt,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(context.design.radius.md),
          borderSide: BorderSide(color: skin.colors.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(context.design.radius.md),
          borderSide: BorderSide(color: skin.colors.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(context.design.radius.md),
          borderSide: BorderSide(color: MistralColors.primary, width: 2),
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Widget _buildSocialLoginButton({
    required SkinSystem skin,
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    bool outlined = false,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: outlined
          ? OutlinedButton.icon(
              onPressed: onTap,
              icon: Icon(icon, color: color, size: 20),
              label: Text(label, style: TextStyle(color: color)),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: skin.colors.divider),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(context.design.radius.md)),
              ),
            )
          : ElevatedButton.icon(
              onPressed: onTap,
              icon: Icon(icon, color: AppColors.white100, size: 20),
              label: Text(label, style: const TextStyle(color: AppColors.white100)),
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(context.design.radius.md)),
              ),
            ),
    );
  }

}
