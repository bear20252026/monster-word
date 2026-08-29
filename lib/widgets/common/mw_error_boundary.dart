// Monster Word — 全局错误边界
//
// Flutter 默认的 widget 异常界面是红底黄字（debug）/灰字（release），
// 商业产品必须兜住：任何页面组件崩溃只降级该页面，不吓用户。
// 通过覆盖 ErrorWidget.builder 全局生效（在 MaterialApp.builder 里调用一次）。
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// 接管 Flutter 全局 widget 异常渲染。
///
/// 仅 release 生效：debug/test 下 flutter_test 会校验 ErrorWidget.builder
/// 未被修改（widget_test 冒烟启动 app 会触发校验失败），且开发期需要
/// 保留原始红字定位问题。debug 期的页面级降级由 MwErrorBoundary 负责。
void installMwErrorBoundary() {
  if (!kReleaseMode) return;
  ErrorWidget.builder = mwErrorBuilder;
}

/// 友好错误页 builder（公开以便测试直接注入）。
Widget mwErrorBuilder(FlutterErrorDetails details) {
  debugPrint('[ErrorBoundary] ${details.exception}');
  return const _MwErrorPage();
}

class _MwErrorPage extends StatelessWidget {
  const _MwErrorPage();

  @override
  Widget build(BuildContext context) {
    // ErrorWidget 渲染时可能没有任何皮肤/Directionality 上下文，
    // 自带 Material + Directionality 兜底；深色统一（与暗色主题亲和）。
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Material(
        color: const Color(0xFF16181D),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: const Color(0xFF24272D),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF3A3E45)),
                  ),
                  child: const Icon(Icons.extension_off_rounded, size: 30, color: Color(0xFF8E939B)),
                ),
                const SizedBox(height: 20),
                const Text(
                  '页面出错了',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Colors.white),
                ),
                const SizedBox(height: 8),
                const Text(
                  '这个区域暂时无法显示，返回后重试即可。',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Color(0xFFB0B4BA)),
                ),
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  onPressed: () {
                    // 尽力回退：错误页通常已被 push，pop 掉它即可回到崩溃前页面
                    final navigator = Navigator.maybeOf(context);
                    if (navigator != null && navigator.canPop()) navigator.pop();
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFF3A3E45)),
                  ),
                  icon: const Icon(Icons.arrow_back_rounded, size: 18),
                  label: const Text('返回上一页'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


