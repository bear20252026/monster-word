// 使用统计功能域的装配入口。
//
// 依赖方向：本 feature **不依赖任何其它 feature**（只读自己的表 + 一个 HTTP 出口），
// 所以可以挂在最外层。它被 app.dart 的生命周期钩子（前台/后台）与更多设置页消费。
//
// 上报频率、开关默认值、保留期这些口径都在 UsageStatsCollector / PrefsUsageStatsSettings
// 的注释里，改之前先读那边。

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import 'package:word_app/features/telemetry/application/usage_stats_collector.dart';
import 'package:word_app/features/telemetry/application/usage_stats_ports.dart';
import 'package:word_app/features/telemetry/data/http_usage_stats_uploader.dart';
import 'package:word_app/features/telemetry/data/platform_usage_stats_environment.dart';
import 'package:word_app/features/telemetry/data/prefs_usage_stats_settings.dart';
import 'package:word_app/features/telemetry/data/usage_stats_dao.dart';

Widget buildTelemetryFeatureScope({required Widget child}) {
  return MultiProvider(
    providers: [
      Provider<UsageStatsStore>(create: (_) => UsageStatsDao()),
      Provider<UsageStatsUploader>(create: (_) => HttpUsageStatsUploader()),
      Provider<UsageStatsEnvironment>(create: (_) => PlatformUsageStatsEnvironment()),
      Provider<UsageStatsSettings>(create: (_) => PrefsUsageStatsSettings()),
      Provider<UsageStatsCollector>(
        create: (context) {
          final collector = UsageStatsCollector(
            store: context.read<UsageStatsStore>(),
            uploader: context.read<UsageStatsUploader>(),
            environment: context.read<UsageStatsEnvironment>(),
            settings: context.read<UsageStatsSettings>(),
            // 时钟注入而不是内部直接 DateTime.now()：跨午夜切分与退避判断都要能测。
            clock: DateTime.now,
          );
          // 读开关是异步的；create 不能 await。初始化完成前所有 record* 都会
          // 因 _enabled=false 而空转 —— 这是有意的保守行为（宁可漏记开头几毫秒，
          // 也不要「开关还没读出来就先记了一条」）。
          unawaited(collector.initialize());
          return collector;
        },
      ),
      // 设置页只依赖 application 层的窄接口（架构守卫 R4：跨 feature 只能 import
      // 对方的 application 层）。同一个 collector 实例，两种暴露面。
      ProxyProvider<UsageStatsCollector, UsageStatsController>(update: (_, c, _) => c),
    ],
    child: child,
  );
}
