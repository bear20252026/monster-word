// 由 Claude 团队生成 | Monster Word App

// 拼写/听写/快速拼写三页共享的测验流程：判分状态机 + 页面脚手架。
// 消除三页各自维护的 ~250 行重复逻辑（判分/推进/空态/结果弹窗），
// 反馈改为图标 + 文案（wasCorrect 布尔驱动），不再用 ✓/✗ 字符串前缀判色。
import 'package:flutter/material.dart';

import 'package:word_app/app/router/nav_utils.dart';
import 'package:word_app/core/presentation/responsive.dart';
import 'package:word_app/models/word.dart';
import 'package:word_app/theme/skin_system.dart';
import 'package:word_app/tokens/design_tokens.dart';
import 'package:word_app/tokens/motion_tokens.dart';
import 'package:word_app/widgets/monster_icon.dart';
import 'package:word_app/widgets/mw_button.dart';

/// 拼写测验状态机：词表装载、判分、推进、重开。
///
/// 页面持有并 dispose 本控制器；[SpellingQuizScaffold] 通过
/// ListenableBuilder 订阅渲染。[onStarted] 在词表就绪时触发
/// （快速拼写用来启动计时器），[onFinished] 在会话走完时触发
/// （快速拼写用来取消计时器）。
class SpellingQuizController extends ChangeNotifier {
  SpellingQuizController({this.limit, this.onStarted, this.onFinished});

  /// 单次会话最多练习的词数（快速拼写 20，其余不限）。
  final int? limit;

  /// 词表就绪回调。
  final VoidCallback? onStarted;

  /// 会话结束回调。
  final VoidCallback? onFinished;

  Future<List<Word>> Function()? _loader;
  List<Word> _source = [];
  List<Word> _words = [];
  int _index = 0;
  int _correct = 0;
  int _wrong = 0;
  bool _loading = true;
  bool _showAnswer = false;
  bool _wasCorrect = false;
  bool _finished = false;

  bool get isLoading => _loading;
  bool get isEmpty => !_loading && _words.isEmpty;
  bool get showAnswer => _showAnswer;
  bool get wasCorrect => _wasCorrect;
  bool get finished => _finished;
  int get index => _index;
  int get correctCount => _correct;
  int get wrongCount => _wrong;
  int get total => _words.length;
  String get answer => _words.isEmpty ? '' : _words[_index].word;

  Word get currentWord => _words.isNotEmpty
      ? _words[_index]
      : Word(
          id: 0,
          word: '',
          mainWord: '',
          interpret: '',
          ukPron: '',
          usPron: '',
          phrase: '',
          example: '',
          confuse: '',
        );

  /// 异步装载词表（失败按空表降级），完成后触发 [onStarted]。
  Future<void> load(Future<List<Word>> Function() loader) async {
    _loader = loader;
    _loading = true;
    notifyListeners();
    List<Word> words;
    try {
      words = await loader();
    } catch (_) {
      words = const [];
    }
    _seed(words);
  }

  /// 同步注入词表（测试与已持词表的调用方）。
  void seed(List<Word> words) => _seed(words);

  void _seed(List<Word> words) {
    _source = words;
    _words = limit == null ? words : words.take(limit!).toList();
    _index = 0;
    _correct = 0;
    _wrong = 0;
    _showAnswer = false;
    _finished = false;
    _loading = false;
    notifyListeners();
    if (_words.isNotEmpty) onStarted?.call();
  }

  /// 判分（忽略大小写与首尾空白），返回是否正确。
  bool checkAnswer(String input) {
    if (_showAnswer || _finished || _words.isEmpty) return false;
    _wasCorrect = input.trim().toLowerCase() == answer.toLowerCase();
    _showAnswer = true;
    _wasCorrect ? _correct++ : _wrong++;
    notifyListeners();
    return _wasCorrect;
  }

  /// 推进到下一词；走完则结束会话并触发 [onFinished]。
  void nextWord() {
    if (_finished || _words.isEmpty) return;
    if (_index >= _words.length - 1) {
      _finished = true;
      notifyListeners();
      onFinished?.call();
      return;
    }
    _index++;
    _showAnswer = false;
    notifyListeners();
  }

  /// 外部结束会话（快速拼写的「时间到」）。
  void finishByTime() {
    if (_finished) return;
    _finished = true;
    notifyListeners();
    onFinished?.call();
  }

  /// 重开会话：重跑上次 loader（或复用上次注入的词表）并复位计数。
  void restart() {
    final loader = _loader;
    if (loader != null) {
      load(loader);
    } else {
      _seed(_source);
    }
  }
}

/// 拼写测验页面脚手架：导航条/发丝线/输入框/反馈/CTA/结果页全托管，
/// 页面只提供标题、提示区（[promptBuilder]）与可选的导航尾部件。
class SpellingQuizScaffold extends StatefulWidget {
  const SpellingQuizScaffold({
    super.key,
    required this.controller,
    required this.title,
    required this.inputHint,
    required this.promptBuilder,
    this.finishTitle = '练习完成',
    this.navTrailing,
    this.inputStyle,
    this.onExit,
  });

  final SpellingQuizController controller;
  final String title;
  final String inputHint;
  final Widget Function(BuildContext context, Word word) promptBuilder;
  final String finishTitle;

  /// 导航条尾部（快速拼写的计时胶囊）；缺省显示「当前/总数」进度胶囊。
  final Widget? navTrailing;

  /// 输入文字样式（听写用 heading3，其余默认 heroWord）。
  final TextStyle? inputStyle;

  /// 退出前清理钩子（快速拼写用来取消计时器）；退出本身统一走 safePop。
  final VoidCallback? onExit;

  @override
  State<SpellingQuizScaffold> createState() => _SpellingQuizScaffoldState();
}

class _SpellingQuizScaffoldState extends State<SpellingQuizScaffold> {
  final _inputController = TextEditingController();
  final _focusNode = FocusNode();
  bool _wasLoading = true;
  bool _wasShowAnswer = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleControllerChange);
    _wasLoading = widget.controller.isLoading;
    _wasShowAnswer = widget.controller.showAnswer;
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerChange);
    _inputController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleControllerChange() {
    final controller = widget.controller;
    // 装载完成且有词 → 聚焦输入框。
    if (_wasLoading && !controller.isLoading && !controller.isEmpty && !controller.finished) {
      _requestFocus();
    }
    // 判分后收起键盘，让反馈与答案完整可见。
    if (!_wasShowAnswer && controller.showAnswer) {
      _focusNode.unfocus();
    }
    // 进入下一词 → 重新聚焦。
    if (_wasShowAnswer && !controller.showAnswer) {
      _requestFocus();
    }
    _wasLoading = controller.isLoading;
    _wasShowAnswer = controller.showAnswer;
  }

  void _requestFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  void _exit() {
    widget.onExit?.call();
    NavUtils.safePop(context);
  }

  void _primaryAction() {
    final controller = widget.controller;
    if (controller.showAnswer) {
      _inputController.clear();
      controller.nextWord();
    } else {
      controller.checkAnswer(_inputController.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final resp = context.responsive;

    return Scaffold(
      backgroundColor: skin.colors.pageBg,
      body: SafeArea(
        child: ListenableBuilder(
          listenable: widget.controller,
          builder: (context, _) => Column(
            children: [
              _buildNavBar(skin),
              Container(height: 1, color: skin.colors.divider),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: resp.contentMaxWidth),
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: resp.horizontalPadding),
                      child: _buildBody(skin),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(SkinSystem skin) {
    final controller = widget.controller;
    if (controller.isLoading) return const Center(child: CircularProgressIndicator());
    if (controller.isEmpty) return _buildEmpty(skin);
    if (controller.finished) return _buildFinish(skin);
    return _buildPlay(skin);
  }

  Widget _buildNavBar(SkinSystem skin) {
    final controller = widget.controller;
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          IconButton(icon: const Icon(Icons.arrow_back_ios_new, size: 20), color: skin.colors.text1, onPressed: _exit),
          const SizedBox(width: 4),
          Text(widget.title, style: MwTypography.heading5.copyWith(color: skin.colors.text1)),
          const Spacer(),
          widget.navTrailing ?? _buildProgressPill(skin, controller),
          const SizedBox(width: 12),
        ],
      ),
    );
  }

  Widget _buildProgressPill(SkinSystem skin, SpellingQuizController controller) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: MwColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(context.design.radius.pill),
      ),
      child: Text(
        '${controller.index + 1} / ${controller.total}',
        style: MwTypography.bodyBold.copyWith(color: MwColors.primary),
      ),
    );
  }

  Widget _buildPlay(SkinSystem skin) {
    final controller = widget.controller;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        widget.promptBuilder(context, controller.currentWord),
        const SizedBox(height: 32),
        _buildInput(skin),
        const SizedBox(height: 16),
        _buildFeedback(skin),
        const Spacer(),
        SizedBox(
          width: double.infinity,
          child: MwButton(
            label: controller.showAnswer ? '下一个' : '确认',
            onTap: _primaryAction,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildInput(SkinSystem skin) {
    return TextField(
      controller: _inputController,
      focusNode: _focusNode,
      enabled: !widget.controller.showAnswer,
      textAlign: TextAlign.center,
      style: (widget.inputStyle ?? AppTypography.heroWord).copyWith(color: skin.colors.text1),
      decoration: InputDecoration(
        hintText: widget.inputHint,
        hintStyle: MwTypography.body.copyWith(color: skin.colors.text3),
        filled: true,
        fillColor: skin.colors.cardBg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(context.design.radius.lg),
          borderSide: BorderSide(color: skin.colors.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(context.design.radius.lg),
          borderSide: BorderSide(color: MwColors.primary, width: 2),
        ),
      ),
      onSubmitted: (_) => _primaryAction(),
    );
  }

  Widget _buildFeedback(SkinSystem skin) {
    final controller = widget.controller;
    if (!controller.showAnswer) return const SizedBox(height: 40);
    final color = controller.wasCorrect ? MwColors.success : MwColors.danger;
    return AnimatedSwitcher(
      duration: MotionDurations.base,
      child: Row(
        key: ValueKey(controller.index),
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(controller.wasCorrect ? Icons.check_circle_rounded : Icons.cancel_rounded, color: color, size: 24),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              controller.wasCorrect ? '回答正确' : '正确答案：${controller.answer}',
              style: MwTypography.heading5.copyWith(color: color),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(SkinSystem skin) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const MonsterIcon(size: 72, showCircle: true),
        const SizedBox(height: 16),
        Text('暂无待学习单词', style: MwTypography.body.copyWith(color: skin.colors.text3)),
        const SizedBox(height: 24),
        MwButton.outlined(label: '返回首页', onTap: () => NavUtils.goHome(context)),
      ],
    );
  }

  Widget _buildFinish(SkinSystem skin) {
    final controller = widget.controller;
    final attempted = controller.correctCount + controller.wrongCount;
    final accuracy = (attempted > 0 ? controller.correctCount / attempted * 100 : 0).toStringAsFixed(1);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const MonsterIcon(size: 64, showCircle: true),
        const SizedBox(height: 16),
        Text(widget.finishTitle, style: MwTypography.heading3.copyWith(color: skin.colors.text1)),
        const SizedBox(height: 24),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: skin.colors.cardBg,
            borderRadius: BorderRadius.circular(context.design.radius.lg),
            border: Border.all(color: skin.colors.divider),
          ),
          child: Column(
            children: [
              Text('正确率 $accuracy%', style: MwTypography.heading4.copyWith(color: MwColors.primary)),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _finishStat(skin, '${controller.correctCount}', '正确', MwColors.success),
                  _finishStat(skin, '${controller.wrongCount}', '错误', MwColors.danger),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        Row(
          children: [
            Expanded(
              child: MwButton.outlined(label: '返回', onTap: _exit, padding: const EdgeInsets.symmetric(vertical: 12)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: MwButton(
                label: '再来一次',
                onTap: () {
                  _inputController.clear();
                  widget.controller.restart();
                },
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _finishStat(SkinSystem skin, String value, String label, Color color) {
    return Column(
      children: [
        Text(value, style: MwTypography.heading3.copyWith(color: color)),
        Text(label, style: MwTypography.bodySm.copyWith(color: skin.colors.text3)),
      ],
    );
  }
}

/// 释义提示卡：词义居中 + 可选「听发音」胶囊；[header] 用于附加进度等信息。
class QuizPromptCard extends StatelessWidget {
  const QuizPromptCard({super.key, required this.word, this.onListen, this.header});

  final Word word;
  final VoidCallback? onListen;
  final Widget? header;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: skin.colors.cardBgAlt,
        borderRadius: BorderRadius.circular(context.design.radius.lg),
      ),
      child: Column(
        children: [
          if (header != null) ...[header!, const SizedBox(height: 8)],
          Text(
            word.cleanInterpret,
            style: MwTypography.heading4.copyWith(color: skin.colors.text1),
            textAlign: TextAlign.center,
          ),
          if (onListen != null) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: onListen,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: MwColors.cream,
                  borderRadius: BorderRadius.circular(context.design.radius.pill),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.volume_up_outlined, size: 18, color: MwColors.primary),
                    const SizedBox(width: 6),
                    Text('听发音', style: MwTypography.bodySm.copyWith(color: MwColors.primary)),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
