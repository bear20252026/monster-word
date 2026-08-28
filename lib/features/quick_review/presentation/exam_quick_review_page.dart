// 由 Claude 团队生成 | Monster Word App
//
// 考试速刷（Quick Review）页面 — 功能域内聚实现
//
// 本页面完整包含考试速刷的 UI 与交互逻辑，遵循 R1-R6 分层：
// - 读：通过 QuickReviewWordReader 端口（application 层）
// - 领域：ExamType / QuickReviewStats（domain 层）
// - 不直接接触 WordRepository 或任何基础设施

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/word.dart';
import '../../../theme/skin_system.dart';
import '../../../tokens/design_tokens.dart';
import '../../../tokens/func_colors.dart';
import '../../../widgets/monster_icon.dart';
import '../application/quick_review_word_reader.dart';
import '../domain/exam_type.dart';
import '../domain/quick_review_stats.dart';

class ExamQuickReviewPage extends StatefulWidget {
  const ExamQuickReviewPage({super.key});

  static const routeName = '/exam_quick_review';

  @override
  State<ExamQuickReviewPage> createState() => _ExamQuickReviewPageState();
}

class _ExamQuickReviewPageState extends State<ExamQuickReviewPage> {
  bool _isLoading = true;
  List<Word> _words = [];
  int _currentIndex = 0;
  bool _showAnswer = false;
  ExamType _examType = ExamType.cet4;
  Timer? _timer;
  QuickReviewStats stats = QuickReviewStats();
  int _tick = 0;

  @override
  void initState() {
    super.initState();
    context.read<QuickReviewWordReader>().loadWords().then((words) {
      if (!mounted) return;
      setState(() {
        _words = words;
        _isLoading = false;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _tick = _tick + 1);
      if (_tick >= _examType.timeLimit) {
        _onSkip();
      }
    });
  }

  void _onKnow() {
    setState(() {
      stats.total += 1;
      stats.correct += 1;
      stats.totalTime += _tick;
      _nextWord();
    });
  }

  void _onUnknown() {
    setState(() {
      stats.total += 1;
      stats.wrong += 1;
      stats.totalTime += _tick;
      _nextWord();
    });
  }

  void _onSkip() {
    setState(() {
      stats.skipped += 1;
      stats.totalTime += _tick;
      _nextWord();
    });
  }

  void _nextWord() {
    _timer?.cancel();
    setState(() {
      _currentIndex += 1;
      _showAnswer = false;
      _tick = 0;
      if (_currentIndex >= _words.length) {
        _finish();
        return;
      }
      _startTimer();
    });
  }

  void _finish() {
    _timer?.cancel();
    setState(() {
      _currentIndex = _words.length;
    });
  }

  void _restart() {
    setState(() {
      stats = QuickReviewStats();
      _currentIndex = 0;
      _showAnswer = false;
      _tick = 0;
      _startTimer();
    });
  }

  void _toggleExamType(ExamType type) {
    setState(() {
      _examType = type;
      _currentIndex = 0;
      _showAnswer = false;
      _tick = 0;
      stats = QuickReviewStats();
      _isLoading = true;
    });
    context.read<QuickReviewWordReader>().loadWords(limit: type.timeLimit).then((words) {
      if (!mounted) return;
      setState(() {
        _words = words;
        _isLoading = false;
        _startTimer();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin.colors;
    return Scaffold(
      backgroundColor: skin.pageBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, size: 24),
          color: skin.text1,
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '快速刷题',
          style: MistralTypography.heading3.copyWith(color: skin.text1),
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _currentIndex >= _words.length
                ? _buildResultPage(skin)
                : _buildReviewPage(skin),
      ),
    );
  }

  Widget _buildReviewPage(dynamic skin) {
    final word = _words[_currentIndex];
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              _StatBadge(label: '已答', value: '${stats.total}', color: skin.text1),
              const SizedBox(width: 8),
              _StatBadge(label: '正确', value: '${stats.correct}', color: FuncColors.success),
              const SizedBox(width: 8),
              _StatBadge(label: '正确率', value: stats.accuracyPercent, color: skin.accent),
              const SizedBox(width: 8),
              _StatBadge(label: '用时', value: stats.timeFormatted, color: skin.text3),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: ExamType.values.map((t) {
              final selected = t == _examType;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(t.label, style: const TextStyle(fontSize: 12)),
                  selected: selected,
                  selectedColor: skin.accent,
                  labelStyle: TextStyle(color: selected ? AppColors.white100 : skin.text1),
                  onSelected: (_) => _toggleExamType(t),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 24),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: _SimpleWordCard(
              word: word,
              showPhonetic: _showAnswer,
              showMeaning: _showAnswer,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              Text(
                '${_currentIndex + 1} / ${_words.length}',
                style: MistralTypography.caption.copyWith(color: skin.text3),
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (_currentIndex + 1) / _words.length,
                  backgroundColor: skin.divider,
                  valueColor: AlwaysStoppedAnimation<Color>(skin.accent),
                  minHeight: 6,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (!_showAnswer)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: skin.accent),
                onPressed: () => setState(() => _showAnswer = true),
                child: const Text('查看答案', style: TextStyle(fontSize: 16)),
              ),
            ),
          ),
        if (_showAnswer)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: MistralColors.danger),
                      ),
                      onPressed: _onUnknown,
                      icon: const Icon(Icons.close, color: MistralColors.danger),
                      label: const Text('不认识', style: TextStyle(color: MistralColors.danger)),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: FuncColors.success),
                      onPressed: _onKnow,
                      icon: const Icon(Icons.check, color: AppColors.white100),
                      label: const Text('认识', style: TextStyle(color: AppColors.white100)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildResultPage(dynamic skin) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const MonsterAvatar(size: 80),
            const SizedBox(height: 24),
            Text(
              '本轮完成！',
              style: MistralTypography.heading2.copyWith(color: skin.text1),
            ),
            const SizedBox(height: 16),
            _ResultRow(label: '答题总数', value: '${stats.total}', skin: skin),
            _ResultRow(label: '答对', value: '${stats.correct}', skin: skin),
            _ResultRow(label: '答错', value: '${stats.wrong}', skin: skin),
            _ResultRow(label: '跳过', value: '${stats.skipped}', skin: skin),
            _ResultRow(label: '正确率', value: stats.accuracyPercent, skin: skin),
            _ResultRow(label: '用时', value: stats.timeFormatted, skin: skin),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: skin.accent),
                onPressed: _restart,
                child: const Text('再来一轮', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatBadge extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatBadge({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final skin = context.skin.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: skin.cardBg,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: skin.divider),
      ),
      child: Column(
        children: [
          Text(label, style: MistralTypography.caption.copyWith(color: skin.text3)),
          Text(value, style: MistralTypography.bodySm.copyWith(color: color)),
        ],
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  final String label;
  final String value;
  final dynamic skin;
  const _ResultRow({required this.label, required this.value, required this.skin});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: MistralTypography.bodyMd.copyWith(color: skin.text3)),
          Text(value, style: MistralTypography.body.copyWith(color: skin.text1, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

/// 简易单词卡片：显示单词 + 音标 + 释义（受控显示）。
class _SimpleWordCard extends StatelessWidget {
  final Word word;
  final bool showPhonetic;
  final bool showMeaning;
  const _SimpleWordCard({required this.word, required this.showPhonetic, required this.showMeaning});

  @override
  Widget build(BuildContext context) {
    final skin = context.skin.colors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: skin.cardBg,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: skin.divider),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            word.word,
            style: MistralTypography.heading1.copyWith(color: skin.text1),
          ),
          if (showPhonetic) ...[
            const SizedBox(height: 12),
            Text(
              '${word.ukPron}  ${word.usPron}',
              style: MistralTypography.bodyMd.copyWith(color: skin.text3),
            ),
          ],
          if (showMeaning) ...[
            const SizedBox(height: 16),
            Text(
              word.firstInterpretLine,
              style: MistralTypography.body.copyWith(color: skin.text1, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}
