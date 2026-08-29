// 由 Claude 团队生成 | Monster Word App

// 移植自 v3.2 MyEquipActivity
// 我的装备：显示已解锁的学习装备/道具
import 'package:flutter/material.dart';

import '../../../theme/skin_system.dart';
import '../../../tokens/design_tokens.dart';

class MyEquipPage extends StatelessWidget {
  const MyEquipPage({super.key});

  static const routeName = '/my_equip';

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;

    return Scaffold(
      backgroundColor: skin.colors.pageBg,
      body: SafeArea(
        child: Column(
          children: [
            _buildNavBar(skin, context),
            Container(height: 1, color: skin.colors.divider),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.inventory_2_outlined, size: 64, color: skin.colors.text3),
                    SizedBox(height: 16),
                    Text('暂无装备', style: MistralTypography.body.copyWith(color: skin.colors.text3)),
                    SizedBox(height: 8),
                    Text('完成学习任务解锁装备', style: MistralTypography.bodySm.copyWith(color: skin.colors.text3)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavBar(SkinSystem skin, BuildContext context) {
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
          Text('我的装备', style: MistralTypography.heading5.copyWith(color: skin.colors.text1)),
        ],
      ),
    );
  }
}
