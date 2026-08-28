// 例句测验页：显示英文例句 + 填空选择 + 答案解析
// 从例句中提取关键词，生成4选1测验
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/router/nav_utils.dart';
import '../data/example_parser.dart';
import '../hooks/responsive.dart';
import '../features/learning/presentation/learning_session_state.dart';
import '../theme/skin_system.dart';
import '../tokens/design_tokens.dart';

class SentenceQuizPage extends StatefulWidget {
  const SentenceQuizPage({super.key});
  static const routeName = '/sentence_quiz';

  @override
  State<SentenceQuizPage> createState() => _SentenceQuizPageState();
}

class _SentenceQuizPageState extends State<SentenceQuizPage> {
  int _currentIdx = 0;
  int? _selectedIdx;
  bool _showAnswer = false;
  late List<_QuizItem> _quizItems;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _buildQuizItems();
  }

  void _buildQuizItems() {
    final state = context.read<LearningSessionState>();
    final word = state.currentWord;
    if (word == null) {
      _quizItems = [];
      return;
    }

    final examples = ExampleParser.parse(word.example);
    _quizItems = examples
        .map((ex) {
          return _QuizItem.fromExample(ex, word.word, state.queue);
        })
        .where((q) => q != null)
        .cast<_QuizItem>()
        .toList();

    // 如果没有足够例句，用单词释义生成备选
    if (_quizItems.isEmpty) {
      _quizItems = [_QuizItem.fallback(word.word, word.interpret, state.queue)];
    }
  }

  void _onSelect(int idx) {
    if (_showAnswer) return;
    setState(() {
      _selectedIdx = idx;
    });
  }

  void _confirmAnswer() {
    if (_selectedIdx == null) return;
    setState(() {
      _showAnswer = true;
    });
  }

  void _next() {
    if (_currentIdx < _quizItems.length - 1) {
      setState(() {
        _currentIdx++;
        _selectedIdx = null;
        _showAnswer = false;
      });
    } else {
      // 测验完成，返回
      if (!mounted) return;
      NavUtils.goHome(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final resp = context.responsive;
    context.watch<LearningSessionState>();

    if (_quizItems.isEmpty) {
      return Scaffold(
        backgroundColor: skin.colors.pageBg,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.format_quote, size: 64, color: skin.colors.text3),
              const SizedBox(height: 16),
              Text('暂无可用例句', style: MistralTypography.heading5.copyWith(color: skin.colors.text1)),
              const SizedBox(height: 8),
              Text('当前单词暂无例句可用于测验', style: MistralTypography.bodySm.copyWith(color: skin.colors.text3)),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => NavUtils.goHome(context),
                icon: const Icon(Icons.home, size: 20),
                label: const Text('返回首页'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: skin.colors.accent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final quiz = _quizItems[_currentIdx];
    final isCorrect = _selectedIdx == quiz.correctIdx;

    return Scaffold(
      backgroundColor: skin.colors.pageBg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: resp.contentWidth),
            child: Column(
              children: [
                _buildTopBar(skin),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(horizontal: resp.pageMargin),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 24),
                        _buildSentenceCard(quiz, skin),
                        const SizedBox(height: 24),
                        _buildOptions(quiz, skin),
                        if (_showAnswer) ...[const SizedBox(height: 20), _buildAnswerCard(quiz, isCorrect, skin)],
                      ],
                    ),
                  ),
                ),
                _buildBottomBar(skin),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(SkinSystem skin) {
    return Container(
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
            onPressed: () => NavUtils.safePop(context),
          ),
          const SizedBox(width: 4),
          Text('例句测验', style: MistralTypography.captionBold.copyWith(color: skin.colors.text1)),
          const Spacer(),
          Text(
            '${_currentIdx + 1}/${_quizItems.length}',
            style: MistralTypography.captionBold.copyWith(color: skin.colors.accent),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 80,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: (_currentIdx + 1) / _quizItems.length,
                minHeight: 3,
                backgroundColor: skin.colors.divider,
                valueColor: AlwaysStoppedAnimation(skin.colors.accent),
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildSentenceCard(_QuizItem quiz, SkinSystem skin) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: skin.colors.cardBg,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: skin.colors.divider, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.format_quote, color: skin.colors.accent, size: 20),
              const SizedBox(width: 6),
              Text('请选出填入空白处的单词', style: MistralTypography.captionBold.copyWith(color: skin.colors.text3)),
            ],
          ),
          const SizedBox(height: 16),
          // 例句文本，空白处用下划线标记
          RichText(
            text: TextSpan(
              style: MistralTypography.bodyMd.copyWith(color: skin.colors.text1, height: 1.6, fontSize: 17),
              children: _buildSentenceSpans(quiz, skin),
            ),
          ),
          if (quiz.source.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(quiz.source, style: AppTypography.footnote.copyWith(color: skin.colors.text3)),
          ],
        ],
      ),
    );
  }

  List<TextSpan> _buildSentenceSpans(_QuizItem quiz, SkinSystem skin) {
    final spans = <TextSpan>[];
    // 在句子中找到关键词位置，替换为空白
    final sentence = quiz.sentenceWithBlank;
    final parts = sentence.split('___');

    for (var i = 0; i < parts.length; i++) {
      if (parts[i].isNotEmpty) {
        spans.add(TextSpan(text: parts[i]));
      }
      if (i < parts.length - 1) {
        spans.add(
          TextSpan(
            text: '______',
            style: TextStyle(
              color: _showAnswer
                  ? (_selectedIdx == quiz.correctIdx ? skin.colors.success : skin.colors.danger)
                  : skin.colors.accent,
              fontWeight: FontWeight.bold,
              decoration: TextDecoration.underline,
              decorationColor: _showAnswer
                  ? (_selectedIdx == quiz.correctIdx ? skin.colors.success : skin.colors.danger)
                  : skin.colors.accent,
            ),
          ),
        );
      }
    }
    return spans;
  }

  Widget _buildOptions(_QuizItem quiz, SkinSystem skin) {
    return Column(
      children: List.generate(quiz.options.length, (i) {
        final isSelected = _selectedIdx == i;
        final isCorrectOption = i == quiz.correctIdx;
        final showResult = _showAnswer;

        Color bgColor;
        Color borderColor;
        Color textColor;

        if (showResult && isCorrectOption) {
          bgColor = skin.colors.success.withValues(alpha: 0.1);
          borderColor = skin.colors.success;
          textColor = skin.colors.success;
        } else if (showResult && isSelected && !isCorrectOption) {
          bgColor = skin.colors.danger.withValues(alpha: 0.1);
          borderColor = skin.colors.danger;
          textColor = skin.colors.danger;
        } else {
          bgColor = skin.colors.cardBg;
          borderColor = skin.colors.divider;
          textColor = skin.colors.text1;
        }

        return GestureDetector(
          onTap: () => _onSelect(i),
          child: Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(
                color: borderColor,
                width: (showResult && (isCorrectOption || isSelected)) ? 1.5 : 0.5,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: showResult && isCorrectOption
                        ? skin.colors.success
                        : showResult && isSelected
                        ? skin.colors.danger
                        : skin.colors.accent,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      String.fromCharCode(65 + i),
                      style: const TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(quiz.options[i], style: MistralTypography.bodyMd.copyWith(color: textColor)),
                ),
                if (showResult && isCorrectOption) Icon(Icons.check_circle, color: skin.colors.success, size: 20),
                if (showResult && isSelected && !isCorrectOption)
                  Icon(Icons.cancel, color: skin.colors.danger, size: 20),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildAnswerCard(_QuizItem quiz, bool isCorrect, SkinSystem skin) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: (isCorrect ? skin.colors.success : skin.colors.danger).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: (isCorrect ? skin.colors.success : skin.colors.danger).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isCorrect ? Icons.check_circle : Icons.info_outline,
                color: isCorrect ? skin.colors.success : skin.colors.danger,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                isCorrect ? '回答正确！' : '回答错误',
                style: MistralTypography.captionBold.copyWith(
                  color: isCorrect ? skin.colors.success : skin.colors.danger,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // 完整句子
          Text('完整句子：', style: MistralTypography.captionBold.copyWith(color: skin.colors.text3)),
          const SizedBox(height: 4),
          Text(quiz.fullSentence, style: MistralTypography.body.copyWith(color: skin.colors.text1, height: 1.5)),
          // 中文翻译
          if (quiz.translation.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('中文释义：', style: MistralTypography.captionBold.copyWith(color: skin.colors.text3)),
            const SizedBox(height: 4),
            Text(quiz.translation, style: MistralTypography.body.copyWith(color: skin.colors.text2)),
          ],
          // 正确答案
          const SizedBox(height: 8),
          Text(
            '正确答案：${quiz.options[quiz.correctIdx]}',
            style: MistralTypography.body.copyWith(color: skin.colors.accent, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(SkinSystem skin) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton(
          onPressed: _showAnswer ? _next : (_selectedIdx != null ? _confirmAnswer : null),
          style: ElevatedButton.styleFrom(
            backgroundColor: skin.colors.accent,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
            elevation: 0,
          ),
          child: Text(
            _showAnswer ? (_currentIdx < _quizItems.length - 1 ? '下一题' : '完成测验') : '确认选择',
            style: MistralTypography.body.copyWith(color: Colors.white),
          ),
        ),
      ),
    );
  }
}

/// 测验题目数据
class _QuizItem {
  final String fullSentence; // 完整句子（含关键词）
  final String sentenceWithBlank; // 句子（关键词替换为 ___）
  final String translation; // 中文翻译
  final String source; // 来源
  final List<String> options; // 4个选项
  final int correctIdx; // 正确答案索引

  _QuizItem({
    required this.fullSentence,
    required this.sentenceWithBlank,
    required this.translation,
    required this.source,
    required this.options,
    required this.correctIdx,
  });

  /// 从例句生成测验题
  static _QuizItem? fromExample(ExampleSentence example, String targetWord, List<dynamic> allWords) {
    final cleanEn = example.cleanEn;
    if (cleanEn.isEmpty) return null;

    // 找到句子中的目标单词（不区分大小写）
    final lowerSentence = cleanEn.toLowerCase();
    final lowerWord = targetWord.toLowerCase();
    final wordIdx = lowerSentence.indexOf(lowerWord);

    String sentenceWithBlank;
    if (wordIdx >= 0) {
      // 精确匹配到目标词
      sentenceWithBlank = '${cleanEn.substring(0, wordIdx)}___${cleanEn.substring(wordIdx + targetWord.length)}';
    } else {
      // 找不到目标词，尝试找 <b> 标记的词
      final bMatch = RegExp(r'<b>(.*?)</b>').firstMatch(example.en);
      if (bMatch != null) {
        final keyword = bMatch.group(1)!;
        final kwIdx = cleanEn.indexOf(keyword);
        if (kwIdx >= 0) {
          sentenceWithBlank = '${cleanEn.substring(0, kwIdx)}___${cleanEn.substring(kwIdx + keyword.length)}';
        } else {
          return null;
        }
      } else {
        return null;
      }
    }

    // 生成干扰选项
    final correctWord = wordIdx >= 0
        ? targetWord
        : RegExp(r'<b>(.*?)</b>').firstMatch(example.en)?.group(1) ?? targetWord;
    final options = _generateOptions(correctWord, allWords);

    return _QuizItem(
      fullSentence: cleanEn,
      sentenceWithBlank: sentenceWithBlank,
      translation: example.cn,
      source: example.source,
      options: options,
      correctIdx: options.indexOf(correctWord),
    );
  }

  /// 备用题目（当没有例句时）
  static _QuizItem fallback(String word, String interpret, List<dynamic> allWords) {
    return _QuizItem(
      fullSentence: word,
      sentenceWithBlank: '___',
      translation: interpret,
      source: '',
      options: _generateOptions(word, allWords),
      correctIdx: 0,
    );
  }

  /// 生成4个选项（1正确 + 3干扰）
  static List<String> _generateOptions(String correct, List<dynamic> allWords) {
    final options = <String>[correct];
    final seen = {correct.toLowerCase()};

    // 从词书中取干扰词
    for (final w in allWords) {
      if (options.length >= 4) break;
      final wordStr = w.word ?? w.toString();
      if (!seen.contains(wordStr.toLowerCase()) && wordStr.isNotEmpty) {
        options.add(wordStr);
        seen.add(wordStr.toLowerCase());
      }
    }

    // 不够则补占位
    final fallbacks = ['apple', 'happy', 'green', 'blue', 'quick', 'brave'];
    for (final fb in fallbacks) {
      if (options.length >= 4) break;
      if (!seen.contains(fb)) {
        options.add(fb);
        seen.add(fb);
      }
    }

    options.shuffle();
    return options;
  }
}
