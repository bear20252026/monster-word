// 由 Claude 团队生成 | 移植自 v3.2 lock/LockWebViewCache.java
// 锁屏 WebView 缓存管理

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// WebView 缓存池，用于锁屏例句显示
/// 复用 WebView 实例以提高性能
class LockWebViewCache {
  static final List<WebViewController> _cache = [];
  static const int _maxCacheSize = 3;

  /// 获取一个可用的 WebViewController
  static WebViewController getController() {
    if (_cache.isNotEmpty) {
      return _cache.removeLast();
    }
    return _createController();
  }

  /// 归还 WebViewController 到缓存池
  static void release(WebViewController controller) {
    if (_cache.length < _maxCacheSize) {
      controller.loadHtmlString('');
      _cache.add(controller);
    }
  }

  /// 清空缓存
  static void clearCache() {
    _cache.clear();
  }

  static WebViewController _createController() {
    return WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent);
  }
}

/// 锁屏例句 WebView 组件
class LockExampleWebView extends StatefulWidget {
  final String htmlContent;
  final VoidCallback? onTap;

  const LockExampleWebView({
    super.key,
    required this.htmlContent,
    this.onTap,
  });

  @override
  State<LockExampleWebView> createState() => _LockExampleWebViewState();
}

class _LockExampleWebViewState extends State<LockExampleWebView> {
  late WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = LockWebViewCache.getController();
    _loadContent();
  }

  @override
  void didUpdateWidget(LockExampleWebView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.htmlContent != widget.htmlContent) {
      _loadContent();
    }
  }

  @override
  void dispose() {
    LockWebViewCache.release(_controller);
    super.dispose();
  }

  void _loadContent() {
    _controller.loadHtmlString('''
      <!DOCTYPE html>
      <html>
      <head>
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <style>
          body {
            margin: 0;
            padding: 16px;
            background: transparent;
            color: white;
            font-size: 16px;
            line-height: 1.6;
            font-family: -apple-system, BlinkMacSystemFont, sans-serif;
          }
          .en { color: white; font-size: 16px; }
          .cn { color: rgba(255,255,255,0.6); font-size: 14px; margin-top: 8px; }
          .highlight { color: #64b5f6; font-weight: bold; }
        </style>
      </head>
      <body>
        ${widget.htmlContent}
      </body>
      </html>
    ''');
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: WebViewWidget(controller: _controller),
    );
  }
}
