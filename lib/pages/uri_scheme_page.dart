// 由 Claude 团队生成 | Monster Word App

// 移植自 v3.2 UriSchemeProcessActivity
// URI Scheme 处理：处理 deep link 跳转
import 'package:flutter/material.dart';

import '../core/router/nav_utils.dart';
import '../core/router/route_names.dart';
import '../theme/skin_system.dart';
import '../tokens/design_tokens.dart';
import 'base_web_page.dart';

class UriSchemePage extends StatelessWidget {
  final String uri;

  const UriSchemePage({super.key, required this.uri});

  static const routeName = '/uri_scheme';

  @override
  Widget build(BuildContext context) {
    // 解析 URI 并跳转到对应页面
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _processUri(context);
    });

    // A-6: 深链冷启动走品牌过渡（品牌色 + 品牌标识），而非生硬白屏+转圈。
    return Scaffold(
      backgroundColor: context.skin.colors.pageBg,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Monster Word',
              style: MistralTypography.heading4.copyWith(
                color: MistralColors.primary,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: MistralColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// A-6: 安全回首页 — 冷启动深链时 UriSchemePage 是根路由，
  /// NavUtils.goHome（popUntil isFirst）会无效导致卡死；此时用 pushReplacement 跳到首页。
  void _goHomeSafe(BuildContext context) {
    final nav = Navigator.of(context);
    if (nav.canPop()) {
      NavUtils.goHome(context);
    } else {
      nav.pushReplacementNamed('/');
    }
  }

  void _processUri(BuildContext context) {
    try {
      final uriObj = Uri.tryParse(uri);
      if (uriObj == null) {
        _goHomeSafe(context);
        return;
      }

      // 处理不同 scheme
      if (uriObj.scheme == 'http' || uriObj.scheme == 'https') {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => BaseWebPage(url: uri)));
      } else if (uriObj.scheme == 'monsterword') {
        // 自定义 scheme 处理
        final host = uriObj.host;
        switch (host) {
          case 'word':
            final word = uriObj.pathSegments.isNotEmpty ? uriObj.pathSegments[0] : '';
            Navigator.pushReplacementNamed(context, RouteNames.wordDetail, arguments: word);
            break;
          case 'learn':
            Navigator.pushReplacementNamed(context, RouteNames.learn);
            break;
          case 'review':
            Navigator.pushReplacementNamed(context, RouteNames.review);
            break;
          default:
            _goHomeSafe(context);
        }
      } else {
        _goHomeSafe(context);
      }
    } catch (_) {
      // 解析异常时兜底回首页
      _goHomeSafe(context);
    }
  }
}
