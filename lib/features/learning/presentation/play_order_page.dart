// 由 Claude 团队生成 | Monster Word App

// 播放顺序：设置随身听的单词播放顺序（持久化到 AppPreferences，被随身听消费）
import 'dart:async';

import 'package:flutter/material.dart';

import 'package:word_app/core/infrastructure/app_preferences.dart';
import 'package:word_app/features/learning/application/play_order.dart';
import 'package:word_app/theme/skin_system.dart';
import 'package:word_app/tokens/design_tokens.dart';

export 'package:word_app/features/learning/application/play_order.dart' show PlayOrder;

class PlayOrderPage extends StatefulWidget {
  const PlayOrderPage({super.key});

  static const routeName = '/play_order';

  /// 播放顺序的持久化键（随身听播放器读取同一 key）。
  static const prefKey = 'stereo.play_order';

  @override
  State<PlayOrderPage> createState() => _PlayOrderPageState();
}

class _PlayOrderPageState extends State<PlayOrderPage> {
  final AppPreferences _prefs = AppPreferences();
  PlayOrder _selected = PlayOrder.sequential;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    await _prefs.init();
    if (!mounted) return;
    final saved = _prefs.getString(PlayOrderPage.prefKey);
    setState(() {
      _selected = PlayOrder.values.where((order) => order.name == saved).firstOrNull ?? PlayOrder.sequential;
    });
  }

  Future<void> _select(PlayOrder order) async {
    setState(() => _selected = order);
    await _prefs.setString(PlayOrderPage.prefKey, order.name);
  }

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
                    onTap: () => unawaited(_select(order)),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: skin.colors.cardBgAlt,
                        borderRadius: BorderRadius.circular(context.design.radius.lg),
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
