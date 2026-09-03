/// ─── 依赖注入约定（2026-08-30 健康评估 M1/M2 落地）──────────────────
///
/// 全库两条装配通道，不许混用第三种：
/// 1. **get_it（本文件配套的 app/service_locator.dart）**：只注册
///    「跨 feature 基础设施」——DB、音频、session、各 feature 的
///    端口实现（data 层 XxxRepository/Reader/WriterPort）。
/// 2. **Provider（各 feature 的 *_feature_providers.dart）**：注册
///    「presentation 层可观察状态」（ChangeNotifier）与页面依赖。
///
/// 禁止：
/// - service_locator 注册任何 presentation/ 下的类型（ChangeNotifier
///   的生命周期归 Provider 管，见 NewWordsState 迁移先例）。
/// - feature 的 presentation 层直接 `sl<>` 取依赖（走 Provider）；
///   `*_feature_providers.dart` 是装配边界例外。存量 3 处已于 v2.7.40
///   收口（A3），新增即被 R6-DI 规则拦截。
/// - widgets/ 共享组件层消费 feature 的 domain/data/presentation 内部
///   实现（A2，v2.7.40 起由 R-widgets 规则拦截；application 端口放行）。
/// - 新增第三种装配通道。
// 由 Claude 团队生成 | Monster Word App
//
// 依赖边界守卫（data-driven，无 IO、无 Flutter）。
//
// 本工具只做「判定」：给定一个 from（发起 import 的文件的 lib/ 相对逻辑路径）
// 与一个 to（被 import 的目标的逻辑路径或外部包前缀），返回违规说明列表（空 = 通过）。
// 它不读取文件系统 —— 具体扫描 lib/**/*.dart、解析 import URI 的工作由
// test/architecture/import_guard_test.dart 的 harness 承担，以便本文件保持纯净、可单测。
//
// 规则来源：《TEAM_COLLABORATION_FRAMEWORK.md》§2 依赖规则（R3/R4/R5）。
//
// 路径约定：传入的 from/to 均为 `lib/` 相对逻辑路径，例如：
//   - from: 'features/account/presentation/my_space_page.dart'
//   - to:   'core/scare_coin/scare_coin_store.dart'（相对 import 在 harness 中已解析成此类路径）
//   - 外部 import 保留原前缀：'package:flutter/material.dart'、'dart:async'、'package:provider/...'。
//     （此类 to 不满足 features/ 前缀，故只受 R5 领域纯净规则约束。）
class ImportGuard {
  const ImportGuard();

  static const List<String> _featureLayers = ['domain', 'application', 'data', 'presentation'];

  /// 校验单条 import，返回违规说明列表；为空表示允许。
  List<String> check({required String from, required String to}) {
    final violations = <String>[];
    final fromFeature = _featureOf(from);
    final toFeature = _featureOf(to);
    final fromLayer = _layerOf(from);
    final toLayer = _layerOf(to);

    // R4：跨功能 import 禁止 —— 一个 feature 不得 import 另一个 feature 的
    // domain / data / presentation 内部实现。
    //
    // 例外（sanctioned port/channel，见 test/architecture/app_structure_test.dart）：
    // 允许跨 feature 仅 import 对方 feature 的 `application/` 层抽象端口。这是
    // 端口-适配器架构允许的功能间通道（如 SentenceFavoritesStore、WordNotesStore、
    // ReviewScheduleReader 由其它 feature 的 presentation 消费）。application 层
    // 只暴露抽象契约、不承载具体页面/仓储实现，因此这种跨 feature 引用是安全的。
    final isCrossFeature = fromFeature.isNotEmpty && toFeature.isNotEmpty && toFeature != fromFeature;
    if (isCrossFeature) {
      final isPortChannel = toLayer == 'application';
      // 2026-08-31 C2：聚合页豁免已清除——home/profile 的跨域路由跳转
      // 已改走 RouteNames 集中表，跨域状态消费已迁 application 端口通道。
      if (!isPortChannel) {
        violations.add('跨功能 import 被禁止(R4): $from -> $to');
      }
    }

    // core 依赖方向：core 不得反向依赖 features。
    // 组合根：app/router/ 是路由装配边界，按其设计必须引用各页面（只做组装、不承载
    // 业务逻辑）。组合根本体已上移 app/service_locator.dart（v2.7.37）、app/router/
    //（v2.7.44），core/di 不复存在；core 其余部分由 app_structure_test 的
    // REG-ARCH-002 守卫锁定零 feature 依赖。
    final isCompositionRoot = from.startsWith('app/router/');
    if (!isCompositionRoot && from.startsWith('core/') && to.startsWith('features/')) {
      violations.add('core 不得 import features(R-core): $from -> $to');
    }

    // R6：feature 不得反向依赖壳层 —— feature 不得 import screens/ 或 app/（组合根）。
    // 壳层只有组合根（app/app.dart、app/router/）可以引用 feature；feature 只能
    // 通过 RouteNames 等路由契约做跨功能导航，不得 import 壳层实现。
    // 豁免：app/service_locator.dart 是 get_it 容器（组合根产出的 DI 契约），
    // feature 经它访问 sl<> 是两条装配通道之一，不算 import 壳层实现；
    // app/router/ 同理（组合根产出的路由契约：RouteNames 集中表、nav_utils），
    // feature/widgets 消费契约不算 import 壳层装配实现。
    final isDiContract = to == 'app/service_locator.dart';
    final isRouteContract = to.startsWith('app/router/');
    if (!isDiContract &&
        !isRouteContract &&
        fromFeature.isNotEmpty &&
        (to.startsWith('screens/') || to.startsWith('app/'))) {
      violations.add('feature 不得 import 壳层 screens/app(R6): $from -> $to');
    }

    // R6-DI（A3 收口）：DI 契约仅 data 层适配器与 *_feature_providers.dart 装配边界
    // 可用；feature 的 presentation 页面必须走 Provider 注入，不得直取 sl<>。
    final isProviderAssembly = from.endsWith('_feature_providers.dart');
    if (isDiContract && fromFeature.isNotEmpty && fromLayer == 'presentation' && !isProviderAssembly) {
      violations.add('presentation 不得直取 DI 契约(R6-DI): $from -> $to（改走 Provider 注入）');
    }

    // R-widgets（A2 收口）：共享组件层（widgets/）位于 R4/R6 的 from 域之外，
    // 此前完全脱离守卫。规则：可消费 feature 的 application 端口（端口-适配器
    // 允许的功能间通道），不得进入 feature 的 domain/data/presentation 内部，
    // 也不得 import 壳层 app/（组合根归 app.dart 专用）。
    final isWidgetsLayer = from.startsWith('widgets/');
    if (isWidgetsLayer) {
      if (toFeature.isNotEmpty && toLayer != 'application') {
        violations.add('widgets 只能消费 feature application 端口(R-widgets): $from -> $to');
      }
      if (to.startsWith('app/') && !isRouteContract) {
        violations.add('widgets 不得 import 壳层 app/(R-widgets): $from -> $to');
      }
    }

    // R3：分层只向内 —— 仅对同一 feature 内的层间 import 生效。
    final sameFeature = fromFeature.isNotEmpty && fromFeature == toFeature;
    if (sameFeature) {
      if (fromLayer == 'domain' && (toLayer == 'application' || toLayer == 'data' || toLayer == 'presentation')) {
        violations.add('R3: domain 不得依赖同功能的上层($toLayer): $from -> $to');
      }
      if (fromLayer == 'application' && (toLayer == 'data' || toLayer == 'presentation')) {
        violations.add('R3: application 不得依赖同功能的 $toLayer 层: $from -> $to');
      }
      if (fromLayer == 'data' && toLayer == 'presentation') {
        violations.add('R3: data 不得依赖同功能的 presentation 层: $from -> $to');
      }
    }

    // R5：领域纯净 —— domain 不得依赖 Flutter/UI。
    if (fromLayer == 'domain' && (to.startsWith('package:flutter/') || to == 'dart:ui' || to.startsWith('dart:ui/'))) {
      violations.add('R5: domain 不得依赖 Flutter/UI: $from -> $to');
    }

    return violations;
  }

  /// 返回路径所属的 feature（`features/` 后第一段），否则空串。
  String _featureOf(String path) {
    if (path.startsWith('features/')) {
      final rest = path.substring('features/'.length);
      final slash = rest.indexOf('/');
      if (slash > 0) return rest.substring(0, slash);
    }
    return '';
  }

  /// 返回路径所属的层名（`features/` 后第二段），非 feature 层路径返回空串。
  String _layerOf(String path) {
    if (path.startsWith('features/')) {
      final rest = path.substring('features/'.length);
      final parts = rest.split('/');
      if (parts.length >= 2 && _featureLayers.contains(parts[1])) return parts[1];
    }
    return '';
  }
}
