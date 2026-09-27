// 由 Claude 团队生成 | Monster Word App

// 通用 WebView 页面：加载指定 URL（仅白名单内域名可打开）
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'package:word_app/theme/skin_system.dart';
import 'package:word_app/tokens/design_tokens.dart';

class BaseWebPage extends StatefulWidget {
  final String url;
  final String? title;
  final bool showAppBar;

  const BaseWebPage({super.key, required this.url, this.title, this.showAppBar = true});

  @override
  State<BaseWebPage> createState() => _BaseWebPageState();
}

class _BaseWebPageState extends State<BaseWebPage> {
  WebViewController? _controller;
  bool _isLoading = true;
  bool _hasError = false;
  String _pageTitle = '';

  /// 允许的域名白名单（当前为空：应用暂无自有 Web 内容域名，
  /// 任何 URL 都不会放行；新增自有内容站点时在此登记）
  static const _allowedDomains = <String>[];

  /// 检查 URL 是否在白名单内
  bool _isUrlAllowed(String url) {
    try {
      final uri = Uri.parse(url);

      // 拒绝危险协议
      if (uri.scheme == 'javascript' || uri.scheme == 'data') {
        return false;
      }

      // 只允许 https（安全审计 P3-5：白名单逻辑不应接受明文 http）
      if (uri.scheme != 'https') {
        return false;
      }

      // 检查域名白名单
      return _allowedDomains.any((domain) => uri.host == domain || uri.host.endsWith('.$domain'));
    } catch (e) {
      return false;
    }
  }

  @override
  void initState() {
    super.initState();
    _pageTitle = widget.title ?? '';

    // 检查初始 URL 是否在白名单
    if (!_isUrlAllowed(widget.url)) {
      _hasError = true;
      return;
    }

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.disabled)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            if (!_isUrlAllowed(request.url)) {
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
          onPageStarted: (_) {
            if (!mounted) return;
            setState(() {
              _isLoading = true;
              _hasError = false;
            });
          },
          onPageFinished: (url) async {
            final title = await _controller?.getTitle();
            if (mounted) {
              setState(() {
                _isLoading = false;
                if (title != null && title.isNotEmpty) _pageTitle = title;
              });
            }
          },
          onWebResourceError: (_) {
            if (!mounted) return;
            setState(() {
              _hasError = true;
              _isLoading = false;
            });
          },
        ),
      );
    _controller!.loadRequest(Uri.parse(widget.url)).catchError((Object e) {
      // 平台通道加载失败：置错误态而不是让异常逃逸到 zone
      if (mounted) {
        setState(() => _hasError = true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;

    return Scaffold(
      backgroundColor: skin.colors.pageBg,
      body: SafeArea(
        child: Column(
          children: [
            if (widget.showAppBar) ...[_buildNavBar(skin), Container(height: 1, color: skin.colors.divider)],
            Expanded(
              child: Stack(
                children: [
                  if (_hasError || _controller == null)
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.wifi_off, size: 64, color: skin.colors.text3),
                          const SizedBox(height: 16),
                          Text('页面加载失败', style: MwTypography.body.copyWith(color: skin.colors.text3)),
                          const SizedBox(height: 16),
                          // 控制器未初始化（白名单未放行）时没有可重载的页面，
                          // 此前直接调 _controller.reload() 会抛 LateInitializationError
                          if (_controller != null)
                            ElevatedButton(
                              onPressed: () => _controller?.reload(),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: MwColors.primary,
                                foregroundColor: AppColors.white100,
                              ),
                              child: const Text('重试'),
                            ),
                        ],
                      ),
                    )
                  else
                    WebViewWidget(controller: _controller!),
                  if (_isLoading) Center(child: CircularProgressIndicator(color: MwColors.primary)),
                ],
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
          Expanded(
            child: Text(
              _pageTitle,
              style: MwTypography.heading5.copyWith(color: skin.colors.text1),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: Icon(Icons.refresh, color: skin.colors.text1, size: 22),
            onPressed: _controller == null ? null : () => _controller?.reload(),
          ),
        ],
      ),
    );
  }
}
