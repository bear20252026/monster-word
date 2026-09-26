// 单词浏览页 FlowIn 有序流动入场复用测试（与 lib_select_page 同一动效语言）
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:word_app/core/application/wordbook_maintenance_service.dart';
import 'package:word_app/features/book/application/book_catalog_reader.dart';
import 'package:word_app/features/book/application/book_selection_writer.dart';
import 'package:word_app/features/book/application/book_word_list_reader.dart';
import 'package:word_app/features/book/presentation/book_state.dart';
import 'package:word_app/features/book/presentation/book_words_page.dart';
import 'package:word_app/features/learning/application/learning_favorites_store.dart';
import 'package:word_app/features/learning/application/new_words_store.dart';
import 'package:word_app/models/book.dart';
import 'package:word_app/models/word.dart';
import 'package:word_app/widgets/flow_in.dart';

import '../test_helpers/fake_learning_progress_reader.dart';

/// 模拟 BookCatalogReader
class MockCatalogReader implements BookCatalogReader {
  @override
  Future<List<Book>> listBooks() async => [];

  @override
  Future<Book?> findById(int bookId) async => null;
}

/// 模拟 BookSelectionWriter
class MockSelectionWriter implements BookSelectionWriter {
  @override
  Future<int> getCurrentBookId() async => 0;

  @override
  Future<Book?> getCurrentBook() async => null;

  @override
  Future<void> selectBook(int bookId) async {}
}

/// 按词书返回窗口的模拟 BookWordListReader
class MockWordsReader implements BookWordListReader {
  MockWordsReader(this._wordsByBook);

  final Map<int, List<Word>> _wordsByBook;

  @override
  Future<List<Word>> loadWords(int bookId, {int limit = 50, int offset = 0}) async =>
      (_wordsByBook[bookId] ?? []).skip(offset).take(limit).toList();

  @override
  Future<int> countWords(int bookId) async => (_wordsByBook[bookId] ?? []).length;

  @override
  Future<List<Word>> loadWordPage(int bookId, {required int offset, required int limit}) async =>
      (_wordsByBook[bookId] ?? []).skip(offset).take(limit).toList();

  @override
  Future<List<String>> loadWordTexts(int bookId) async => (_wordsByBook[bookId] ?? []).map((w) => w.word).toList();
}

/// 收藏 store 契约的内存 fake（_WordCard watch 必需）
class _FakeFavoritesStore extends LearningFavoritesStore {
  final Set<String> _favs = {};

  @override
  Set<String> get favoriteWords => Set.unmodifiable(_favs);
  @override
  int get favoriteCount => _favs.length;
  @override
  bool get isLoading => false;
  @override
  bool isFavorite(String word) => _favs.contains(word);
  @override
  Future<void> refresh() async {}
  @override
  Future<bool> toggle(String word) async {
    if (!_favs.remove(word)) _favs.add(word);
    return _favs.contains(word);
  }

  @override
  Future<List<Word>> loadFavoriteWords({required Iterable<Word> currentQueue}) async => [];
}

/// 生词本 store 契约的内存 fake（_WordCard watch 必需）
class _FakeNewWordsStore extends NewWordsStore {
  final Set<int> _ids = {};

  @override
  bool get initialized => true;
  @override
  int get count => _ids.length;
  @override
  bool isNewWord(int wordId) => _ids.contains(wordId);
  @override
  Future<void> initialize() async {}
  @override
  Future<void> toggleNewWord(Word word, {String source = 'manual'}) async {
    if (!_ids.remove(word.id)) _ids.add(word.id);
  }
}

Widget _host(Book book, BookState bookState, {bool disableAnimations = false}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: disableAnimations),
      child: MultiProvider(
        providers: [
          Provider<BookCatalogReader>.value(value: MockCatalogReader()),
          Provider<BookSelectionWriter>.value(value: MockSelectionWriter()),
          Provider<WordBookMaintenanceService>.value(value: const WordBookMaintenanceService()),
          ChangeNotifierProvider<LearningFavoritesStore>.value(value: _FakeFavoritesStore()),
          ChangeNotifierProvider<NewWordsStore>.value(value: _FakeNewWordsStore()),
          ChangeNotifierProvider<BookState>.value(value: bookState),
        ],
        child: BookWordsPage(book: book),
      ),
    ),
  );
}

Finder _rowOpacity(int wordId) =>
    find.descendant(of: find.byKey(ValueKey('word-flow-$wordId')), matching: find.byType(Opacity));

Book _book(int id, int wordCount) => Book(id: id, code: 'b$id', name: '词书 $id', wordCount: wordCount);

void main() {
  testWidgets('词行按索引波次入场：靠后的行起跑更晚，最终完全呈现', (tester) async {
    final bookState = BookState(
      catalogReader: MockCatalogReader(),
      selectionWriter: MockSelectionWriter(),
      wordsReader: MockWordsReader({
        1: [Word(id: 1, word: 'apple'), Word(id: 2, word: 'banana'), Word(id: 3, word: 'cherry')],
      }),
      progressReader: FakeLearningProgressReader(),
    );
    await bookState.load();

    await tester.pumpWidget(_host(_book(1, 3), bookState));
    // frame0: 目录加载中 → postFrame selectAndLoad → 词表窗口就绪
    await tester.pump();
    await tester.pump();
    await tester.pump();

    // 入场起点：各行均不可见（波次尚未起跑）
    expect(tester.widget<Opacity>(_rowOpacity(1)).opacity, lessThan(0.05));
    expect(tester.widget<Opacity>(_rowOpacity(3)).opacity, lessThan(0.05));

    // 120ms：第 1 行已起步，第 3 行（波次 2，70ms 起跑）刚开始
    await tester.pump(const Duration(milliseconds: 120));
    final first = tester.widget<Opacity>(_rowOpacity(1)).opacity;
    final third = tester.widget<Opacity>(_rowOpacity(3)).opacity;
    expect(first, greaterThan(third));
    expect(third, greaterThan(0));

    await tester.pumpAndSettle();
    expect(tester.widget<Opacity>(_rowOpacity(3)).opacity, 1.0);
    expect(find.text('cherry'), findsOneWidget);
  });

  testWidgets('切换词书时整列重放入场波次', (tester) async {
    final bookState = BookState(
      catalogReader: MockCatalogReader(),
      selectionWriter: MockSelectionWriter(),
      wordsReader: MockWordsReader({
        1: [Word(id: 1, word: 'apple'), Word(id: 2, word: 'banana')],
        2: [Word(id: 4, word: 'date'), Word(id: 5, word: 'fig')],
      }),
      progressReader: FakeLearningProgressReader(),
    );
    await bookState.load();

    final book1 = _book(1, 2);
    await tester.pumpWidget(_host(book1, bookState));
    await tester.pump();
    await tester.pump();
    await tester.pump();
    await tester.pumpAndSettle();
    expect(tester.widget<Opacity>(_rowOpacity(1)).opacity, 1.0);

    // 同一 BookState 下换书：词 id 全换 → FlowIn 重建 → 波次重放
    await tester.pumpWidget(_host(_book(2, 2), bookState));
    await tester.pump();
    await tester.pump();
    await tester.pump();
    expect(find.text('fig'), findsOneWidget);
    expect(tester.widget<Opacity>(_rowOpacity(4)).opacity, lessThan(0.05));

    await tester.pumpAndSettle();
    expect(tester.widget<Opacity>(_rowOpacity(4)).opacity, 1.0);
  });

  testWidgets('减弱动态效果时词行直接呈现最终态', (tester) async {
    final bookState = BookState(
      catalogReader: MockCatalogReader(),
      selectionWriter: MockSelectionWriter(),
      wordsReader: MockWordsReader({
        1: [Word(id: 1, word: 'apple'), Word(id: 2, word: 'banana')],
      }),
      progressReader: FakeLearningProgressReader(),
    );
    await bookState.load();

    await tester.pumpWidget(_host(_book(1, 2), bookState, disableAnimations: true));
    await tester.pump();
    await tester.pump();
    await tester.pump();

    // FlowIn 在 disableAnimations 下不包 Opacity/Transform，直接给最终态
    expect(find.text('apple'), findsOneWidget);
    expect(find.byType(Opacity), findsNothing);
    expect(tester.widget<FlowIn>(find.byKey(const ValueKey('word-flow-1'))), isNotNull);
  });
}
