// 由 Claude 团队生成 | Monster Word App

// 移植自 v3.2 BaseWebActivity / AdWebActivity / HeadAdWebActivity
// 通用 WebView 页面：加载指定 URL
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../theme/skin_system.dart';
import '../tokens/design_tokens.dart';

class BaseWebPage extends StatefulWidget {
  final String url;
  final String? title;
  final bool showAppBar;

  const BaseWebPage({
    super.key,
    required this.url,
    this.title,
    this.showAppBar = true,
  });

  static const routeName = '/web';

  @override
  State<BaseWebPage> createState() => _BaseWebPageState();
}

class _BaseWebPageState extends State<BaseWebPage> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _hasError = false;
  String _pageTitle = '';

  @override
  void initState() {
    super.initState();
    _pageTitle = widget.title ?? '';
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) => setState(() {
          _isLoading = true;
          _hasError = false;
        }),
        onPageFinished: (url) async {
          final title = await _controller.getTitle();
          if (mounted) {
            setState(() {
              _isLoading = false;
              if (title != null && title.isNotEmpty) _pageTitle = title;
            });
          }
        },
        onWebResourceError: (_) => setState(() {
          _hasError = true;
          _isLoading = false;
        }),
      ));
    _controller.loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;

    return Scaffold(
      backgroundColor: skin.colors.pageBg,
      body: SafeArea(
        child: Column(
          children: [
            if (widget.showAppBar) ...[
              _buildNavBar(skin),
              Container(height: 1, color: skin.colors.divider),
            ],
            Expanded(
              child: Stack(
                children: [
                  if (_hasError)
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.wifi_off, size: 64, color: skin.colors.text3),
                          const SizedBox(height: 16),
                          Text('页面加载失败', style: MistralTypography.body.copyWith(color: skin.colors.text3)),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () => _controller.reload(),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: MistralColors.primary,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('重试'),
                          ),
                        ],
                      ),
                    )
                  else
                    WebViewWidget(controller: _controller),
                  if (_isLoading)
                    Center(child: CircularProgressIndicator(color: MistralColors.primary)),
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
              style: MistralTypography.heading5.copyWith(color: skin.colors.text1),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: Icon(Icons.refresh, color: skin.colors.text1, size: 22),
            onPressed: () => _controller.reload(),
          ),
        ],
      ),
    );
  }
}

/// 广告 WebView 页面（对应原版 AdWebActivity）
class AdWebPage extends StatelessWidget {
  final String url;
  const AdWebPage({super.key, required this.url});

  static const routeName = '/ad_web';

  @override
  Widget build(BuildContext context) {
    return BaseWebPage(url: url, showAppBar: true);
  }
}
