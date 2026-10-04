// MemoFutureBuilder：跨重建记忆的 FutureBuilder（性能审计 P2，2026-10-04）。
//
// 针对「build 里新建 future」的两件套缺陷：
//  ① 快照回退闪 0——每次重建 future 引用变化，FutureBuilder 回到等待态，
//    `snap.data ?? 0` 让余额/计数闪回占位值；
//  ② 重建风暴重复发起查询——任何祖先 setState 都会重跑 DB/SP 查询。
//
// 本组件在 TTL 窗口（默认 800ms）内复用同一 future（去重建风暴），等待期
// 显示上一次成功值（不闪 0）；TTL 过期后的任意重建会重新取数——从子页返回
// 触发的 pop 重建通常已过 TTL，数据照常刷新。
import 'package:flutter/widgets.dart';

class MemoFutureBuilder<T> extends StatefulWidget {
  const MemoFutureBuilder({
    super.key,
    required this.create,
    required this.builder,
    this.ttl = const Duration(milliseconds: 800),
    this.placeholder,
  });

  /// 取数入口（原写在 build 里的 `context.read<X>().query()`）。
  final Future<T> Function() create;

  /// [data] 为 null 表示从未取到过值（首帧），调用方决定占位展示。
  final Widget Function(BuildContext context, T? data) builder;

  /// future 复用窗口。
  final Duration ttl;

  /// 从未成功取数时的展示值（与 builder 的 null 分支二选一使用）。
  final T? placeholder;

  @override
  State<MemoFutureBuilder<T>> createState() => _MemoFutureBuilderState<T>();
}

class _MemoFutureBuilderState<T> extends State<MemoFutureBuilder<T>> {
  Future<T>? _future;
  DateTime _fetchedAt = DateTime.fromMillisecondsSinceEpoch(0);
  T? _lastData;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    if (_future == null || now.difference(_fetchedAt) > widget.ttl) {
      _future = widget.create();
      _fetchedAt = now;
      _future!.then((value) {
        if (!mounted) return;
        setState(() => _lastData = value);
      });
    }
    return FutureBuilder<T>(
      future: _future,
      builder: (context, snap) => widget.builder(context, snap.hasData ? snap.data : (_lastData ?? widget.placeholder)),
    );
  }
}
