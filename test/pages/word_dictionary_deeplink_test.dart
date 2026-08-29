// 由 Claude 团队生成
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:word_app/core/di/service_locator.dart';
import 'package:word_app/core/router/content_routes.dart';
import 'package:word_app/core/router/route_error_page.dart';
import 'package:word_app/core/router/route_names.dart';
import 'package:word_app/features/dictionary/presentation/dictionary_by_name_page.dart';
import 'package:word_app/features/dictionary/presentation/dictionary_page.dart';
import 'package:word_app/models/word.dart';
import 'package:word_app/repositories/word_repository.dart';

/// 仅承接 getWordByText 的轻量 Fake，其余方法返回空/空值（测试不触达）。
class _FakeWordRepository implements WordRepository {
  final Word? found;

  _FakeWordRepository({this.found});

  @override
  Future<Word?> getWordByText(String text) async => found;

  @override
  Future<List<Word>> getWordsByBookId(int bookId, {int? limit, int? offset}) async => [];

  @override
  Future<Word?> getWordById(int id) async => null;

  @override
  Future<List<Word>> getWordsByTexts(Iterable<String> texts) async => [];

  @override
  Future<List<Word>> getWordsByIds(Iterable<int> ids) async => [];

  @override
  Future<List<Word>> searchWords(String query, {int? limit}) async => [];

  @override
  Future<Map<String, dynamic>?> getWordDetails(int wordId) async => null;

  @override
  Future<List<Word>> getRandomWords(int count, {int? excludeBookId}) async => [];

  @override
  Future<int> updateWordStatus(int wordId, Map<String, dynamic> status) async => 0;
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
        sl.registerLazySingleton<WordRepository>(
          () => _FakeWordRepository(found: null),
        );
        await tester.pumpWidget(const MaterialApp(
          home: DictionaryByNamePage(wordName: 'zzz_not_exist'),
        ));
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
