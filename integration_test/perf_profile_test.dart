// 真机（Windows 桌面）性能剖析 harness —— P3「性能剖析（帧率/内存）」。
//
// 运行方式（profile 模式，帧数据才有代表性）：
//   flutter test integration_test/perf_profile_test.dart -d windows --profile
//
// 职责：
//   1. 泵真实应用（完整 bootstrapApp + WordApp），走真实用户路径：
//      启动首帧 → 一级 Tab 切换（课程）→ 词书网格滚动 → 单词浏览页滚动；
//   2. 采集每场景 FrameTiming（build/raster/total、jank 计数）与 RSS 内存曲线；
//   3. 只报告数据、不设性能阈值断言（本机性能噪声大，阈值留给 CI 之外的
//      人工评审），结果落 build/perf_report.json + 控制台摘要。
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';

import 'package:word_app/app/app.dart';
import 'package:word_app/app/app_bootstrap.dart';
import 'package:word_app/app/router/route_names.dart';
import 'package:word_app/features/book/application/book_catalog_reader.dart';

const _wait = Duration(milliseconds: 1200);

final _frames = <FrameTiming>[];
final _memory = <Map<String, Object>>[];
final _stages = <Map<String, Object>>[];
final _attribution = <Map<String, Object>>[];

Map<String, Object> _summarize(String name, Iterable<FrameTiming> timings) {
  final total = timings.map((t) => t.totalSpan.inMicroseconds / 1000).toList()..sort();
  final build = timings.map((t) => t.buildDuration.inMicroseconds / 1000).toList()..sort();
  final raster = timings.map((t) => t.rasterDuration.inMicroseconds / 1000).toList()..sort();

  double pct(List<double> xs, double p) => xs.isEmpty ? 0 : xs[((xs.length - 1) * p).clamp(0, xs.length - 1).toInt()];

  return <String, Object>{
    'stage': name,
    'frames': total.length,
    'buildP50Ms': _r2(pct(build, 0.50)),
    'buildP95Ms': _r2(pct(build, 0.95)),
    'rasterP50Ms': _r2(pct(raster, 0.50)),
    'rasterP95Ms': _r2(pct(raster, 0.95)),
    'totalP50Ms': _r2(pct(total, 0.50)),
    'totalP95Ms': _r2(pct(total, 0.95)),
    'totalMaxMs': _r2(total.isEmpty ? 0 : total.last),
    // jank：桌面 60Hz 标准帧预算 16.7ms；34ms+ 为明显卡顿（掉 2 帧+）。
    'jank17': total.where((ms) => ms > 17).length,
    'jank34': total.where((ms) => ms > 34).length,
  };
}

double _r2(double v) => (v * 100).round() / 100;

Future<void> _recordStage(WidgetTester tester, String name, {required int beforeCount}) async {
  await Future<void>.delayed(_wait);
  await tester.pump();
  final slice = _frames.sublist(beforeCount.clamp(0, _frames.length));
  final stage = _summarize(name, slice);
  _stages.add(stage);
  _memory.add({'stage': name, 'rssMB': _r2(ProcessInfo.currentRss / 1048576)});
  debugPrint('[perf] $stage');
}

/// 从应用 navigator 语境读 provider（provider 作用域包着 MaterialApp）。
T _read<T>(WidgetTester tester) {
  final ctx = tester.element(find.byType(Navigator).first);
  return Provider.of<T>(ctx, listen: false);
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  // 帧由引擎真实 vsync 驱动（而非测试假帧），FrameTiming 才有代表性。
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('真机性能剖析：启动/Tab 切换/词书网格滚动/单词列表滚动', (tester) async {
    final sw = Stopwatch()..start();
    await bootstrapApp();
    final bootstrapMs = sw.elapsedMilliseconds;
    debugPrint('[perf] bootstrapApp: ${bootstrapMs}ms');

    SchedulerBinding.instance.addTimingsCallback((timings) => _frames.addAll(timings));

    runApp(const WordApp());
    await Future<void>.delayed(const Duration(seconds: 2));
    await tester.pump();

    // ---- 场景 1：启动首帧（含首屏波次入场）----
    _memory.add({'stage': '启动完成', 'rssMB': _r2(ProcessInfo.currentRss / 1048576)});
    final startupBefore = 0;
    await _recordStage(tester, '启动首屏', beforeCount: startupBefore);

    // ---- 场景 2：一级 Tab 切换 → 课程（词书网格）+ 内存跳变归因 ----
    // P2 归因（perf 2026-09-28）：此前该步 RSS 一次性 +203MB，此处加
    // 250ms 细粒度采样 + imageCache 统计 + 清缓存/二次进入对比，定位跳变
    // 落点（首帧光栅分配 vs 图像解码 vs 数据流渐增）。
    var before = _frames.length;
    final cache = PaintingBinding.instance.imageCache;
    Map<String, Object> cacheStats() => {
      'imageCacheCount': cache.currentSize,
      'imageCacheMB': _r2(cache.currentSizeBytes / 1048576),
      'liveImageCount': cache.liveImageCount,
    };
    _attribution.add({'step': '切换前(学习Tab)', 'rssMB': _r2(ProcessInfo.currentRss / 1048576), ...cacheStats()});
    await tester.tap(find.byIcon(Icons.school_outlined));
    final samples = <Map<String, Object>>[];
    for (var i = 0; i < 12; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      await tester.pump();
      samples.add({'tMs': (i + 1) * 250, 'rssMB': _r2(ProcessInfo.currentRss / 1048576)});
    }
    _attribution.add({'step': '切换后3s采样', 'samples': samples, ...cacheStats()});
    await _recordStage(tester, 'Tab切换→课程', beforeCount: before);

    cache.clear();
    cache.clearLiveImages();
    await Future<void>.delayed(const Duration(milliseconds: 500));
    await tester.pump();
    _attribution.add({'step': '清图像缓存后', 'rssMB': _r2(ProcessInfo.currentRss / 1048576), ...cacheStats()});

    // 切回学习 Tab（离开课程页）：若 RSS 回落 → 光栅/缓存性；不回落 → 被保留。
    await tester.tap(find.byIcon(Icons.auto_stories_outlined));
    await Future<void>.delayed(const Duration(seconds: 1));
    await tester.pump();
    _attribution.add({'step': '切回学习Tab(1s)', 'rssMB': _r2(ProcessInfo.currentRss / 1048576), ...cacheStats()});

    // 二次进入课程 Tab：首帧光栅已做过一次，若不再跳变 → 首次绘制分配。
    await tester.tap(find.byIcon(Icons.school_outlined));
    await Future<void>.delayed(const Duration(seconds: 1));
    await tester.pump();
    _attribution.add({'step': '二次进入课程Tab(1s)', 'rssMB': _r2(ProcessInfo.currentRss / 1048576), ...cacheStats()});

    // ---- 场景 3：词书网格滚动（流动入场 + 懒加载行）----
    before = _frames.length;
    final grid = find.byType(Scrollable).first;
    for (var i = 0; i < 3; i++) {
      await tester.drag(grid, const Offset(0, -500));
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 400));
    }
    for (var i = 0; i < 2; i++) {
      await tester.drag(grid, const Offset(0, 500));
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 400));
    }
    await _recordStage(tester, '词书网格滚动', beforeCount: before);

    // ---- 场景 4：单词浏览页（列表 FlowIn + 滚动）----
    final books = await _read<BookCatalogReader>(tester).listBooks();
    expect(books, isNotEmpty, reason: '本地词库为空，无法进行单词列表剖析');
    before = _frames.length;
    final navCtx = tester.element(find.byType(Navigator).first);
    // 与 lib_select_page._openBookWords 同参契约
    Navigator.pushNamed(
      navCtx,
      RouteNames.bookWords,
      arguments: {'bookId': books.first.id, 'bookName': books.first.name},
    );
    await tester.pump();
    await _recordStage(tester, '进入单词浏览页', beforeCount: before);

    // ---- 场景 5：单词列表滚动 ----
    // 词表加载期间是骨架屏（无 Scrollable）：就绪轮询最多 ~6s，未就绪则
    // 跳过滚动场景但仍写报告（harness 是测量工具，不因数据慢而崩）。
    before = _frames.length;
    var listReady = false;
    for (var i = 0; i < 20; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 300));
      await tester.pump();
      if (find.byType(Scrollable).evaluate().isNotEmpty) {
        listReady = true;
        break;
      }
    }
    if (listReady) {
      final list = find.byType(Scrollable).first;
      for (var i = 0; i < 4; i++) {
        await tester.drag(list, const Offset(0, -600));
        await tester.pump();
        await Future<void>.delayed(const Duration(milliseconds: 400));
      }
      for (var i = 0; i < 2; i++) {
        await tester.drag(list, const Offset(0, 600));
        await tester.pump();
        await Future<void>.delayed(const Duration(milliseconds: 400));
      }
      await _recordStage(tester, '单词列表滚动', beforeCount: before);
    } else {
      debugPrint('[perf] 单词列表未就绪（骨架屏超时），跳过滚动场景');
      _memory.add({'stage': '单词列表(未就绪跳过)', 'rssMB': _r2(ProcessInfo.currentRss / 1048576)});
    }

    // ---- 汇总输出 ----
    final report = <String, Object>{
      'platform': Platform.operatingSystemVersion,
      'timestamp': DateTime.now().toIso8601String(),
      'mode': 'profile',
      'bootstrapMs': bootstrapMs,
      'stages': _stages,
      'memory': _memory,
      'attribution': _attribution,
    };
    final encoded = const JsonEncoder.withIndent('  ').convert(report);
    final out = File('build/perf_report.json');
    out.parent.createSync(recursive: true);
    out.writeAsStringSync(encoded);
    debugPrint('[perf] 报告已写入 ${out.path}');
    debugPrint(encoded);
  }, timeout: const Timeout(Duration(minutes: 15)));
}
