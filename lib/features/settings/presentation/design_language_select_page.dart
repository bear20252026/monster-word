// 设计语言选择页：已收敛为「精选风格」网格（6 选 1，颜色 + 形态一次绑定）。
// 历史上本页单独切换 B 档设计语言，与主题选择形成双轴混乱；
// 现与其他换肤入口共用 MwStyleGrid，全应用只有一个风格事实来源。
import 'package:flutter/material.dart';

import 'package:word_app/theme/skin_system.dart';
import 'package:word_app/tokens/design_tokens.dart';
import 'package:word_app/widgets/mw_style_grid.dart';

class DesignLanguageSelectPage extends StatelessWidget {
  const DesignLanguageSelectPage({super.key});

  static const routeName = '/design_language';

  @override
  Widget build(BuildContext context) {
    final skin = context.skin.colors;

    return Scaffold(
      backgroundColor: skin.pageBg,
      body: SafeArea(
        child: Column(
          children: [
            _buildNavBar(context, skin),
            Container(height: 1, color: skin.divider),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text('风格', style: MwTypography.caption.copyWith(color: skin.text3)),
                  const SizedBox(height: 4),
                  Text(
                    '每个风格已配好配色与字体、圆角、间距、阴影的整体气质，选择即全站生效。',
                    style: TextStyle(fontSize: 12, height: 1.5, color: skin.text3),
                  ),
                  const SizedBox(height: 16),
                  const MwStyleGrid(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavBar(BuildContext context, dynamic skin) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
            color: skin.text1,
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 4),
          Text(
            '风格设置',
            style: MwTypography.bodyBold.copyWith(fontWeight: FontWeight.w600, color: skin.text1),
          ),
        ],
      ),
    );
  }
}
