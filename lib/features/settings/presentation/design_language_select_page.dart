// 设计语言选择页（B档：字体/圆角/间距/阴影的整体风格切换）
// 运行时通过 context.skin.setDesignLanguage(id) 切换，SkinProvider(InheritedNotifier)
// 通知所有依赖 context.design 的页面即时重建 —— 这就是设计语言动态切换的可见入口。
import 'package:flutter/material.dart';

import 'package:word_app/theme/skin_system.dart';
import 'package:word_app/tokens/design_language.dart';

class DesignLanguageSelectPage extends StatelessWidget {
  const DesignLanguageSelectPage({super.key});

  static const routeName = '/design_language';

  @override
  Widget build(BuildContext context) {
    final skin = context.skin.colors;
    final design = context.design;

    return Scaffold(
      backgroundColor: skin.pageBg,
      body: SafeArea(
        child: Column(
          children: [
            _buildNavBar(context, skin),
            Container(height: 1, color: skin.divider),
            Expanded(
              child: ListView(
                padding: EdgeInsets.all(design.spacing.page),
                children: [
                  Text('设计语言（B档）', style: TextStyle(fontSize: 13, color: skin.text3)),
                  SizedBox(height: design.spacing.xxs),
                  Text('一键切换整站字体、圆角、间距与阴影的风格气质，即时生效。', style: TextStyle(fontSize: 12, color: skin.text3)),
                  SizedBox(height: design.spacing.md),
                  // 动态渲染所有可用设计语言；选中即整站换肤（A 档品牌色 + B 档形态联动）
                  ...DesignLanguages.all.values.map((lang) {
                    final isSelected = context.skin.designLanguageId == lang.id;
                    return Padding(
                      padding: EdgeInsets.only(bottom: design.spacing.sm),
                      child: _buildDesignOption(
                        context: context,
                        lang: lang,
                        isSelected: isSelected,
                        onTap: () => context.skin.setBrandStyle(lang.id),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavBar(BuildContext context, dynamic skin) {
    final design = context.design;
    return Container(
      height: 48,
      padding: EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
            color: skin.text1,
            onPressed: () => Navigator.pop(context),
          ),
          SizedBox(width: 4),
          Text(
            '设计语言',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: skin.text1),
          ),
          const Spacer(),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: design.spacing.page),
            child: Text('风格', style: TextStyle(fontSize: 12, color: skin.text3)),
          ),
        ],
      ),
    );
  }

  Widget _buildDesignOption({
    required BuildContext context,
    required DesignLanguage lang,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final skin = context.skin.colors;
    final design = context.design;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: EdgeInsets.all(design.spacing.md),
        decoration: BoxDecoration(
          color: skin.cardBgAlt,
          borderRadius: BorderRadius.circular(design.radius.lg),
          border: Border.all(color: isSelected ? skin.accent : skin.divider, width: isSelected ? 2 : 1),
        ),
        child: Row(
          children: [
            // 用「该语言自己的 radius/spacing」渲染预览卡，直观展示风格差异
            _buildPreviewCard(skin: skin, lang: lang),
            SizedBox(width: design.spacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lang.name,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: skin.text1),
                  ),
                  SizedBox(height: design.spacing.xxs),
                  Text(_langDescription(lang.id), style: TextStyle(fontSize: 12, color: skin.text3)),
                ],
              ),
            ),
            if (isSelected) Icon(Icons.check_circle, color: skin.accent, size: 24),
          ],
        ),
      ),
    );
  }

  /// 预览卡：用该设计语言的 radius + spacing 渲染一条「圆角胶囊 + 细条」的迷你卡片
  Widget _buildPreviewCard({required dynamic skin, required DesignLanguage lang}) {
    return Container(
      width: 104,
      height: 64,
      padding: EdgeInsets.all(lang.spacing.sm),
      decoration: BoxDecoration(
        color: skin.cardBg,
        borderRadius: BorderRadius.circular(lang.radius.xl),
        border: Border.all(color: skin.divider),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 12,
            decoration: BoxDecoration(color: skin.accent, borderRadius: BorderRadius.circular(lang.radius.pill)),
          ),
          SizedBox(height: lang.spacing.xs),
          Container(
            width: 30,
            height: 6,
            decoration: BoxDecoration(color: skin.text2, borderRadius: BorderRadius.circular(lang.radius.pill)),
          ),
          SizedBox(height: lang.spacing.xxs),
          Container(
            width: 22,
            height: 6,
            decoration: BoxDecoration(color: skin.text3, borderRadius: BorderRadius.circular(lang.radius.pill)),
          ),
        ],
      ),
    );
  }

  String _langDescription(String id) {
    switch (id) {
      case 'starbucks':
        return '星巴克 · 奶油画布品牌绿，12px 卡片 + 全胶囊按钮';
      case 'airbnb':
        return 'Airbnb · 纯白画布 Rausch 珊瑚，圆润亲和';
      case 'nike':
        return 'Nike · 黑白单色零圆角卡片 + 全胶囊按钮';
      case 'clickhouse':
        return 'ClickHouse · 近纯黑夜 + 电光黄，高密度';
      case 'apple':
        return 'Apple · 珍珠白羊皮纸 + 单一蓝，精密克制';
      case 'claude':
        return 'Claude · 暖奶油 + 赤陶珊瑚，衬线人文';
      default:
        return '';
    }
  }
}
