// 账号信息页：还原 v3.2 原版账号信息页布局
// 包含：头像 + 相机图标、ID账号、账号、昵称、手机号、绑定平台
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../theme/skin_system.dart';
import '../../../tokens/design_tokens.dart';
import 'account_profile_state.dart';

class AccountInfoPage extends StatefulWidget {
  const AccountInfoPage({super.key});

  static const routeName = '/account_info';

  @override
  State<AccountInfoPage> createState() => _AccountInfoPageState();
}

class _AccountInfoPageState extends State<AccountInfoPage> {
  AccountProfileState get _profile => context.read<AccountProfileState>();

  Future<void> _editNickname() async {
    final controller = TextEditingController(text: _profile.nickname);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('修改昵称'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: '输入昵称'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(ctx, controller.text), child: const Text('保存')),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      await _profile.updateNickname(result);
    }
  }

  Future<void> _editWechatName() async {
    final controller = TextEditingController(text: _profile.wechatName);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('修改微信名'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: '输入微信名'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(ctx, controller.text), child: const Text('保存')),
        ],
      ),
    );
    if (result != null) {
      await _profile.updateWechatName(result);
    }
  }

  Future<void> _editUserId() async {
    final controller = TextEditingController(text: _profile.displayId);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('修改个人ID'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: '输入你的个人ID'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(ctx, controller.text), child: const Text('保存')),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      await _profile.updateDisplayId(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin.colors;
    final profile = context.watch<AccountProfileState>();

    return Scaffold(
      backgroundColor: skin.pageBg,
      body: SafeArea(
        child: Column(
          children: [
            _buildNavBar(context, skin),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
                child: Column(
                  children: [
                    const SizedBox(height: 24),
                    _buildAvatarSection(skin),
                    const SizedBox(height: 32),
                    _buildInfoCard(context, skin, profile),
                    const SizedBox(height: 16),
                    _buildBindCard(context, skin, profile),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavBar(BuildContext context, ThemeVars skin) {
    return Container(
      height: AppSpacing.navH,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
            color: skin.text1,
            onPressed: () => Navigator.pop(context),
          ),
          const Spacer(),
          Text('账号信息', style: MistralTypography.heading5.copyWith(color: skin.text1)),
          const Spacer(),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildAvatarSection(ThemeVars skin) {
    return Center(
      child: Stack(
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [skin.cardBg, skin.cardBgAlt],
              ),
              border: Border.all(color: skin.divider, width: 2),
            ),
            child: Icon(Icons.person, color: skin.text3, size: 44),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: skin.accent,
                border: Border.all(color: skin.cardBg, width: 2),
              ),
              child: const Icon(Icons.camera_alt, color: Color(0xFFFFFFFF), size: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context, ThemeVars skin, AccountProfileState profile) {
    return Container(
      decoration: BoxDecoration(color: skin.cardBg, borderRadius: BorderRadius.circular(AppRadius.xl)),
      child: Column(
        children: [
          _buildInfoRow(
            skin,
            label: 'ID账号',
            value: profile.displayId.isEmpty ? '点击设置' : profile.displayId,
            onTap: _editUserId,
          ),
          _buildDivider(skin),
          _buildInfoRow(
            skin,
            label: '账号',
            value: profile.wechatName.isEmpty ? '点击设置' : '微信：${profile.wechatName}',
            onTap: _editWechatName,
          ),
          _buildDivider(skin),
          _buildInfoRow(
            skin,
            label: '昵称',
            value: profile.nickname.isEmpty ? '点击设置' : profile.nickname,
            onTap: _editNickname,
          ),
          _buildDivider(skin),
          _buildInfoRow(skin, label: '手机号', value: '点击设置', onTap: () {}),
        ],
      ),
    );
  }

  Widget _buildBindCard(BuildContext context, ThemeVars skin, AccountProfileState profile) {
    return Container(
      decoration: BoxDecoration(color: skin.cardBg, borderRadius: BorderRadius.circular(AppRadius.xl)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text('绑定平台', style: MistralTypography.body.copyWith(color: skin.text2, fontSize: 13)),
          ),
          _buildBindRow(
            skin,
            icon: Icons.chat_bubble,
            iconColor: const Color(0xFF07C160),
            platform: '微信',
            isBound: profile.wechatName.isNotEmpty,
            boundName: profile.wechatName,
            onTap: _editWechatName,
          ),
          _buildDivider(skin),
          _buildBindRow(
            skin,
            icon: Icons.circle,
            iconColor: const Color(0xFF12B7F5),
            platform: 'QQ',
            isBound: false,
            onTap: () {},
          ),
          _buildDivider(skin),
          _buildBindRow(
            skin,
            icon: Icons.language,
            iconColor: const Color(0xFFE6162D),
            platform: '微博',
            isBound: false,
            onTap: () {},
          ),
          _buildDivider(skin),
          _buildBindRow(
            skin,
            icon: Icons.apple,
            iconColor: skin.text1,
            platform: 'Apple ID',
            isBound: false,
            onTap: () {},
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _buildInfoRow(ThemeVars skin, {required String label, required String value, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.xl),
      child: Container(
        height: AppSpacing.rowH,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Text(label, style: MistralTypography.body.copyWith(color: skin.text1)),
            const Spacer(),
            Text(value, style: MistralTypography.body.copyWith(color: skin.text2)),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, size: 18, color: skin.text3),
          ],
        ),
      ),
    );
  }

  Widget _buildBindRow(
    ThemeVars skin, {
    required IconData icon,
    required Color iconColor,
    required String platform,
    required bool isBound,
    String? boundName,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.xl),
      child: Container(
        height: AppSpacing.rowH,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 16, color: iconColor),
            ),
            const SizedBox(width: 12),
            Text(platform, style: MistralTypography.body.copyWith(color: skin.text1)),
            const Spacer(),
            if (isBound && boundName != null)
              Text(boundName, style: MistralTypography.body.copyWith(color: skin.text2))
            else
              Text('未绑定', style: MistralTypography.body.copyWith(color: skin.text3)),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, size: 18, color: skin.text3),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider(ThemeVars skin) {
    return Divider(height: 0.5, thickness: 0.5, indent: 16, endIndent: 16, color: skin.divider);
  }
}
