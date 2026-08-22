// 由账号4生成
// 字典详情页：单词详解（释义+音标+例句+常见用法+词根+形近词）
// 从学习页答题后进入，看完后点击"下一词"返回学习
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/example_parser.dart';
import '../state/learning_state.dart';
import '../theme/skin_system.dart';
import '../tokens/design_tokens.dart';

class WordDetailPage extends StatelessWidget {
  const WordDetailPage({super.key});
  static const routeName = '/word_detail';

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final state = context.watch<LearningState>();
    final word = state.currentWord;

    if (word == null) return const Scaffold(body: Center(child: Text('暂无单词')));

    final examples = ExampleParser.parse(word.example);
    final lines = word.interpretLines;
    final confuseList = _parseConfuse(word.confuse);

    return Scaffold(
      backgroundColor: skin.colors.pageBg,
      body: SafeArea(
        child: Column(
          children: [
            // 顶部导航
            Container(
              height: AppSpacing.navH,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: skin.colors.cardBg,
                border: Border(bottom: BorderSide(color: skin.colors.divider, width: 0.5)),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                    color: skin.colors.text1,
                    onPressed: () => Navigator.pop(context),
                  ),
                  Text('单词详情',
                    style: MistralTypography.heading5.copyWith(color: skin.colors.text1)),
                ],
              ),
            ),
            // 内容
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 单词 + 音标 + 发音
                    _buildWordHeader(word, skin),
                    const SizedBox(height: 20),
                    // 释义
                    if (lines.isNotEmpty) ...[
                      Text('释义',
                        style: MistralTypography.heading5.copyWith(color: skin.colors.text2)),
                      const SizedBox(height: 8),
                      ...lines.map((line) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(line,
                          style: MistralTypography.bodyMd.copyWith(color: skin.colors.text1, height: 1.5)),
                      )),
                    ],
                    // 例句
                    if (examples.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      Text('例句',
                        style: MistralTypography.heading5.copyWith(color: skin.colors.text2)),
                      const SizedBox(height: 8),
                      ...examples.take(3).map((ex) => _ExampleTile(ex, skin)),
                    ],
                    // 形近词
                    if (confuseList.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      Text('形近词',
                        style: MistralTypography.heading5.copyWith(color: skin.colors.text2)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: confuseList.map((c) => Chip(
                          label: Text(c,
                            style: MistralTypography.bodySm.copyWith(color: skin.colors.text1)),
                          backgroundColor: MistralColors.cream,
                          side: BorderSide(color: MistralColors.beigeDeep),
                        )).toList(),
                      ),
                    ],
                    // 词根词缀（如果有的话）
                    const SizedBox(height: 20),
                    Text('常见用法',
                      style: MistralTypography.heading5.copyWith(color: skin.colors.text2)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: MistralColors.creamLight,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(color: MistralColors.beigeDeep),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${word.word} — 详细用法',
                            style: MistralTypography.bodyMd.copyWith(color: skin.colors.text1)),
                          const SizedBox(height: 4),
                          Text('释义: ${word.interpret}',
                            style: MistralTypography.bodySm.copyWith(color: skin.colors.text3)),
                          if (word.phrase.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text('词组: ${word.phrase}',
                              style: MistralTypography.bodySm.copyWith(color: skin.colors.text3)),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // 底部：下一词按钮
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: skin.colors.cardBg,
                border: Border(top: BorderSide(color: skin.colors.divider, width: 0.5)),
              ),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: () {
                    state.next();
                    Navigator.pop(context);
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: skin.colors.accent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md)),
                  ),
                  child: Text('下一词',
                    style: MistralTypography.buttonMd.copyWith(color: Colors.white)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWordHeader(dynamic word, SkinSystem skin) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [MistralColors.cream, MistralColors.creamLight]),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: MistralColors.beigeDeep),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(word.word,
                style: MistralTypography.heading1.copyWith(color: skin.colors.text1, fontSize: 40)),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () async {
                  try {
                    final player = AudioPlayer();
                    await player.play(UrlSource(
                      'http://dict.youdao.com/dictvoice?audio=${Uri.encodeComponent(word.word)}&type=2'));
                  } catch (_) {}
                },
                child: Icon(Icons.volume_up_outlined, color: skin.colors.accent, size: 28),
              ),
            ],
          ),
          if (word.usPron.isNotEmpty || word.ukPron.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (word.usPron.isNotEmpty)
                  Text('美 /${word.usPron}/  ',
                    style: MistralTypography.bodySm.copyWith(color: skin.colors.text3)),
                if (word.ukPron.isNotEmpty)
                  Text('英 /${word.ukPron}/',
                    style: MistralTypography.bodySm.copyWith(color: skin.colors.text3)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  List<String> _parseConfuse(String confuse) {
    final t = confuse.trim();
    if (t.isEmpty) return [];
    if (t.startsWith('[')) {
      return t.substring(1, t.length - 1)
          .split(',').map((e) => e.trim().replaceAll('"', ''))
          .where((e) => e.isNotEmpty).toList();
    }
    return [t];
  }
}

/// 例句条目
class _ExampleTile extends StatelessWidget {
  final ExampleSentence example;
  final SkinSystem skin;
  const _ExampleTile(this.example, this.skin);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: MistralColors.creamLight,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: MistralColors.beigeDeep),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              style: MistralTypography.bodySm.copyWith(color: skin.colors.text1, height: 1.4),
              children: example.highlightedParts.map((p) => TextSpan(
                text: p.text,
                style: p.highlight
                    ? TextStyle(fontWeight: FontWeight.bold, color: skin.colors.accent)
                    : null,
              )).toList(),
            ),
          ),
          if (example.cn.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(example.cn,
              style: MistralTypography.micro.copyWith(color: skin.colors.text3)),
          ],
          if (example.source.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(example.source,
                style: MistralTypography.micro.copyWith(color: skin.colors.text3)),
            ),
        ],
      ),
    );
  }
}
