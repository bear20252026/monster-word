// P2-8（架构审计 2026-11-12）：共享演出驱动 CelebrationDriver 单测。
// 锚定：进度推进、完成回调一次、stop 归零、replay 重播、Listenable 每帧通知。
// vsync 经探针 widget 的 TickerProviderStateMixin 提供（绑定测试帧时钟，随 pump 推进）。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:word_app/core/utils/celebration_driver.dart';

/// 探针：把自身 State（TickerProvider）交出来，供驱动作 vsync。
class _VsyncProbe extends StatefulWidget {
  const _VsyncProbe({required this.onVsync});
  final void Function(TickerProvider vsync) onVsync;
  @override
  State<_VsyncProbe> createState() => _VsyncProbeState();
}

class _VsyncProbeState extends State<_VsyncProbe> with TickerProviderStateMixin {
  @override
  void initState() {
    super.initState();
    widget.onVsync(this);
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

Future<TickerProvider> _pumpVsync(WidgetTester tester) async {
  late TickerProvider vsync;
  await tester.pumpWidget(_VsyncProbe(onVsync: (v) => vsync = v));
  return vsync;
}

void main() {
  testWidgets('play 推进进度并在完成时回调一次', (tester) async {
    final vsync = await _pumpVsync(tester);
    var completed = 0;
    final driver = CelebrationDriver(
      vsync: vsync,
      duration: const Duration(milliseconds: 200),
      onCompleted: () => completed++,
    );
    addTearDown(driver.dispose);

    expect(driver.progress, 0);
    expect(driver.isPlaying, isFalse);

    driver.play();
    expect(driver.isPlaying, isTrue);

    await tester.pump(); // 启动帧
    await tester.pump(const Duration(milliseconds: 100));
    expect(driver.progress, greaterThan(0));
    expect(driver.progress, lessThan(1));
    expect(completed, 0);

    await tester.pump(const Duration(milliseconds: 150)); // 过冲确保到达 completed
    expect(driver.progress, 1);
    expect(completed, 1);
    expect(driver.isPlaying, isFalse);
  });

  testWidgets('stop 归零进度并停止播放', (tester) async {
    final vsync = await _pumpVsync(tester);
    final driver = CelebrationDriver(vsync: vsync, duration: const Duration(milliseconds: 200));
    addTearDown(driver.dispose);

    driver.play();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(driver.progress, greaterThan(0));

    driver.stop();
    expect(driver.progress, 0);
    expect(driver.isPlaying, isFalse);
  });

  testWidgets('replay 从头重播并再次触发完成回调', (tester) async {
    final vsync = await _pumpVsync(tester);
    var completed = 0;
    final driver = CelebrationDriver(
      vsync: vsync,
      duration: const Duration(milliseconds: 100),
      onCompleted: () => completed++,
    );
    addTearDown(driver.dispose);

    driver.play();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150)); // 过冲确保 completed
    expect(completed, 1);

    driver.replay();
    await tester.pump();
    expect(driver.progress, lessThan(1));
    await tester.pump(const Duration(milliseconds: 150)); // 过冲确保再次 completed
    expect(completed, 2);
  });

  testWidgets('Listenable 每帧通知订阅者', (tester) async {
    final vsync = await _pumpVsync(tester);
    final driver = CelebrationDriver(vsync: vsync, duration: const Duration(milliseconds: 200));
    var ticks = 0;
    driver.addListener(() => ticks++);

    driver.play();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));
    expect(ticks, greaterThan(0));

    driver.stop(); // 停止 ticker，避免 teardown 时仍在跑
    driver.dispose();
  });

  testWidgets('controller getter 暴露底层供 CurvedAnimation/Interval', (tester) async {
    final vsync = await _pumpVsync(tester);
    final driver = CelebrationDriver(vsync: vsync, duration: const Duration(milliseconds: 200));
    addTearDown(driver.dispose);
    expect(driver.controller, isA<AnimationController>());
    expect(driver.controller.duration, const Duration(milliseconds: 200));
  });
}
