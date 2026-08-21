// 由账号4生成
// L3 学习页：壁纸沉浸 + HeroWord + 音标 + 释义 + 例句 + 派生词 + SegmentTabs + 底部双按钮
// 翻译自 Figma 03a-screens-learning.json learn_session
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/example_parser.dart';
import '../engine/srs_engine.dart';
import '../hooks/responsive.dart';
import '../state/learning_state.dart';
import '../theme/skin_system.dart';
import '../tokens/design_tokens.dart';
import '../widgets/glass_widgets.dart';

class LearnSession extends StatefulWidget {
  const LearnSession({super.key});
  static const routeName = '/learn_session';

  @override
  State<LearnSession> createState() => _LearnSessionState();
}

class _LearnSessionState extends State<LearnSession> {
  int _selectedTab = 0;

  static const _tabs = ['释义', '派生', '词组搭配', '词根', '近义'];

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final resp = context.responsive;
    final state = context.watch<LearningState>();
    final word = state.currentWord;

    if (word == null) {
      return const Scaffold(body: Center(child: Text('暂无单词')));
    }

    final examples = ExampleParser.parse(word.example);

    return Scaffold(
      body: WallpaperBg(
        child: SafeArea(
          child: Column(
            children: [
              // 透明导航栏（原版 nav：返回 + 进度 + 操作）
              _buildNav(skin, state),
              // 内容区
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(horizontal: resp.pageMargin),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 24),
                      // HeroWord（原版 40dp 粗体 + 音节圆点）
                      Text(
                        word.word,
                        style: AppTypography.heroWord.copyWith(
                          fontSize: resp.heroFontSize,
                          color: skin.colors.onGlassText1,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // 音标（原版 phonetics Pill + caption）
                      if (word.usPron.isNotEmpty || word.ukPron.isNotEmpty)
                        Row(
                          children: [
                            if (word.usPron.isNotEmpty) ...[
                              _PhoneticPill(label: '美', skin: skin),
                              const SizedBox(width: 4),
                              Text(
                                '/${word.usPron}/',
                                style: AppTypography.caption.copyWith(
                                  color: skin.colors.onGlassText2,
                                ),
                              ),
                            ],
                            if (word.ukPron.isNotEmpty) ...[
                              const SizedBox(width: 12),
                              _PhoneticPill(label: '英', skin: skin),
                              const SizedBox(width: 4),
                              Text(
                                '/${word.ukPron}/',
                                style: AppTypography.caption.copyWith(
                                  color: skin.colors.onGlassText2,
                                ),
                              ),
                            ],
                          ],
                        ),
                      const SizedBox(height: 20),
                      // 释义（原版 defs TextBlock，核心义项带下划线）
                      ...word.interpretLines.map(
                        (line) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            line,
                            style: AppTypography.body.copyWith(
                              color: skin.colors.onGlassText1,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // 例句卡（原版 ExampleCard，奶油半透明底）
                      if (examples.isNotEmpty)
                        ...examples.take(2).map(
                          (ex) => _ExampleCard(example: ex, skin: skin),
                        ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
              // SegmentTabs（原版 派生/词组搭配/词根/近义）
              _buildSegmentTabs(skin),
              // 底部双按钮（原版 下一词 + 记错了）
              _buildBottomActions(skin, state),
            ],
          ),
        ),
      ),
    );
  }

  /// 透明导航栏（原版 nav_transparent）
  Widget _buildNav(SkinSystem skin, LearningState state) {
    return Container(
      height: AppSpacing.navH,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          Text(
            '${state.currentIndex + 1}/${state.total}',
            style: AppTypography.caption.copyWith(color: skin.colors.onGlassText1),
          ),
          const Spacer(),
          IconButton(
            icon: Icon(Icons.undo, color: skin.colors.onGlassText2, size: 20),
            onPressed: () {},
          ),
          IconButton(
            icon: Icon(Icons.star_border, color: skin.colors.onGlassText2, size: 20),
            onPressed: () {},
          ),
          IconButton(
            icon: Icon(Icons.more_horiz, color: skin.colors.onGlassText2, size: 20),
            onPressed: () {},
          ),
        ],
      ),
    );
  }

  /// SegmentTabs（原版 word_tabs：派生/词组搭配/词根/近义）
  Widget _buildSegmentTabs(SkinSystem skin) {
    return Container(
      height: 36,
      margin: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: List.generate(_tabs.length, (i) {
          final on = i == _selectedTab;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTab = i),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _tabs[i],
                    style: AppTypography.caption.copyWith(
                      color: on ? skin.colors.onGlassAccent : skin.colors.onGlassText2,
                      fontWeight: on ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    height: 2,
                    color: on ? skin.colors.onGlassAccent : Colors.transparent,
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  /// 底部双按钮（原版 actions：下一词 + 记错了）
  Widget _buildBottomActions(SkinSystem skin, LearningState state) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                state.rate(RecallRating.good);
                setState(() {});
              },
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: skin.colors.success,
                      width: AppUnderline.thickness,
                    ),
                  ),
                ),
                child: Center(
                  child: Text(
                    '下一词',
                    style: AppTypography.body.copyWith(
                      color: skin.colors.onGlassText1,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: GestureDetector(
              onTap: () {
                state.rate(RecallRating.again);
                setState(() {});
              },
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: skin.colors.danger,
                      width: AppUnderline.thickness,
                    ),
                  ),
                ),
                child: Center(
                  child: Text(
                    '记错了',
                    style: AppTypography.body.copyWith(
                      color: skin.colors.onGlassText1,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 音标 Pill（原版美/英标签）
class _PhoneticPill extends StatelessWidget {
  final String label;
  final SkinSystem skin;
  const _PhoneticPill({required this.label, required this.skin});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppRadius.control),
      ),
      child: Text(
        label,
        style: AppTypography.footnote.copyWith(color: skin.colors.onGlassText2),
      ),
    );
  }
}

/// 例句卡（原版 ExampleCard，奶油半透明底）
class _ExampleCard extends StatelessWidget {
  final ExampleSentence example;
  final SkinSystem skin;
  const _ExampleCard({required this.example, required this.skin});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        // 奶油半透明底（原版 rgba(255,251,240,0.92)）
        color: const Color(0xEBFFFBF0),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              style: AppTypography.body.copyWith(
                color: skin.colors.text1,
                height: 1.5,
              ),
              children: example.highlightedParts
                  .map(
                    (p) => TextSpan(
                      text: p.text,
                      style: p.highlight
                          ? const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2FA89F))
                          : null,
                    ),
                  )
                  .toList(),
            ),
          ),
          if (example.cn.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              example.cn,
              style: AppTypography.caption.copyWith(color: skin.colors.text2),
            ),
          ],
          if (example.source.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                example.source,
                style: AppTypography.footnote.copyWith(color: skin.colors.text3),
              ),
            ),
        ],
      ),
    );
  }
}
