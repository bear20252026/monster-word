// 由 Claude 团队生成 | 移植自 v3.2 lock/LockViewProcessorImp.java
// 锁屏学习主界面 - Flutter 实现

import 'dart:async';
import 'package:flutter/material.dart';

import '../widgets/animations.dart';

import 'lock_presenter.dart';
import 'lock_presenter_imp.dart';
import 'lock_view.dart';
import 'my_element_animator.dart';
import 'view/line_indicator.dart';

/// 锁屏专用颜色常量（刻意独立于 app 主题，始终深色）
/// 锁屏是系统级全屏覆盖，无论 app 当前皮肤如何都应保持深色背景 + 白色文字。
class LockScreenColors {
  LockScreenColors._();
  static const Color background = Colors.black;
  static const Color gradientTop = Color(0xFF1a1a2e);
  static const Color gradientMid = Color(0xFF16213e);
  static const Color gradientBottom = Color(0xFF0f3460);
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Colors.white70;
  static const Color textTertiary = Colors.white60;
  static const Color textMuted = Colors.white54;
  static const Color iconDim = Colors.white38;
  static const Color borderLight = Colors.white30;
  static const Color chargingIcon = Colors.greenAccent;
  static const Color overlayScrim = Colors.black87;
  static const Color pillBg = Color(0x26FFFFFF); // white 15%
}

/// 锁屏学习主页面
/// 完整还原 v3.2 LockViewProcessorImp 的功能：
/// - 锁屏界面显示单词、音标、释义
/// - 下拉显示例句（ViewPager）
/// - 左滑解锁进入学习
/// - 长按播放发音
/// - 电量/时间显示
/// - 上下滑动切换音标类型
class LockScreenPage extends StatefulWidget {
  /// 是否作为独立锁屏使用（true）或嵌入页面使用（false）
  final bool isStandalone;

  const LockScreenPage({super.key, this.isStandalone = true});

  @override
  State<LockScreenPage> createState() => _LockScreenPageState();
}

class _LockScreenPageState extends State<LockScreenPage>
    with TickerProviderStateMixin
    implements LockView {
  // === Presenter ===
  late LockPresenter _presenter;

  // === UI 状态 ===
  String _time = '';
  String _dateEn = '';
  String _word = '';
  String _phonetic = '';
  String _phoneticType = 'US';
  List<Map<String, String>> _interpretations = [];
  bool _isProcessingExample = false;
  bool _isCharging = false;
  int _powerPercent = 0;
  bool _showExplanation = false; // 是否显示释义（下拉时）

  // === 例句 ===
  List<Map<String, dynamic>> _sentences = [];
  List<String> _examples = [];
  List<String> _mp3Paths = [];
  int _currentExampleIndex = 0;
  final PageController _examplePageController = PageController();

  // === 动画 ===
  late AnimationController _slideUpController;
  late AnimationController _slideDownController;
  late AnimationController _chargingController;
  late Animation<double> _slideUpAnimation;
  late Animation<double> _slideDownAnimation;

  // === 元素动画器（锁屏解锁/回弹） ===
  MyElementAnimator? _elementAnimator;
  late ElementDirection _timeDirection;
  late ElementDirection _wordDirection;
  late ElementDirection _bottomDirection;

  // === 手势状态 ===
  final bool _cancelAnimation = false;
  Timer? _longPressTimer;
  double _dragStartY = 0;
  bool _isDragging = false;

  // === 引导状态 ===
  final bool _shouldShowExampleGuide = true;

  // === 导航页面 ===
  final PageController _navPageController = PageController();

  @override
  void initState() {
    super.initState();
    _presenter = LockPresenterImp(context, this);
    _initAnimations();
    _presenter.init();
    _presenter.nextWord();
  }

  void _initAnimations() {
    _slideUpController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _slideDownController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _chargingController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    );

    _slideUpAnimation = Tween<double>(begin: 0.0, end: -50.0).animate(
      CurvedAnimation(parent: _slideUpController, curve: Curves.linear),
    );
    _slideDownAnimation = Tween<double>(begin: -50.0, end: 0.0).animate(
      CurvedAnimation(parent: _slideDownController, curve: Curves.linear),
    );

    _slideUpController.addStatusListener((status) {
      if (status == AnimationStatus.completed && !_cancelAnimation) {
        _slideUpController.reset();
        _slideUpController.forward();
      }
    });
    _slideDownController.addStatusListener((status) {
      if (status == AnimationStatus.completed && !_cancelAnimation) {
        _slideDownController.reset();
        _slideDownController.forward();
      }
    });

    // 充电动画
    _chargingController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _presenter.destroy();
    _slideUpController.dispose();
    _slideDownController.dispose();
    _chargingController.dispose();
    _examplePageController.dispose();
    _navPageController.dispose();
    _longPressTimer?.cancel();
    _elementAnimator?.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final size = MediaQuery.of(context).size;
    _initElementAnimator(size.height);
  }

  /// 初始化元素动画器
  void _initElementAnimator(double screenHeight) {
    // 如果已存在且屏幕高度没变，跳过
    if (_elementAnimator != null) return;

    // 元素方向配置：speedFactor 控制视差速度
    // 时间区域滑动最快，单词区域次之，底部区域最慢
    _timeDirection = ElementDirection(speedFactor: 1.5);
    _wordDirection = ElementDirection(speedFactor: 1.0);
    _bottomDirection = ElementDirection(speedFactor: 0.6);

    // 设置更新回调：当动画器更新值时触发 UI 重建
    void refresh() {
      if (mounted) setState(() {});
    }
    _timeDirection.onUpdate = refresh;
    _wordDirection.onUpdate = refresh;
    _bottomDirection.onUpdate = refresh;

    _elementAnimator = MyElementAnimator(
      screenHeight: screenHeight,
      directions: [_timeDirection, _wordDirection, _bottomDirection],
      vsync: this,
    );
    _elementAnimator!.setMinDistance(
      (screenHeight * 0.3).toInt(), // 上滑 30% 触发解锁
    );
  }

  // ==================== LockView 接口实现 ====================

  @override
  void initWord(Map<String, dynamic> wordProcess) {
    if (!mounted) return;
    setState(() {
      _word = wordProcess['word'] ?? '';

      // 解析音标
      final isUK = wordProcess['pronounceType'] == 'UK';
      _phoneticType = isUK ? 'UK' : 'US';
      final pron = isUK
          ? (wordProcess['uk_pron'] ?? '')
          : (wordProcess['us_pron'] ?? '');
      _phonetic = pron.isNotEmpty
          ? (isUK ? '[ $pron ]' : '/ $pron /')
          : '';

      // 解析释义
      final interpret = wordProcess['interpret'] ?? '';
      _interpretations = _parseInterpretations(interpret);
    });
  }

  @override
  void loadExampleData(
    List<Map<String, dynamic>> sentences,
    List<String> examples,
    List<String> mp3Paths,
    String word,
  ) {
    if (!mounted) return;
    setState(() {
      _sentences = sentences;
      _examples = examples;
      _mp3Paths = mp3Paths;
    });
  }

  @override
  void loadExampleFinish(Map<String, dynamic> wordProcess) {
    // 例句加载完成后，如果正在显示例句区域，自动播放
  }

  @override
  void setProcessingExample(bool processing) {
    if (!mounted) return;
    setState(() {
      _isProcessingExample = processing;
    });
  }

  @override
  void showExampleItemAt(int index) {
    if (_examples.isEmpty) return;
    final targetIndex = (_examples.length * 10) + index;
    _examplePageController.jumpToPage(targetIndex);
    setState(() {
      _currentExampleIndex = index;
    });
  }

  @override
  void updateDateTime(String time, String dateCn, String dateEn) {
    if (!mounted) return;
    setState(() {
      _time = time;
      _dateEn = dateEn;
    });
  }

  @override
  void updatePower(bool isCharging, int percent) {
    if (!mounted) return;
    setState(() {
      _isCharging = isCharging;
      _powerPercent = percent;
    });
    if (isCharging) {
      _chargingController.repeat(reverse: true);
    } else {
      _chargingController.stop();
    }
  }

  // ==================== 业务逻辑 ====================

  /// 解析释义文本
  List<Map<String, String>> _parseInterpretations(String interpret) {
    final result = <Map<String, String>>[];
    final lines = interpret.split('\n');
    for (final line in lines) {
      final dotIndex = line.indexOf('.');
      if (dotIndex >= 0) {
        result.add({
          'type': line.substring(0, dotIndex + 1),
          'meaning': line.substring(dotIndex + 1),
        });
      } else {
        result.add({'type': '', 'meaning': line});
      }
    }
    return result;
  }

  /// 切换音标类型
  void _togglePhoneticType() {
    _presenter.changePhoneticType();
  }

  /// 播放单词发音
  void _playWordAudio() {
    _presenter.autoPlayWordAudio(true, 0);
  }

  /// 播放例句
  void _playExampleAudio(int index) {
    if (index < _mp3Paths.length) {
      _presenter.togglePlayExample(index, true, _mp3Paths[index]);
    }
  }

  /// 解锁进入学习
  void _unlockToLearn() {
    _presenter.unlockToLearn();
  }

  /// 下滑隐藏例句区域
  void _onSlideDownToHideExamples() {
    _presenter.setCanPlayExample(false);
    _presenter.pauseAudio();
  }

  // ==================== UI 构建 ====================

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    // 锁屏覆层：颜色刻意独立于 app 主题（始终深色），不走 ThemeVars。
    // 锁屏是系统级全屏覆盖，无论 app 当前皮肤如何都应保持深色背景 + 白色文字。
    return Scaffold(
      backgroundColor: LockScreenColors.background,
      body: GestureDetector(
        onLongPressStart: (_) => _onLongPressStart(),
        onLongPressEnd: (_) => _onLongPressEnd(),
        onVerticalDragStart: _onVerticalDragStart,
        onVerticalDragUpdate: _onVerticalDragUpdate,
        onVerticalDragEnd: _onVerticalDragEnd,
        child: Stack(
          children: [
            // 背景图
            _buildBackground(screenSize),
            // 主内容
            SafeArea(
              child: Column(
                children: [
                  // 顶部区域：时间 + 电量
                  _buildTopBar(),
                  // 中间区域：单词 + 音标 + 释义
                  Expanded(
                    child: _buildWordSection(),
                  ),
                  // 底部区域：例句指示器 + 滑动提示
                  _buildBottomBar(),
                ],
              ),
            ),
            // 例句区域（上滑后显示）
            _buildExampleSection(screenSize),
            // 上滑引导动画
            _buildSlideGuide(),
          ],
        ),
      ),
    );
  }

  Widget _buildBackground(Size screenSize) {
    return Positioned.fill(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              LockScreenColors.gradientTop,
              LockScreenColors.gradientMid,
              LockScreenColors.gradientBottom,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Transform.translate(
      offset: Offset(0, _timeDirection.translateY),
      child: Opacity(
        opacity: _timeDirection.alpha,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // 时间
              Text(
                _time,
                style: const TextStyle(
                  color: LockScreenColors.textPrimary,
                  fontSize: 48,
                  fontWeight: FontWeight.w200,
                ),
              ),
              // 电量
              _buildPowerIndicator(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPowerIndicator() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_isCharging)
          FadeTransition(
            opacity: _chargingController,
            child: const Icon(
              Icons.battery_charging_full,
              color: LockScreenColors.chargingIcon,
              size: 20,
            ),
          ),
        const SizedBox(width: 4),
        Text(
          '$_powerPercent%',
          style: const TextStyle(
            color: LockScreenColors.textSecondary,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildWordSection() {
    return Transform.translate(
      offset: Offset(0, _wordDirection.translateY),
      child: Opacity(
        opacity: _wordDirection.alpha,
        child: GestureDetector(
      onTap: _playWordAudio,
      onVerticalDragEnd: (details) {
        if (details.primaryVelocity != null && details.primaryVelocity! > 0) {
          _togglePhoneticType();
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 日期
            Text(
              _dateEn,
              style: const TextStyle(
                color: LockScreenColors.textMuted,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            // 单词
            Text(
              _word,
              style: const TextStyle(
                color: LockScreenColors.textPrimary,
                fontSize: 36,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            // 音标
            GestureDetector(
              onTap: _togglePhoneticType,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: LockScreenColors.borderLight),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _phoneticType,
                      style: const TextStyle(
                        color: LockScreenColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _phonetic,
                    style: const TextStyle(
                      color: LockScreenColors.textSecondary,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // 释义
            if (_showExplanation) _buildInterpretations(),
          ],
        ),
      ),
      ),
    ),
    );
  }

  Widget _buildInterpretations() {
    return AnimatedOpacity(
      opacity: _showExplanation ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 200),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _interpretations.map((interp) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (interp['type']!.isNotEmpty)
                  SizedBox(
                    width: 50,
                    child: Text(
                      interp['type']!,
                      style: const TextStyle(
                        color: LockScreenColors.textTertiary,
                        fontSize: 14,
                      ),
                    ),
                  ),
                Expanded(
                  child: Text(
                    interp['meaning'] ?? '',
                    style: const TextStyle(
                      color: LockScreenColors.textPrimary,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Transform.translate(
      offset: Offset(0, _bottomDirection.translateY),
      child: Opacity(
        opacity: _bottomDirection.alpha,
        child: Padding(
      padding: const EdgeInsets.only(bottom: 32),
      child: Column(
        children: [
          // 例句指示器
          if (_examples.isNotEmpty)
            LineIndicator(
              count: _examples.length,
              selectedIndex: _currentExampleIndex % _examples.length,
            ),
          const SizedBox(height: 16),
          // 滑动提示
          AnimatedBuilder(
            animation: _slideUpAnimation,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, _slideUpAnimation.value),
                child: Opacity(
                  opacity: (_slideUpAnimation.value.abs() / 50).clamp(0.0, 1.0),
                  child: const Icon(
                    Icons.keyboard_arrow_up,
                    color: LockScreenColors.iconDim,
                    size: 32,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          // "左滑学习"提示
          GestureDetector(
            onTap: _unlockToLearn,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: LockScreenColors.pillBg,
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '左滑进入学习',
                    style: TextStyle(
                      color: LockScreenColors.textPrimary,
                      fontSize: 14,
                    ),
                  ),
                  SizedBox(width: 8),
                  Icon(
                    Icons.arrow_forward_ios,
                    color: LockScreenColors.textPrimary,
                    size: 14,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      ),
    ),
    );
  }

  Widget _buildExampleSection(Size screenSize) {
    final topHeight = screenSize.height * 0.39;

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 300),
      curve: ReverseSpringCurve(),
      top: _showExplanation ? 0 : screenSize.height,
      left: 0,
      right: 0,
      height: screenSize.height,
      child: GestureDetector(
        onVerticalDragEnd: (details) {
          if (details.primaryVelocity != null &&
              details.primaryVelocity! > 300) {
            setState(() => _showExplanation = false);
            _onSlideDownToHideExamples();
          }
        },
        child: Container(
          color: LockScreenColors.overlayScrim,
          child: Column(
            children: [
              // 顶部区域：单词 + 释义
              SizedBox(
                height: topHeight,
                child: _buildWordSection(),
              ),
              // 例句区域
              Expanded(
                child: _buildExamplePager(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExamplePager() {
    if (_isProcessingExample) {
      return const Center(
        child: CircularProgressIndicator(color: LockScreenColors.textMuted),
      );
    }

    if (_examples.isEmpty) {
      return const Center(
        child: Text(
          '暂无例句',
          style: TextStyle(color: LockScreenColors.textMuted),
        ),
      );
    }

    return GestureDetector(
      onTap: () => _playExampleAudio(_currentExampleIndex),
      child: PageView.builder(
        controller: _examplePageController,
        onPageChanged: (index) {
          final realIndex = index % _examples.length;
          setState(() => _currentExampleIndex = realIndex);
          _presenter.autoPlayExample(
            realIndex,
            false,
            _mp3Paths[realIndex],
          );
        },
        itemBuilder: (context, index) {
          final realIndex = index % _examples.length;
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 英文例句
                Text(
                  _examples[realIndex],
                  style: const TextStyle(
                    color: LockScreenColors.textPrimary,
                    fontSize: 18,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 12),
                // 中文翻译
                if (realIndex < _sentences.length)
                  Text(
                    _sentences[realIndex]['cn'] ?? '',
                    style: const TextStyle(
                      color: LockScreenColors.textTertiary,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSlideGuide() {
    if (!_shouldShowExampleGuide) return const SizedBox.shrink();

    return Positioned(
      bottom: 100,
      left: 0,
      right: 0,
      child: AnimatedBuilder(
        animation: _slideDownAnimation,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, _slideDownAnimation.value),
            child: Opacity(
              opacity: (_slideDownAnimation.value.abs() / 50).clamp(0.0, 1.0),
              child: const Icon(
                Icons.keyboard_arrow_down,
                color: LockScreenColors.iconDim,
                size: 32,
              ),
            ),
          );
        },
      ),
    );
  }

  // ==================== 手势处理 ====================

  void _onLongPressStart() {
    _longPressTimer = Timer(const Duration(milliseconds: 500), () {
      _playWordAudio();
    });
  }

  void _onLongPressEnd() {
    _longPressTimer?.cancel();
  }

  /// 垂直拖拽开始
  void _onVerticalDragStart(DragStartDetails details) {
    _dragStartY = details.globalPosition.dy;
    _isDragging = true;
  }

  /// 垂直拖拽更新：驱动 onScroll 视差效果
  void _onVerticalDragUpdate(DragUpdateDetails details) {
    if (!_isDragging || _elementAnimator == null) return;
    final delta = (details.globalPosition.dy - _dragStartY).toInt();
    _elementAnimator!.onScroll(delta);
  }

  /// 垂直拖拽结束：判断是解锁还是回弹
  void _onVerticalDragEnd(DragEndDetails details) {
    if (!_isDragging || _elementAnimator == null) return;
    _isDragging = false;

    final velocity = details.primaryVelocity ?? 0;
    final scrollDelta = _elementAnimator!.scrollDelta;
    final screenHeight = MediaQuery.of(context).size.height;
    final threshold = screenHeight * 0.3; // 30% 屏幕高度

    // 条件：上滑超过 30% 或者上滑速度足够快
    if (-scrollDelta > threshold || velocity < -800) {
      // 解锁动画
      final speedY = (-velocity).toInt().abs().clamp(1, 5000);
      _elementAnimator!.finishAnimate(speedY, onUnlock: () {
        _unlockToLearn();
      });
    } else {
      // 回弹动画
      final speedY = velocity.toInt().abs().clamp(1, 5000);
      _elementAnimator!.rollbackAnimate(speedY);
    }
  }
}
