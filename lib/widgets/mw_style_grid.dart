// Monster Word — 精选风格网格（6 选 1 的唯一换肤界面）
// 外观页 / 主题选择页 / 设计语言页共用此组件，杜绝多处入口展示不一致。
import 'package:flutter/material.dart';

import 'package:word_app/theme/skin_system.dart';
import 'package:word_app/widgets/scale_down_on_press.dart';

/// 6 个精选风格卡片网格：每卡为「画布预览条 + 名称 + 一句气质描述」。
class MwStyleGrid extends StatelessWidget {
  const MwStyleGrid({super.key, this.columns = 2, this.aspectRatio = 1.25});

  /// 列数（宽屏可给 3）
  final int columns;

  /// 卡片宽高比
  final double aspectRatio;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final selectedId = skin.currentStyleId;
    return GridView.count(
      crossAxisCount: columns,
      childAspectRatio: aspectRatio,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      children: kMwStyles.map((style) {
        final vars = themes[style.themeId]!.vars;
        final isSelected = style.id == selectedId;
        return ScaleDownOnPress(
          onTap: () => skin.setStyle(style.id),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: skin.colors.cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? skin.colors.accent : skin.colors.divider,
                width: isSelected ? 1.6 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 画布预览条：三块色板 + 选中角标
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Row(
                          children: [
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: vars.pageBg,
                                  borderRadius: const BorderRadius.horizontal(left: Radius.circular(10)),
                                  border: Border.all(color: skin.colors.divider, width: 0.5),
                                ),
                              ),
                            ),
                            const SizedBox(width: 2),
                            Expanded(child: Container(color: vars.cardBgAlt)),
                            const SizedBox(width: 2),
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: vars.accent,
                                  borderRadius: const BorderRadius.horizontal(right: Radius.circular(10)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isSelected)
                        Positioned(
                          top: 6,
                          right: 6,
                          child: Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: skin.colors.accent,
                              shape: BoxShape.circle,
                              border: Border.all(color: skin.colors.cardBg, width: 1.5),
                            ),
                            child: const Icon(Icons.check_rounded, size: 14, color: Colors.white),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  style.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                    color: isSelected ? skin.colors.accent : skin.colors.text1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  style.desc,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, height: 1.3, color: skin.colors.text3),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
