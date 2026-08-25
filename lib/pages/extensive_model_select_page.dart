// 由 Claude 团队生成 | Monster Word App

// 移植自 v3.2 ExtensiveModelSelectActivity
// 泛听模式选择：选择随身听的播放模式
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/wordbook_database.dart';
import '../hooks/responsive.dart';
import '../pages/listening_player_page.dart';
import '../state/learning_state.dart';
import '../theme/skin_system.dart';
import '../tokens/design_tokens.dart';

class ListenMode {
  final String name;
  final String description;
  final IconData icon;
  final ListeningMode playerMode;

  const ListenMode({
    required this.name,
    required this.description,
    required this.icon,
    required this.playerMode,
  });
}

class ExtensiveModelSelectPage extends StatefulWidget {
  final int bookId;
  final String bookName;

  const ExtensiveModelSelectPage({
    super.key,
    required this.bookId,
    this.bookName = '',
  });

  static const routeName = '/listen_mode_select';

  @override
  State<ExtensiveModelSelectPage> createState() => _ExtensiveModelSelectPageState();
}

class _ExtensiveModelSelectPageState extends State<ExtensiveModelSelectPage> {
  final List<ListenMode> _modes = const [
    ListenMode(
      name: '单词+释义',
      description: '播放单词发音后播放中文释义',
      icon: Icons.translate,
      playerMode: ListeningMode.wordMeaning,
    ),
    ListenMode(
      name: '仅单词',
      description: '只播放单词发音',
      icon: Icons.hearing,
      playerMode: ListeningMode.wordOnly,
    ),
    ListenMode(
      name: '单词+例句',
      description: '播放单词后播放例句',
      icon: Icons.format_quote,
      playerMode: ListeningMode.wordExample,
    ),
    ListenMode(
      name: '释义+单词',
      description: '先播放中文释义再播放单词',
      icon: Icons.swap_horiz,
      playerMode: ListeningMode.meaningWord,
    ),
  ];

  int _selectedIndex = 0;
  bool _loading = false;

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
            // 底部确认按钮
            _buildConfirmButton(skin),
          ],
        ),
      ),
    );
  }

  Widget _buildConfirmButton(SkinSystem skin) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: skin.colors.pageBg,
        border: Border(top: BorderSide(color: skin.colors.divider)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: _loading ? null : _onConfirm,
            style: ElevatedButton.styleFrom(
              backgroundColor: MistralColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              elevation: 0,
            ),
            child: _loading
                ? const SizedBox(
                    width: 22, height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('开始播放', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ),
      ),
    );
  }

  Future<void> _onConfirm() async {
    setState(() => _loading = true);
    try {
      final learningState = context.read<LearningState>();
      final words = await learningState.getWordsByBook(widget.bookId);
      if (!mounted) return;
      if (words.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('该词书暂无单词')),
        );
        return;
      }
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ListeningPlayerPage(
            words: words,
            mode: _modes[_selectedIndex].playerMode,
            bookName: widget.bookName,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('加载单词失败: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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
