// 由 Claude 团队生成 | Monster Word App

// 帮助页：默认加载内置帮助内容，也可通过 url 参数加载外部页面
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'package:word_app/theme/skin_system.dart';
import 'package:word_app/tokens/design_tokens.dart';

class HelpPage extends StatefulWidget {
  final String? url;
  final int type; // 0=默认, 1=查看逻辑复习, 2=免费获取尖叫币

  const HelpPage({super.key, this.url, this.type = 0});

  static const routeName = '/help';

  @override
  State<HelpPage> createState() => _HelpPageState();
}

class _HelpPageState extends State<HelpPage> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _hasError = false;

  /// 外部传入的初始 URL（为空时加载内置帮助内容）
  String? _initialUrl;

  /// 内置帮助内容（本地 HTML，无外部依赖）
  static const String _builtinHelpHtml = '''
<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<style>
  body { font-family: sans-serif; padding: 24px; color: #333; line-height: 1.7; }
  h2 { font-size: 20px; margin-top: 0; }
  li { margin-bottom: 10px; }
</style>
</head>
<body>
<h2>🧸 Monster Word 帮助</h2>
<ul>
  <li><b>开始学习</b>：在首页选择词书，进入学习页即可开始背单词。</li>
  <li><b>复习安排</b>：App 会根据你的作答自动安排复习间隔，忘得越快复习越勤。</li>
  <li><b>生词本</b>：学习中点星标收藏生词，可在「我的」中随时回顾。</li>
  <li><b>更多问题</b>：请通过「更多设置 → 帮助与反馈」联系我们。</li>
</ul>
</body>
</html>
''';

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.disabled) // 安全加固：禁用 JS（帮助页无需执行脚本）
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => setState(() {
            _isLoading = true;
            _hasError = false;
          }),
          onPageFinished: (_) => setState(() => _isLoading = false),
          onWebResourceError: (_) => setState(() {
            _hasError = true;
            _isLoading = false;
          }),
          // 安全加固：仅允许加载初始内容，阻止跳转到外部站点
          onNavigationRequest: (request) {
            // 本地 HTML 初始加载不产生 http(s) 导航；任何远程导航一律阻止
            final uri = Uri.tryParse(request.url);
            if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https') && request.url == _initialUrl) {
              return NavigationDecision.navigate;
            }
            return NavigationDecision.prevent;
          },
        ),
      );

    if (widget.url != null) {
      final url = widget.url!;
      _initialUrl = url;
      _controller.loadRequest(Uri.parse(url));
    } else {
      _controller.loadHtmlString(_builtinHelpHtml);
    }
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
                          SizedBox(height: 16),
                          Text('加载失败，请检查网络', style: MwTypography.body.copyWith(color: skin.colors.text3)),
                          SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () => _controller.reload(),
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
                    WebViewWidget(controller: _controller),
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
      padding: EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
            color: skin.colors.text1,
            tooltip: '返回',
            onPressed: () => Navigator.pop(context),
          ),
          SizedBox(width: 4),
          Text('帮助', style: MwTypography.heading5.copyWith(color: skin.colors.text1)),
          const Spacer(),
          IconButton(
            icon: Icon(Icons.refresh, color: skin.colors.text1, size: 22),
            tooltip: '刷新',
            onPressed: () => _controller.reload(),
          ),
        ],
      ),
    );
  }
}
