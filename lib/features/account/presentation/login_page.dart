// 由 Claude 团队生成 | Monster Word App

// 登录页：仅账号密码登录。
//
// 2026-10-13 移除短信链路：Spug 官方文档明确要求「验证码发送必须由业务服务端
// 发起，不要把模板编码放入网页或移动端安装包」，而本项目此前由客户端直连
// Spug（模板编码随包分发，即 R2-01 P0）。短信原本只服务两件事，都不是必需的：
//   - 手机号登录：删除（账号密码登录是主路径，且本来就是本机真校验）；
//   - 忘记密码：改为提示联系管理员（服务端就绪后由后台重置）。
// 收益：仓库与安装包里不再有任何短信调用凭证 —— R2-01 整体关闭；同时少一个
// 网络依赖（push.spug.cc）与一条隐私政策披露。
import 'package:word_app/widgets/common/mw_feedback.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:word_app/app/router/route_names.dart';
import 'package:provider/provider.dart';

import 'package:word_app/app/router/nav_utils.dart';
import 'package:word_app/theme/skin_system.dart';
import 'package:word_app/tokens/design_tokens.dart';
import 'package:word_app/widgets/monster_icon.dart';
import 'package:word_app/widgets/monster_peek_overlay.dart';
import 'package:word_app/widgets/animations.dart';
import 'package:word_app/features/account/application/password_auth_store.dart';
import 'package:word_app/features/account/application/legal_consent_store.dart';
import 'package:word_app/features/account/domain/legal_documents.dart';
import 'package:word_app/core/utils/swallowed_error_report.dart';
import 'package:word_app/features/account/presentation/app_session_state.dart';
import 'package:word_app/core/utils/monster_identity_prefs.dart';
import 'package:word_app/features/account/presentation/legal_document_page.dart';
import 'package:word_app/features/account/presentation/monster_hatching_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  static const routeName = RouteNames.login;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with SingleTickerProviderStateMixin {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
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
    _usernameController.dispose();
    _passwordController.dispose();
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

    // 本机账号闭环：首次登录即创建（用户确认后），此后真校验密码。
    // 密码校验走 PasswordAuthStore（盐值+哈希存平台安全存储），会话仍走本地语义。
    final auth = context.read<PasswordAuthStore>();
    // 错误处理审计 P2：hasPassword 同样走 flutter_secure_storage，无兜底时
    // 平台异常会让整个 _loginWithCoolID 的 Future 未处理。
    bool hasAccount;
    try {
      hasAccount = await auth.hasPassword(username);
    } catch (e) {
      if (mounted) _showToast('本机凭证读取失败，请重试');
      return;
    }
    if (!hasAccount) {
      final confirmed = await _confirmCreateLocalAccount(username);
      if (!confirmed || !mounted) return;
      try {
        await auth.setPassword(username, password);
      } catch (e) {
        if (mounted) _showToast('创建本机账号失败：$e');
        return;
      }
    } else {
      // 错误处理审计 P2：flutter_secure_storage 平台调用（系统还原/
      // Keystore 故障）可能抛 PlatformException，此前无兜底会让登录按钮
      // “点了没反应”。
      bool verified;
      try {
        verified = await auth.verify(username, password);
      } catch (e) {
        if (mounted) _showToast('本机凭证读取失败，请重试');
        return;
      }
      if (!verified) {
        if (mounted) _showToast('账号或密码不正确');
        return;
      }
    }

    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      if (!mounted) return;
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

  /// 首次使用账号密码登录：确认创建本机账号（密码哈希仅存本机）。
  Future<bool> _confirmCreateLocalAccount(String username) async {
    if (!mounted) return false;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('创建本机账号'),
        content: Text('「$username」首次使用，将把当前密码保存为本机登录密码（仅存本机，不上传）。\n\n继续使用该账号密码登录即视为创建。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('确认创建')),
        ],
      ),
    );
    return confirmed == true;
  }

  /// 忘记密码：提示联系管理员。
  ///
  /// 2026-10-13：原实现走「账号绑定手机号 → 短信验证码 → 重置本机密码」，
  /// 随短信链路一并移除（Spug 官方要求验证码由服务端发起，见文件头注释）。
  ///
  /// 这里**不做自助重置**：密码哈希只存在本机安全存储，客户端没有能力证明
  /// 「你是账号主人」——任何自助通道都等价于「谁拿到设备谁就能改密码」，
  /// 反而会把登录降级成摆设。真正的重置要等 R2-01 阶段二（服务端账号）上线，
  /// 由管理员在后台完成。
  Future<void> _forgotPassword() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('忘记密码'),
        content: const Text(
          '本机登录密码只保存在这台设备上，无法远程重置。\n\n'
          '请联系管理员协助处理。\n\n'
          '如需自行处理，可在系统设置中清除本应用数据后重新创建账号'
          '（会一并清除本机学习记录，请谨慎操作）。',
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('知道了'))],
      ),
    );
  }

  void _onLoginSuccess() {
    // MW-78：协议同意留痕——登录成功即视为同意当前版本协议，落
    // policyVersion + acceptedAt。写入失败不阻断登录（留痕是合规补强，
    // 不改变登录语义），但必须可观测。
    unawaited(_recordLegalConsent(context.read<LegalConsentStore>()));
    // 史诗化 W1：登录成功怪兽开门惊喜——探头演出挂在根 Overlay（跨路由存活），
    // 先起「欢迎回家！」再延迟切首页，给这一拍留出可见时刻。
    MonsterPeekOverlay.show(context, phrase: '欢迎回家！');
    final navigator = Navigator.of(context);
    Future<void>.delayed(const Duration(milliseconds: 900), () async {
      // 蓝图 W4 命名仪式：首次登录（未破壳）先进开局仪式，完成后再进主页。
      // 此前直接 push '/'，新用户的命名/生日/羁绊起点全部缺失，需重启才能补演。
      var hatched = true;
      try {
        hatched = await MonsterIdentityPrefs.hatched;
      } catch (e, s) {
        // 读不到按「已破壳」降级直进主页（fail-safe 口径与 splash _goToMain 一致）。
        reportSwallowedError('登录后读取破壳标记失败', e, s);
      }
      if (!navigator.mounted) return;
      if (!hatched) {
        navigator.pushReplacement(MaterialPageRoute<void>(builder: (_) => const MonsterHatchingPage()));
        return;
      }
      navigator.pushReplacementNamed('/');
    });
  }

  /// MW-78：协议同意留痕（policyVersion + acceptedAt）。
  Future<void> _recordLegalConsent(LegalConsentStore store) async {
    try {
      await store.record(LegalDocuments.policyVersion);
    } catch (e, s) {
      reportSwallowedError('协议同意留痕失败', e, s);
    }
  }

  /// MW-78：打开协议正文页（纯本地渲染，离线可用）。
  void _openLegalDocument(LegalDocument document) {
    Navigator.of(context).push(LegalDocumentPage.route(document));
  }

  void _showToast(String msg) {
    showMwSnackBar(context, SnackBar(content: Text(msg), duration: const Duration(seconds: 2)));
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;

    // 2026-10-13：登录页只剩一个视图（账号密码），系统返回键一律走退出确认。
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _showExitConfirmDialog(context);
        }
      },
      child: Scaffold(
        backgroundColor: skin.colors.pageBg,
        body: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: SlideTransition(position: _slideAnim, child: _buildLoginView(skin)),
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

  /// 唯一登录视图：品牌头 + 账号密码表单。
  ///
  /// 2026-10-13：原「主登录选择页 → 输入页」两级结构随手机号登录一并移除；
  /// 品牌标记保留，表单直接展开，少一次点击。
  Widget _buildLoginView(SkinSystem skin) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: 40),
          // 品牌标记：怪兽头像 + 强调色柔环
          Center(
            child: SizedBox(
              width: 108,
              height: 108,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: skin.colors.accent.withValues(alpha: AppAlphas.o06),
                      border: Border.all(color: skin.colors.accent.withValues(alpha: AppAlphas.o18), width: 1),
                    ),
                  ),
                  const MonsterAvatar(size: 72),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          // 衬线词标
          Center(
            child: Text(
              'Monster Word',
              style: TextStyle(
                fontFamily: 'Charter',
                fontSize: AppFontSizes.stat,
                fontWeight: FontWeight.w400,
                letterSpacing: -0.5,
                color: skin.colors.text1,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text('在语境中学习单词', style: MwTypography.body.copyWith(color: skin.colors.text2)),
          ),
          const SizedBox(height: 32),
          // 上次登录信息
          if (_lastLoginAccountInfo != null && _lastLoginAccountInfo!.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(bottom: AppSpacing.xs),
              child: Text('上次登录：$_lastLoginAccountInfo', style: MwTypography.bodySm.copyWith(color: skin.colors.text3)),
            ),
          _buildTextField(controller: _usernameController, hint: '请输入用户名', icon: Icons.person_outline, skin: skin),
          SizedBox(height: 16),
          _buildTextField(
            controller: _passwordController,
            hint: '请输入密码',
            icon: Icons.lock_outline,
            obscure: !_isPasswordVisible,
            skin: skin,
            suffixIcon: IconButton(
              icon: Icon(_isPasswordVisible ? Icons.visibility : Icons.visibility_off, color: skin.colors.text3),
              onPressed: () {
                setState(() => _isPasswordVisible = !_isPasswordVisible);
              },
            ),
          ),
          SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _forgotPassword,
              child: Text('忘记密码？', style: MwTypography.bodySm.copyWith(color: skin.colors.accent)),
            ),
          ),
          SizedBox(height: 16),
          // 登录按钮
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: _isLoading
                  ? null
                  : () => _loginWithCoolID(_usernameController.text.trim(), _passwordController.text.trim()),
              style: ElevatedButton.styleFrom(
                backgroundColor: skin.colors.accent,
                foregroundColor: AppColors.white100,
                disabledBackgroundColor: skin.colors.text2,
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
          SizedBox(height: 24),
          // 用户协议 / 隐私政策（MW-78：可点击查看正文，此前只是不可点的文字）
          Text.rich(
            TextSpan(
              text: '登录即同意 ',
              style: MwTypography.micro.copyWith(color: skin.colors.text3),
              children: [
                WidgetSpan(
                  alignment: PlaceholderAlignment.baseline,
                  baseline: TextBaseline.alphabetic,
                  child: _LegalLink(label: '用户协议', onTap: () => _openLegalDocument(LegalDocuments.userAgreement)),
                ),
                const TextSpan(text: ' 和 '),
                WidgetSpan(
                  alignment: PlaceholderAlignment.baseline,
                  baseline: TextBaseline.alphabetic,
                  child: _LegalLink(label: '隐私政策', onTap: () => _openLegalDocument(LegalDocuments.privacyPolicy)),
                ),
              ],
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 24),
        ],
      ),
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
      style: MwTypography.body.copyWith(color: skin.colors.text1),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: MwTypography.body.copyWith(color: skin.colors.text3),
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
          borderSide: BorderSide(color: context.skin.colors.accent, width: 2),
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}

/// MW-78：协议链接（登录页「用户协议 / 隐私政策」）。
///
/// 用下划线 + 主题强调色表达可点击；语义层声明为按钮并给出「查看 XXX」标签，
/// 读屏用户不必依赖颜色推断可交互性。
class _LegalLink extends StatelessWidget {
  const _LegalLink({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '查看$label',
      child: GestureDetector(
        onTap: onTap,
        child: Text(
          label,
          style: MwTypography.micro.copyWith(color: context.skin.colors.accent, decoration: TextDecoration.underline),
        ),
      ),
    );
  }
}
