// 由 Claude 团队生成 | Monster Word App

// 移植自 v3.2 PlayOrderActivity
// 播放顺序：设置随身听的单词播放顺序
import 'package:flutter/material.dart';

import '../theme/skin_system.dart';
import '../tokens/design_tokens.dart';

enum PlayOrder {
  sequential('顺序播放', Icons.format_list_numbered),
  reverse('逆序播放', Icons.format_list_numbered),
  random('随机播放', Icons.shuffle),
  alphabetical('字母顺序', Icons.sort_by_alpha);

  final String label;
  final IconData icon;
  const PlayOrder(this.label, this.icon);
}

class PlayOrderPage extends StatefulWidget {
  const PlayOrderPage({super.key});

  static const routeName = '/play_order';

  @override
  State<PlayOrderPage> createState() => _PlayOrderPageState();
}

class _PlayOrderPageState extends State<PlayOrderPage> {
  PlayOrder _selected = PlayOrder.sequential;

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
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: PlayOrder.values.map((order) {
                  final isSelected = _selected == order;
                  return GestureDetector(
                    onTap: () => setState(() => _selected = order),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: skin.colors.cardBgAlt,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        border: Border.all(
                          color: isSelected ? MistralColors.primary : skin.colors.divider,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(order.icon, color: isSelected ? MistralColors.primary : skin.colors.text3, size: 24),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              order.label,
                              style: MistralTypography.bodyBold.copyWith(
                                color: isSelected ? MistralColors.primary : skin.colors.text1,
                              ),
                            ),
                          ),
                          if (isSelected) Icon(Icons.check_circle, color: MistralColors.primary, size: 24),
                        ],
                      ),
                    ),
                  );
                }).toList(),
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
          Text('播放顺序', style: MistralTypography.heading5.copyWith(color: skin.colors.text1)),
        ],
      ),
    );
  }
}
