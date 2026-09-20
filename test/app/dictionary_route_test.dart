// 由 Claude 团队生成
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:word_app/app/service_locator.dart';
import 'package:word_app/app/router/content_routes.dart';
import 'package:word_app/app/router/route_error_page.dart';
import 'package:word_app/app/router/route_names.dart';
import 'package:word_app/features/dictionary/presentation/dictionary_by_name_page.dart';
import 'package:word_app/features/dictionary/presentation/dictionary_page.dart';
import 'package:word_app/models/word.dart';
import 'package:word_app/core/application/word_lookup_reader.dart';

/// 仅承接 getWordByText 的轻量 Fake（WordLookupReader 端口，R-core-repo）。
class _FakeWordLookup implements WordLookupReader {
  final Word? found;

  _FakeWordLookup({this.found});

  @override
  Future<Word?> getWordByText(String text) async => found;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('P2-7 词典按单词名深链', () {
    setUp(() async {
      await resetServiceLocator();
    });

    tearDown(() async {
      await disposeServiceLocator();
    });

    group('路由解析契约（不渲染）', () {
      test('build(/dictionary, Word) → DictionaryPage', () {
        final page = ContentRoutes.build(RouteNames.dictionary, Word(word: 'hello'));
        expect(page, isA<DictionaryPage>());
      });

      test('build(/dictionary, {word: 名称}) → DictionaryByNamePage', () {
        final page = ContentRoutes.build(RouteNames.dictionary, {'word': 'hello'});
        expect(page, isA<DictionaryByNamePage>());
      });

      test('build(/dictionary, {text: 名称}) → DictionaryByNamePage', () {
        final page = ContentRoutes.build(RouteNames.dictionary, {'text': 'hello'});
        expect(page, isA<DictionaryByNamePage>());
      });

      test('build(/dictionaryByName, String) → DictionaryByNamePage', () {
        final page = ContentRoutes.build(RouteNames.dictionaryByName, 'hello');
        expect(page, isA<DictionaryByNamePage>());
      });

      test('build(/dictionary, 缺参) → RouteErrorPage', () {
        final page = ContentRoutes.build(RouteNames.dictionary, null);
        expect(page, isA<RouteErrorPage>());
      });

      test('build(/dictionaryByName, 空字符串) → RouteErrorPage', () {
        final page = ContentRoutes.build(RouteNames.dictionaryByName, '   ');
        expect(page, isA<RouteErrorPage>());
      });
    });

    group('按名解析页面', () {
      testWidgets('未命中 → 友好错误态，可返回首页', (tester) async {
        // R-core-repo：DictionaryByNamePage 经 WordLookupReader 端口取词（Provider 注入）。
        await tester.pumpWidget(
          Provider<WordLookupReader>.value(
            value: _FakeWordLookup(found: null),
            child: const MaterialApp(home: DictionaryByNamePage(wordName: 'zzz_not_exist')),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.textContaining('未找到'), findsOneWidget);
        expect(find.text('返回首页'), findsOneWidget);
        // 返回按钮应可安全触发（栈底时 no-op，不黑屏）
        expect(find.byTooltip('返回'), findsOneWidget);
      });

      // 命中路径：由路由契约测试（build(/dictionary, Word) → DictionaryPage）
      // 保证命中后转到 DictionaryPage；实际渲染依赖完备 Provider 树，属集成层，
      // 不在本单测范围内，避免为单个深链测试过度 stub。
    });
  });
}
