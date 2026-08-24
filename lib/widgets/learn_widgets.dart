// 由 Claude 团队生成 | Monster Word App

// 由账号4生成
// 学习相关控件：翻译自 widget/ 中的学习类
// 文件：LearnView, LearnReviewHelper, LoadInfoHelper

import 'package:flutter/material.dart';
import 'animations.dart';

/// 学习视图状态
enum LearnPanelState { expanded, collapsed, dragging }

/// 学习主视图（翻译自 LearnView.dart）
/// 包含卡片区域、底部操作栏、左右滑动面板
class LearnMainView extends StatefulWidget {
  final Widget topInfoView;
  final Widget cardView;
  final Widget bottomPanel;
  final Widget? leftPanel;
  final Widget? rightPanel;
  final bool leftPanelEnabled;
  final ValueChanged<bool>? onRightPanelChanged;
  final ValueChanged<bool>? onLeftPanelChanged;
  final Widget? guideView;

  const LearnMainView({
    super.key,
    required this.topInfoView,
    required this.cardView,
    required this.bottomPanel,
    this.leftPanel,
    this.rightPanel,
    this.leftPanelEnabled = false,
    this.onRightPanelChanged,
    this.onLeftPanelChanged,
    this.guideView,
  });

  @override
  State<LearnMainView> createState() => _LearnMainViewState();
}

class _LearnMainViewState extends State<LearnMainView>
    with TickerProviderStateMixin {
  late AnimationController _rightPanelController;
  late AnimationController _leftPanelController;
  LearnPanelState _rightPanelState = LearnPanelState.collapsed;
  LearnPanelState _leftPanelState = LearnPanelState.collapsed;
  double _rightSlideOffset = 0;
  double _leftSlideOffset = 0;
  double _bottomPanelTranslation = 0;

  @override
  void initState() {
    super.initState();
    _rightPanelController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _leftPanelController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _rightPanelController.dispose();
    _leftPanelController.dispose();
    super.dispose();
  }

  void _showRightPanel(bool show) {
    setState(() {
      _rightPanelState =
          show ? LearnPanelState.expanded : LearnPanelState.collapsed;
      _rightSlideOffset = show ? 1.0 : 0.0;
      _updateBottomPanel();
    });
    widget.onRightPanelChanged?.call(show);
  }

  void _showLeftPanel(bool show) {
    if (!widget.leftPanelEnabled && show) return;
    setState(() {
      _leftPanelState =
          show ? LearnPanelState.expanded : LearnPanelState.collapsed;
      _leftSlideOffset = show ? 1.0 : 0.0;
      _updateBottomPanel();
    });
    widget.onLeftPanelChanged?.call(show);
  }

  void _updateBottomPanel() {
    _bottomPanelTranslation =
        _rightSlideOffset > _leftSlideOffset ? _rightSlideOffset : _leftSlideOffset;
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final statusBarHeight = MediaQuery.of(context).padding.top;

    return Stack(
      children: [
        // 主内容区域
        Column(
          children: [
            // 顶部信息栏
            widget.topInfoView,
            // 卡片区域
            Expanded(
              child: widget.cardView,
            ),
            // 底部操作栏
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              transform: Matrix4.translationValues(0, _bottomPanelTranslation * 48, 0),
              child: widget.bottomPanel,
            ),
          ],
        ),
        // 右侧面板（例句卡片等）
        if (widget.rightPanel != null)
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: fataleCurve,
            left: _rightPanelState == LearnPanelState.expanded
                ? 0
                : MediaQuery.of(context).size.width,
            top: statusBarHeight + 16,
            bottom: 0,
            width: MediaQuery.of(context).size.width,
            child: widget.rightPanel!,
          ),
        // 左侧面板（词根词缀等）
        if (widget.leftPanel != null)
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: fataleCurve,
            right: _leftPanelState == LearnPanelState.expanded
                ? 0
                : MediaQuery.of(context).size.width,
            top: statusBarHeight + 16,
            bottom: 0,
            width: MediaQuery.of(context).size.width,
            child: widget.leftPanel!,
          ),
        // 引导视图
        if (widget.guideView != null) widget.guideView!,
      ],
    );
  }
}

/// 加载信息辅助（翻译自 LoadInfoHelper.dart）
/// 显示加载状态、错误信息、重试按钮
class LoadInfoWidget extends StatelessWidget {
  final IconData? emoji;
  final String message;
  final String? actionText;
  final VoidCallback? onAction;
  final bool visible;

  const LoadInfoWidget({
    super.key,
    this.emoji,
    required this.message,
    this.actionText,
    this.onAction,
    this.visible = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (emoji != null) ...[
            Icon(emoji, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
          ],
          Text(
            message,
            style: const TextStyle(fontSize: 14, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          if (actionText != null) ...[
            const SizedBox(height: 12),
            TextButton(
              onPressed: onAction,
              child: Text(actionText!),
            ),
          ],
        ],
      ),
    );
  }
}

/// 学习数据辅助（翻译自 LearnReviewHelper.dart）
/// WebView 池管理 — Flutter 中使用 WebView widget 直接管理
class WebViewPool {
  static const int _maxPoolSize = 3;

  /// 获取 WebView 实例（Flutter 中直接创建 widget 即可）
  static Widget getWebView({
    required String url,
    ValueChanged<String>? onPageFinished,
    bool enableJavaScript = true,
  }) {
    // 实际使用时引入 webview_flutter
    return Container(
      color: Colors.transparent,
      child: const Center(child: Text('WebView placeholder')),
    );
  }
}

/// 示例点击监听器接口（翻译自 LearnReviewHelper.ExampleClickListener.dart）
abstract class ExampleClickListener {
  void clickHeader(String sentId);
  void clickSent(String audio);
  void selectedWord(String word, String? spanId, String? courseId);
  void touchOnWord(String word);
  void clickRootSuffixHeader();
  void takeEffect4LongPress(bool active);
}
