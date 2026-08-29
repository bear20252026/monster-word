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
    final isCrossFeature =
        fromFeature.isNotEmpty && toFeature.isNotEmpty && toFeature != fromFeature;
    if (isCrossFeature) {
      final isPortChannel = toLayer == 'application';
      if (!isPortChannel) {
        violations.add('跨功能 import 被禁止(R4): $from -> $to');
      }
    }

    // core 依赖方向：core 不得反向依赖 features。
    // 例外：core/di 与 core/router 是 IoC 组合根/装配边界，按其设计必须引用
    // feature 的实现（DI 注册表注册各 feature 的端口实现；路由协调器装配各页面）。
    // 它们只做「组装」，不承载业务逻辑，因此豁免 R-core，避免依赖方向误报。
    final isCompositionRoot = from.startsWith('core/di/') ||
        from.startsWith('core/router/');
    if (!isCompositionRoot &&
        from.startsWith('core/') &&
        to.startsWith('features/')) {
      violations.add('core 不得 import features(R-core): $from -> $to');
    }

    // R6：feature 不得反向依赖壳层 —— feature 不得 import screens/ 或 app/（组合根）。
    // 壳层只有组合根（app/app.dart、core/router）可以引用 feature；feature 只能
    // 通过 core 的 routeNames 等契约做跨功能导航，不得 import 壳层实现。
    if (fromFeature.isNotEmpty &&
        (to.startsWith('screens/') || to.startsWith('app/'))) {
      violations.add('feature 不得 import 壳层 screens/app(R6): $from -> $to');
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
    if (fromLayer == 'domain' &&
        (to.startsWith('package:flutter/') || to == 'dart:ui' || to.startsWith('dart:ui/'))) {
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
