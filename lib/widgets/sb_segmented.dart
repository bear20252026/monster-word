import 'package:flutter/material.dart';

/// 星巴克分段控件
///
/// 用于学习模式切换等场景，支持泛型键值对。
///
/// 规格（遵循 docs/component_spec.md §9）：
/// - 轨道：ceramic #edebe9 实底、全胶囊圆角 50、内衬 4
/// - 选中段：白底小卡浮起（双层阴影）+ 绿字 #00754A w600
/// - 未选中：透明底黑 87 w400
/// - 尺寸：段高 44；文字 15px
/// - 动画：选中滑块 AnimatedAlign 200ms ease
///
/// 示例：
/// ```dart
/// SbSegmented<String>(
///   segments: {'new': '新学', 'review': '复习'},
///   value: 'new',
///   onChanged: (v) => setState(() => _mode = v),
/// )
/// ```
class SbSegmented<T> extends StatelessWidget {
  /// 分段项映射，键为值，键为显示文字
  final Map<T, String> segments;

  /// 当前选中的值
  final T value;

  /// 选中项变化回调
  final ValueChanged<T> onChanged;

  const SbSegmented({
    super.key,
    required this.segments,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final keys = segments.keys.toList();
    final i = keys.indexOf(value);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFEDEBE9), // ceramic 轨道
        borderRadius: BorderRadius.circular(50), // 全胶囊圆角
      ),
      child: LayoutBuilder(builder: (context, c) {
        final w = (c.maxWidth - 8) / keys.length;
        return Stack(children: [
          // 选中滑块：白底小卡浮起 + 双层阴影
          AnimatedAlign(
            alignment: Alignment(i * 2 / (keys.length - 1) - 1, 0),
            duration: const Duration(milliseconds: 200),
            curve: Curves.ease,
            child: SizedBox(
              width: w,
              height: 44,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(50),
                  boxShadow: const [
                    // 双层阴影（同 §2 ContentCard）
                    BoxShadow(
                      offset: Offset.zero,
                      blurRadius: 0.5,
                      color: Color(0x24000000), // rgba(0,0,0,.14)
                    ),
                    BoxShadow(
                      offset: Offset(0, 1),
                      blurRadius: 1,
                      color: Color(0x3D000000), // rgba(0,0,0,.24)
                    ),
                  ],
                ),
              ),
            ),
          ),
          // 分段文字
          Row(children: [
            for (final k in keys)
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(50),
                  onTap: () => onChanged(k),
                  child: SizedBox(
                    height: 44,
                    child: Center(
                      child: Text(
                        segments[k]!,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: k == value
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: k == value
                              ? const Color(0xFF00754A) // 绿字 #00754A
                              : const Color(0xDE000000), // 黑 87
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ]),
        ]);
      }),
    );
  }
}
