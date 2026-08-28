import 'package:flutter/foundation.dart';

import '../../../core/learning/learning_progress_reader.dart';
import '../../../models/book.dart';
import '../../../models/word.dart';
import '../application/book_catalog_reader.dart';
import '../application/book_selection_writer.dart';
import '../application/book_words_reader.dart';
import '../domain/book_statistics.dart';

/// 词书模块聚合状态。
///
/// 封装词书目录、当前选中词书、单词列表及学习进度。
/// 通过各端口读取/写入数据，UI 层仅与此状态交互。
class BookState extends ChangeNotifier {
  BookState({
    required BookCatalogReader catalogReader,
    required BookSelectionWriter selectionWriter,
    required BookWordsReader wordsReader,
    required LearningProgressReader progressReader,
  })  : _catalogReader = catalogReader,
        _selectionWriter = selectionWriter,
        _wordsReader = wordsReader,
        _progressReader = progressReader;
  // ignore_for_file: prefer_initializing_formals

  final BookCatalogReader _catalogReader;
  final BookSelectionWriter _selectionWriter;
  final BookWordsReader _wordsReader;
  final LearningProgressReader _progressReader;

  // ── 词书目录 ──────────────────────────────────────────────
  List<Book> _books = const [];
  List<Book> get books => _books;

  // ── 当前选中词书 ──────────────────────────────────────────
  Book? _currentBook;
  Book? get currentBook => _currentBook;

  int _currentBookId = 0;
  int get currentBookId => _currentBookId;

  // ── 单词列表 ──────────────────────────────────────────────
  List<Word> _words = const [];
  List<Word> get words => _words;

  BookStatistics? _statistics;
  BookStatistics? get statistics => _statistics;

  // ── 状态标志 ──────────────────────────────────────────────
  bool _loading = false;
  bool get loading => _loading;

  bool _wordsLoading = false;
  bool get wordsLoading => _wordsLoading;

  String? _error;
  String? get error => _error;

  /// 加载词书目录与当前选中词书。
  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      _books = await _catalogReader.listBooks();
      _currentBookId = await _selectionWriter.getCurrentBookId();
      if (_currentBookId > 0) {
        _currentBook = await _catalogReader.findById(_currentBookId);
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// 选中一本词书并加载其单词。
  Future<void> selectAndLoad(Book book) async {
    await _selectionWriter.selectBook(book.id);
    _currentBook = book;
    _currentBookId = book.id;
    notifyListeners();
    await loadWords();
  }

  /// 加载当前词书的单词列表。
  Future<void> loadWords() async {
    if (_currentBookId == 0) return;
    _wordsLoading = true;
    notifyListeners();

    try {
      _words = await _wordsReader.loadWords(_currentBookId);
      // 通过 learning 模块提供的契约读取真实已学数
      final learned = await _progressReader.countLearnedWords(_words.map((w) => w.word));
      _statistics = BookStatistics(
        totalWords: _currentBook?.wordCount ?? _words.length,
        learnedWords: learned,
      );
    } catch (e) {
      _words = const [];
    } finally {
      _wordsLoading = false;
      notifyListeners();
    }
  }

  /// 重新加载单词（用于收藏/生词等操作后刷新）。
  Future<void> reloadWords() => loadWords();

  /// 测试用：注入单词列表（绕过真实数据加载）。
  @visibleForTesting
  void setWordsForTest(List<Word> words) {
    _words = words;
    _currentBookId = 1;
    notifyListeners();
  }
}
