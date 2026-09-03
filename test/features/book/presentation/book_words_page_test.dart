import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:word_app/features/book/application/book_catalog_reader.dart';
import 'package:word_app/features/book/application/book_selection_writer.dart';
import 'package:word_app/features/book/application/book_word_list_reader.dart';
import 'package:word_app/features/book/presentation/book_state.dart';
import 'package:word_app/features/book/presentation/book_words_page.dart';
import 'package:word_app/models/book.dart';
import 'package:word_app/models/word.dart';
import 'package:word_app/core/application/wordbook_maintenance_service.dart';

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

/// 模拟 BookWordListReader
class MockWordsReader implements BookWordListReader {
  @override
  Future<List<Word>> loadWords(int bookId, {int limit = 50, int offset = 0}) async => [];
}

void main() {
  testWidgets('BookWordsPage 渲染不崩溃', (tester) async {
    final book = Book(id: 1, code: 'cet4', name: 'CET-4', wordCount: 4000);

    await tester.pumpWidget(
      MaterialApp(
        home: MultiProvider(
          providers: [
            Provider<BookCatalogReader>.value(value: MockCatalogReader()),
            Provider<BookSelectionWriter>.value(value: MockSelectionWriter()),
            Provider<BookWordListReader>.value(value: MockWordsReader()),
            Provider<WordBookMaintenanceService>.value(value: const WordBookMaintenanceService()),

            ChangeNotifierProvider<BookState>(
              create: (context) => BookState(
                catalogReader: context.read<BookCatalogReader>(),
                selectionWriter: context.read<BookSelectionWriter>(),
                wordsReader: context.read<BookWordListReader>(),
                progressReader: FakeLearningProgressReader(),
              )..load(),
            ),
          ],
          child: BookWordsPage(book: book),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // 验证页面渲染成功
    expect(find.byType(BookWordsPage), findsOneWidget);
  });
}
