import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:word_app/core/import_guard.dart';

void main() {
  group('ImportGuard 规则判定（纯逻辑）', () {
    const guard = ImportGuard();

    List<String> check(String from, String to) => guard.check(from: from, to: to);

    test('R4: 跨功能 import 被拒绝(除 application 端口通道)', () {
      // 跨 feature 引用对方具体实现层（presentation/data/domain）→ 拒绝。
      expect(
        check(
          'features/account/presentation/my_space_page.dart',
          'features/scare_coin/presentation/scare_coin_page.dart',
        ),
        anyElement(contains('跨功能 import 被禁止(R4)')),
      );
      expect(
        check('features/account/presentation/my_space_page.dart', 'features/scare_coin/data/scare_coin_store.dart'),
        anyElement(contains('跨功能 import 被禁止(R4)')),
      );
      // 跨 feature 仅引用对方 application 层抽象端口 → 允许。这是端口-适配器架构
      // 允许的功能间通道（app_structure_test.dart 强制 word_detail/my_fav_sentence
      // 消费 SentenceFavoritesStore / WordNotesStore / ReviewScheduleReader）。
      expect(
        check(
          'features/account/presentation/my_space_page.dart',
          'features/scare_coin/application/scare_coin_store.dart',
        ),
        isEmpty,
      );
    });

    test('同功能内部 import 允许', () {
      expect(check('features/learning/presentation/page.dart', 'features/learning/data/repo.dart'), isEmpty);
      expect(check('features/learning/data/repo.dart', 'features/learning/application/port.dart'), isEmpty);
    });

    test('feature 依赖 core/models 允许；core 依赖 features 被拒绝', () {
      expect(check('features/account/presentation/my_space_page.dart', 'models/scare_coin_entry.dart'), isEmpty);
      expect(
        check('core/learning/learning_session_starter.dart', 'features/learning/presentation/state.dart'),
        anyElement(contains('core 不得 import features(R-core)')),
      );
    });

    test('R3: domain 不得依赖同功能上层', () {
      expect(
        check('features/learning/domain/choice_generator.dart', 'features/learning/application/starter.dart'),
        anyElement(contains('R3: domain 不得依赖同功能的上层')),
      );
      expect(
        check('features/learning/domain/choice_generator.dart', 'features/learning/presentation/page.dart'),
        anyElement(contains('R3: domain 不得依赖同功能的上层')),
      );
    });

    test('R3: application 不得依赖 data/presentation', () {
      expect(
        check('features/learning/application/starter.dart', 'features/learning/data/repo.dart'),
        anyElement(contains('R3: application 不得依赖同功能的 data 层')),
      );
      expect(
        check('features/learning/application/starter.dart', 'features/learning/presentation/page.dart'),
        anyElement(contains('R3: application 不得依赖同功能的 presentation 层')),
      );
    });

    test('R3: data 不得依赖 presentation', () {
      expect(
        check('features/learning/data/impl.dart', 'features/learning/presentation/state.dart'),
        anyElement(contains('R3: data 不得依赖同功能的 presentation 层')),
      );
    });

    test('R5: domain 不得依赖 Flutter/UI，但允许 dart:* 与 models', () {
      expect(
        check('features/learning/domain/choice_generator.dart', 'package:flutter/material.dart'),
        anyElement(contains('R5: domain 不得依赖 Flutter/UI')),
      );
      expect(check('features/learning/domain/choice_generator.dart', 'dart:math'), isEmpty);
      expect(check('features/learning/domain/choice_generator.dart', 'package:word_app/models/word.dart'), isEmpty);
    });

    test('R6: feature 不得 import 壳层 screens/app', () {
      expect(
        check('features/learning/presentation/learn_session.dart', 'screens/learn_session.dart'),
        anyElement(contains('feature 不得 import 壳层 screens/app(R6)')),
      );
      expect(
        check('features/account/presentation/my_page.dart', 'app/app.dart'),
        anyElement(contains('feature 不得 import 壳层 screens/app(R6)')),
      );
      // 组合根不受限：app/router 可装配 feature 页面
      expect(check('app/router/learning_routes.dart', 'features/learning/presentation/learn_session.dart'), isEmpty);
    });

    test('R6-DI: feature presentation 不得直取 DI 契约（A3 收口）', () {
      // presentation 页面 import app/service_locator → 违规（走 Provider）
      expect(
        check('features/learning/presentation/personal_stereo_page.dart', 'app/service_locator.dart'),
        anyElement(contains('presentation 不得直取 DI 契约(R6-DI)')),
      );
      // 装配边界（*_feature_providers.dart）与 data 层适配器放行
      expect(
        check('features/learning/presentation/learning_feature_providers.dart', 'app/service_locator.dart'),
        isEmpty,
      );
      expect(check('features/learning/data/repository_favorites_port.dart', 'app/service_locator.dart'), isEmpty);
    });

    test('R-widgets: widgets 层只能消费 feature application 端口（A2 收口）', () {
      // widgets import feature presentation/data/domain → 违规
      expect(
        check('widgets/review_dialog.dart', 'features/learning/presentation/learning_session_state.dart'),
        anyElement(contains('widgets 只能消费 feature application 端口(R-widgets)')),
      );
      expect(
        check('widgets/some_card.dart', 'features/book/data/book_repository.dart'),
        anyElement(contains('widgets 只能消费 feature application 端口(R-widgets)')),
      );
      // widgets import 壳层 app/ → 违规
      expect(
        check('widgets/some_card.dart', 'app/service_locator.dart'),
        anyElement(contains('widgets 不得 import 壳层 app/(R-widgets)')),
      );
      // widgets import feature application 端口 → 放行
      expect(
        check('widgets/spring_check_in_calendar.dart', 'features/checkin/application/checkin_status_reader.dart'),
        isEmpty,
      );
      // widgets import core/models/theme → 放行
      expect(check('widgets/some_card.dart', 'core/repositories/word_repository.dart'), isEmpty);
    });

    test('非 feature、非 core 壳层（遗留薄适配）依赖 feature 允许', () {
      expect(check('pages/book_words_page.dart', 'features/learning/presentation/state.dart'), isEmpty);
    });
  });

  group('ImportGuard 全库扫描 harness', () {
    test('lib/**/*.dart 不存在依赖边界违规', () {
      final violations = _scanLib();
      expect(violations, isEmpty, reason: violations.isEmpty ? null : '发现依赖边界违规：\n${violations.join('\n')}');
    });
  });
}

/// 扫描 lib/**/*.dart 的所有 import/export，解析为逻辑路径后交给 [ImportGuard]。
List<String> _scanLib() {
  const guard = ImportGuard();
  final violations = <String>[];

  final libRoot = Directory('lib');
  final files = libRoot
      .listSync(recursive: true, followLinks: false)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  // 归一化为正向斜杠：Windows 下 File.path 用反斜杠，而逻辑路径用 '/'，
  // 否则 _scanLib 会因 realPaths 与实际解析路径分隔符不一致而误跳过全部相对 import（假绿）。
  final realPaths = files.map((f) => f.path.replaceAll(r'\', '/')).toSet();

  for (final f in files) {
    final from = f.path.replaceAll(r'\', '/'); // e.g. "lib/features/.../x.dart"
    // 归一化为 lib/ 相对逻辑路径
    final fromLogical = from.startsWith('lib/') ? from.substring('lib/'.length) : from;
    final fromDir = fromLogical.contains('/') ? fromLogical.substring(0, fromLogical.lastIndexOf('/')) : '';

    final lines = f.readAsLinesSync();
    for (final line in lines) {
      final m = RegExp(r"^\s*(import|export)\s+'([^']+)'").firstMatch(line);
      if (m == null) continue;
      final uri = m.group(2)!;

      String to;
      if (uri.startsWith('package:word_app/')) {
        to = uri.substring('package:word_app/'.length);
      } else if (uri.startsWith('package:') || uri.startsWith('dart:') || uri.startsWith('asset:')) {
        to = uri; // 外部依赖，保留前缀（仅受 R5 领域纯净规则约束）
      } else {
        // 相对 import。
        to = _resolveRelative(fromDir, uri);
        // 解析后应指向 lib 内已存在文件；否则说明 import 无效（由 analyzer 兜底），跳过。
        if (!(_isInsideLib(to) && realPaths.contains('lib/${to.replaceAll(r'\', '/')}'))) {
          continue;
        }
      }

      final result = guard.check(from: fromLogical, to: to);
      if (result.isNotEmpty) {
        violations.addAll(result.map((v) => '  [$fromLogical] $v'));
      }
    }
  }

  return violations;
}

bool _isInsideLib(String logical) => !logical.startsWith('..') && !logical.startsWith('/');

String _resolveRelative(String fromDir, String uri) {
  final parts = uri.split('/');
  final stack = fromDir.isEmpty ? <String>[] : fromDir.split('/').toList();
  for (final p in parts) {
    if (p == '..') {
      if (stack.isNotEmpty) stack.removeLast();
    } else if (p == '.' || p.isEmpty) {
      continue;
    } else {
      stack.add(p);
    }
  }
  return stack.join('/');
}
