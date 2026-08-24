// 由 Claude 团队生成 | Monster Word App

// 移植自 v3.2 HelpActivity
// 帮助页：WebView 加载帮助文档
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../theme/skin_system.dart';
import '../tokens/design_tokens.dart';

class HelpPage extends StatefulWidget {
  final String? url;
  final int type; // 0=默认, 1=查看逻辑复习, 2=免费获取酷币

  const HelpPage({super.key, this.url, this.type = 0});

  static const routeName = '/help';

  @override
  State<HelpPage> createState() => _HelpPageState();
}

class _HelpPageState extends State<HelpPage> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.disabled) // 安全加固：禁用 JS（帮助页无需执行脚本）
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) => setState(() {
          _isLoading = true;
          _hasError = false;
        }),
        onPageFinished: (_) => setState(() => _isLoading = false),
        onWebResourceError: (_) => setState(() {
          _hasError = true;
          _isLoading = false;
        }),
        // 安全加固：仅允许 beingfine.cn 域名导航，阻止跳转到外部恶意站点
        navigationRequest: (request) {
          final uri = Uri.tryParse(request.url);
          if (uri != null && uri.host.endsWith('beingfine.cn')) {
            return NavigationDecision.navigate;
          }
          return NavigationDecision.prevent;
        },
      ));

    final url = widget.url ?? 'https://www.beingfine.cn/help';
    _controller.loadRequest(Uri.parse(url));
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;

    return Scaffold(
      backgroundColor: skin.colors.pageBg,
      body: SafeArea(
        child: Column(
          children: [
            _buildNavBar(skin),
            Container(height: 1, color: skin.colors.divider),
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
                          Text('加载失败，请检查网络', style: MistralTypography.body.copyWith(color: skin.colors.text3)),
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
          Text('帮助', style: MistralTypography.heading5.copyWith(color: skin.colors.text1)),
          const Spacer(),
          IconButton(
            icon: Icon(Icons.refresh, color: skin.colors.text1, size: 22),
            onPressed: () => _controller.reload(),
          ),
        ],
      ),
    );
  }
}
