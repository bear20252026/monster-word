// 词书图鉴 demo：20 词各一兽、无词书提示、加载失败兜底、稀有度图例。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:word_app/features/book/application/book_catalog_reader.dart';
import 'package:word_app/features/book/application/book_selection_writer.dart';
import 'package:word_app/features/book/application/book_word_list_reader.dart';
import 'package:word_app/features/book/presentation/book_state.dart';
import 'package:word_app/features/book/presentation/memory_beast_gallery_page.dart';
import 'package:word_app/models/book.dart';
import 'package:word_app/models/word.dart';
import 'package:word_app/theme/skin_system.dart';
import 'package:word_app/widgets/memory_beast_icon.dart';

import '../test_helpers/fake_learning_progress_reader.dart';

class _Catalog implements BookCatalogReader {
  _Catalog(this.book);
  final Book? book;

  @override
  Future<List<Book>> listBooks() async => book == null ? [] : [book!];

  @override
  Future<Book?> findById(int bookId) async => book;
}

class _Selection implements BookSelectionWriter {
  _Selection(this.bookId);
  final int bookId;

  @override
  Future<int> getCurrentBookId() async => bookId;

  @override
  Future<Book?> getCurrentBook() async => null;

  @override
  Future<void> selectBook(int bookId) async {}
}

class _Words implements BookWordListReader {
  _Words(this.words, {this.boom = false});
  final List<Word> words;
  final bool boom;

  @override
  Future<List<Word>> loadWords(int bookId) async => words;

  @override
  Future<int> countWords(int bookId) async => words.length;

  @override
  Future<List<Word>> loadWordPage(int bookId, {required int offset, required int limit}) async {
    if (boom) throw StateError('db closed');
    return words.skip(offset).take(limit).toList();
  }

  @override
  Future<List<String>> loadWordTexts(int bookId) async => words.map((w) => w.word).toList();
}

Word _word(String text, String pos) => Word(word: text, interpret: '[{"t":"$pos","def":[{"cn":"释义"}]}]');

/// 20 个词：覆盖短/中/长与四种词性。
List<Word> _twentyWords() => [
  _word('cat', 'n.'),
  _word('run', 'vi.'),
  _word('happy', 'adj.'),
  _word('quickly', 'adv.'),
  _word('book', 'n.'),
  _word('jump', 'vt.'),
  _word('bright', 'adj.'),
  _word('slowly', 'adv.'),
  _word('apple', 'n.'),
  _word('write', 'vt.'),
  _word('gentle', 'adj.'),
  _word('happily', 'adv.'),
  _word('elephant', 'n.'),
  _word('understand', 'vt.'),
  _word('beautiful', 'adj.'),
  _word('carefully', 'adv.'),
  _word('mountain', 'n.'),
  _word('remember', 'vt.'),
  _word('important', 'adj.'),
  _word('unfortunately', 'adv.'),
];

Future<BookState> _state({required int bookId, List<Word>? words, bool boom = false}) async {
  final book = bookId > 0 ? Book(id: bookId, code: 'b$bookId', name: '测试词书', wordCount: 20) : null;
  final state = BookState(
    catalogReader: _Catalog(book),
    selectionWriter: _Selection(bookId),
    wordsReader: _Words(words ?? _twentyWords(), boom: boom),
    progressReader: FakeLearningProgressReader(),
  );
  await state.load();
  return state;
}

Widget _wrap(BookState state, BookWordListReader reader) {
  return SkinProvider(
    skin: SkinSystem(),
    child: MultiProvider(
      providers: [
        ChangeNotifierProvider<BookState>.value(value: state),
        Provider<BookWordListReader>.value(value: reader),
      ],
      child: const MaterialApp(home: MemoryBeastGalleryPage()),
    ),
  );
}

void main() {
  testWidgets('20 词各生成一只记忆兽，词与属性签可见', (tester) async {
    final reader = _Words(_twentyWords());
    final state = await _state(bookId: 1);
    await tester.pumpWidget(_wrap(state, reader));
    await tester.pumpAndSettle();

    expect(find.byType(MemoryBeastIcon), findsNWidgets(20));
    expect(find.text('cat'), findsOneWidget);
    expect(find.text('unfortunately'), findsOneWidget);
    // 属性签：小巧·圆耳·常见（cat 是名词短词）。
    expect(find.textContaining('圆耳'), findsWidgets);
    // 稀有度图例三档齐全。
    expect(find.text('常见'), findsWidgets);
    expect(find.text('少见'), findsWidgets);
    expect(find.text('稀有'), findsWidgets);
  });

  testWidgets('词书不足 20 词：有几只画几只', (tester) async {
    final reader = _Words(_twentyWords().take(3).toList());
    final state = await _state(bookId: 1, words: _twentyWords().take(3).toList());
    await tester.pumpWidget(_wrap(state, reader));
    await tester.pumpAndSettle();

    expect(find.byType(MemoryBeastIcon), findsNWidgets(3));
  });

  testWidgets('未选词书：给栖息地提示，不白屏', (tester) async {
    final reader = _Words(const []);
    final state = await _state(bookId: 0);
    await tester.pumpWidget(_wrap(state, reader));
    await tester.pumpAndSettle();

    expect(find.textContaining('栖息地'), findsOneWidget);
    expect(find.byType(MemoryBeastIcon), findsNothing);
  });

  testWidgets('加载失败：可见兜底文案，不静默', (tester) async {
    final reader = _Words(_twentyWords(), boom: true);
    final state = await _state(bookId: 1);
    await tester.pumpWidget(_wrap(state, reader));
    await tester.pumpAndSettle();

    expect(find.textContaining('还没醒'), findsOneWidget);
    expect(find.byType(MemoryBeastIcon), findsNothing);
  });
}
