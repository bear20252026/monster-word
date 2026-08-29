// 由 Claude 团队生成 | Monster Word App

// 泛听模式选择页面：选择随身听播放模式（单词/释义+单词/单词+释义/单词+例句）
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/learning/listening_mode.dart';
import '../../../core/router/nav_utils.dart';
import '../../../core/router/route_names.dart';
import 'package:word_app/core/presentation/responsive.dart';
import '../../../models/word.dart';
import '../../../theme/skin_system.dart';
import '../../../tokens/design_tokens.dart';
import '../application/book_words_reader.dart';

class ExtensiveModelSelectPage extends StatefulWidget {
  final String bookId;
  final String bookName;

  const ExtensiveModelSelectPage({
    super.key,
    required this.bookId,
    required this.bookName,
  });

  static const routeName = '/extensive_model_select';

  @override
  State<ExtensiveModelSelectPage> createState() => _ExtensiveModelSelectPageState();
}

class _ExtensiveModelSelectPageState extends State<ExtensiveModelSelectPage> {
  bool _loading = true;
  List<Word> _words = [];

  @override
  void initState() {
    super.initState();
    _loadWords();
  }

  Future<void> _loadWords() async {
    try {
      final words = await context.read<BookWordsReader>().loadWords(int.parse(widget.bookId));
      if (!mounted) return;
      setState(() {
        _words = words;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _startListening(ListeningMode mode) {
    if (_words.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('暂无单词可播放')),
      );
      return;
    }
    Navigator.pushNamed(
      context,
      RouteNames.listeningPlayer,
      arguments: {
        'words': _words,
        'startIndex': 0,
        'mode': mode,
        'bookName': widget.bookName,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final resp = context.responsive;

    if (_loading) {
      return Scaffold(
        backgroundColor: skin.colors.pageBg,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: skin.colors.pageBg,
      body: SafeArea(
        child: Column(
          children: [
            _buildNavBar(skin),
            Container(height: 1, color: skin.colors.divider),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: resp.contentMaxWidth),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: resp.horizontalPadding),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '选择泛听模式',
                          style: MistralTypography.heading3.copyWith(color: skin.colors.text1),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.bookName,
                          style: MistralTypography.body.copyWith(color: skin.colors.text3),
                        ),
                        const SizedBox(height: 48),
                        _ModeCard(
                          icon: Icons.text_fields,
                          title: '仅单词',
                          subtitle: '只听单词发音',
                          onTap: () => _startListening(ListeningMode.wordOnly),
                          skin: skin,
                        ),
                        const SizedBox(height: 16),
                        _ModeCard(
                          icon: Icons.menu_book,
                          title: '单词+释义',
                          subtitle: '单词后跟中文释义',
                          onTap: () => _startListening(ListeningMode.wordMeaning),
                          skin: skin,
                        ),
                        const SizedBox(height: 16),
                        _ModeCard(
                          icon: Icons.record_voice_over,
                          title: '释义+单词',
                          subtitle: '先中文后英文',
                          onTap: () => _startListening(ListeningMode.meaningWord),
                          skin: skin,
                        ),
                        const SizedBox(height: 16),
                        _ModeCard(
                          icon: Icons.format_quote,
                          title: '单词+例句',
                          subtitle: '单词后跟英文例句',
                          onTap: () => _startListening(ListeningMode.wordExample),
                          skin: skin,
                        ),
                      ],
                    ),
                  ),
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
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
            color: skin.colors.text1,
            onPressed: () => NavUtils.safePop(context),
          ),
          const SizedBox(width: 4),
          Text('泛听模式', style: MistralTypography.heading5.copyWith(color: skin.colors.text1)),
        ],
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final SkinSystem skin;

  const _ModeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.skin,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: skin.colors.cardBg,
          borderRadius: BorderRadius.circular(context.design.radius.lg),
          border: Border.all(color: skin.colors.divider),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: MistralColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(context.design.radius.md),
              ),
              child: Icon(icon, color: MistralColors.primary, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: MistralTypography.heading5.copyWith(color: skin.colors.text1)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: MistralTypography.bodySm.copyWith(color: skin.colors.text3)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: skin.colors.text3),
          ],
        ),
      ),
    );
  }
}
