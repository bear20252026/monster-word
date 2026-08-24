// 由 Claude 团队生成 | Monster Word App

// 移植自 v3.2 ExtensiveModelSelectActivity
// 泛听模式选择：选择随身听的播放模式
import 'package:flutter/material.dart';

import '../theme/skin_system.dart';
import '../tokens/design_tokens.dart';

class ListenMode {
  final String name;
  final String description;
  final IconData icon;

  const ListenMode({
    required this.name,
    required this.description,
    required this.icon,
  });
}

class ExtensiveModelSelectPage extends StatefulWidget {
  const ExtensiveModelSelectPage({super.key});

  static const routeName = '/listen_mode_select';

  @override
  State<ExtensiveModelSelectPage> createState() => _ExtensiveModelSelectPageState();
}

class _ExtensiveModelSelectPageState extends State<ExtensiveModelSelectPage> {
  final List<ListenMode> _modes = [
    const ListenMode(
      name: '单词+释义',
      description: '播放单词发音后播放中文释义',
      icon: Icons.translate,
    ),
    const ListenMode(
      name: '仅单词',
      description: '只播放单词发音',
      icon: Icons.hearing,
    ),
    const ListenMode(
      name: '单词+例句',
      description: '播放单词后播放例句',
      icon: Icons.format_quote,
    ),
    const ListenMode(
      name: '释义+单词',
      description: '先播放中文释义再播放单词',
      icon: Icons.swap_horiz,
    ),
  ];

  int _selectedIndex = 0;

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
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _modes.length,
                itemBuilder: (context, index) {
                  final mode = _modes[index];
                  final isSelected = _selectedIndex == index;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedIndex = index),
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
                          Container(
                            width: 44, height: 44,
                            decoration: BoxDecoration(
                              color: MistralColors.cream,
                              borderRadius: BorderRadius.circular(AppRadius.md),
                            ),
                            child: Icon(mode.icon, color: MistralColors.primary, size: 24),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(mode.name, style: MistralTypography.bodyBold.copyWith(
                                  color: skin.colors.text1,
                                )),
                                Text(mode.description, style: MistralTypography.bodySm.copyWith(
                                  color: skin.colors.text3,
                                )),
                              ],
                            ),
                          ),
                          if (isSelected)
                            Icon(Icons.check_circle, color: MistralColors.primary, size: 24),
                        ],
                      ),
                    ),
                  );
                },
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
          Text('泛听模式', style: MistralTypography.heading5.copyWith(color: skin.colors.text1)),
        ],
      ),
    );
  }
}
