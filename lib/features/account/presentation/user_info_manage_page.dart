// 由 Claude 团队生成 | Monster Word App

// 移植自 v3.2 UserInfoManageActivity
// 用户信息管理：修改头像、昵称、签名等个人信息
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:word_app/core/router/nav_utils.dart';
import 'package:word_app/theme/skin_system.dart';
import 'package:word_app/tokens/design_tokens.dart';
import 'package:word_app/features/account/presentation/account_profile_state.dart';

class UserInfoManagePage extends StatefulWidget {
  const UserInfoManagePage({super.key});

  static const routeName = '/user_info_manage';

  @override
  State<UserInfoManagePage> createState() => _UserInfoManagePageState();
}

class _UserInfoManagePageState extends State<UserInfoManagePage> {
  AccountProfileState get _profile => context.read<AccountProfileState>();

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final profile = context.watch<AccountProfileState>();

    return Scaffold(
      backgroundColor: skin.colors.pageBg,
      body: SafeArea(
        child: Column(
          children: [
            _buildNavBar(skin),
            Container(height: 1, color: skin.colors.divider),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    SizedBox(height: 24),
                    // 头像
                    Semantics(
                      label: '更换头像',
                      button: true,
                      child: InkWell(
                        onTap: _changeAvatar,
                        borderRadius: BorderRadius.circular(40),
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(colors: [MistralColors.cream, MistralColors.creamDeeper]),
                            border: Border.all(color: MistralColors.hairline, width: 2),
                          ),
                          child: Icon(Icons.person, size: 40, color: MistralColors.stone),
                        ),
                      ),
                    ),
                    SizedBox(height: 8),
                    Text('点击更换头像', style: MistralTypography.micro.copyWith(color: MistralColors.link)),
                    SizedBox(height: 24),
                    _buildInfoTile(
                      skin,
                      '昵称',
                      profile.nickname.isEmpty ? '点击设置' : profile.nickname,
                      () => _editField('昵称', profile.nickname, _profile.updateNickname),
                    ),
                    _buildInfoTile(
                      skin,
                      '微信名',
                      profile.wechatName.isEmpty ? '点击设置' : profile.wechatName,
                      () => _editField('微信名', profile.wechatName, _profile.updateWechatName),
                    ),
                    _buildInfoTile(
                      skin,
                      '签名',
                      profile.signature.isEmpty ? '未设置' : profile.signature,
                      () => _editField('签名', profile.signature, _profile.updateSignature),
                    ),
                    _buildInfoTile(skin, '手机号', '未绑定', null),
                    _buildInfoTile(skin, '注册时间', '—', null, isReadOnly: true),
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
      padding: EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
            color: skin.colors.text1,
            onPressed: () => NavUtils.safePop(context),
          ),
          SizedBox(width: 4),
          Text('个人信息', style: MistralTypography.heading5.copyWith(color: skin.colors.text1)),
        ],
      ),
    );
  }

  Widget _buildInfoTile(SkinSystem skin, String label, String value, VoidCallback? onTap, {bool isReadOnly = false}) {
    return GestureDetector(
      onTap: isReadOnly ? null : onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: skin.colors.divider)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 80,
              child: Text(label, style: MistralTypography.body.copyWith(color: skin.colors.text3)),
            ),
            Expanded(
              child: Text(
                value,
                style: MistralTypography.body.copyWith(color: isReadOnly ? skin.colors.text3 : skin.colors.text1),
              ),
            ),
            if (onTap != null && !isReadOnly) Icon(Icons.chevron_right, color: skin.colors.text3, size: 20),
          ],
        ),
      ),
    );
  }

  void _changeAvatar() {
    // TODO: 选择图片（功能开发中，暂时隐藏入口）
    // ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('选择头像功能开发中')));
  }

  Future<void> _editField(String label, String current, Future<void> Function(String) onSave) async {
    final controller = TextEditingController(text: current);
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('修改$label'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(hintText: '请输入$label'),
        ),
        actions: [
          TextButton(onPressed: () => NavUtils.safePop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () async {
              await onSave(controller.text.trim());
              if (ctx.mounted) NavUtils.safePop(ctx);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
    controller.dispose();
  }
}
