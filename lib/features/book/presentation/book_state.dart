import 'dart:async';

import 'package:word_app/core/utils/debug_log.dart';
import 'package:flutter/foundation.dart';

import 'package:word_app/features/learning/application/learning_progress_reader.dart';
import 'package:word_app/models/book.dart';
import 'package:word_app/models/word.dart';
import 'package:word_app/features/book/application/book_catalog_reader.dart';
import 'package:word_app/features/book/application/book_selection_writer.dart';
import 'package:word_app/features/book/application/book_word_list_reader.dart';
import 'package:word_app/features/book/domain/book_statistics.dart';
// 埋点端口（跨 feature 只 import 对方的 application 层，架构守卫 R4 允许）。
import 'package:word_app/features/telemetry/application/usage_stats_ports.dart';

/// 词书模块聚合状态。
///
/// 封装词书目录、当前选中词书、单词列表及学习进度。
/// 通过各端口读取/写入数据，UI 层仅与此状态交互。
class BookState extends ChangeNotifier {
  BookState({
    required BookCatalogReader catalogReader,
    required BookSelectionWriter selectionWriter,
    required BookWordListReader wordsReader,
    required LearningProgressReader progressReader,
    UsageStatsRecorder? usageStats,
  }) : _catalogReader = catalogReader,
       _selectionWriter = selectionWriter,
       _wordsReader = wordsReader,
       _progressReader = progressReader,
       _usageStats = usageStats;
  // ignore_for_file: prefer_initializing_formals

  final BookCatalogReader _catalogReader;
  final BookSelectionWriter _selectionWriter;
  final BookWordListReader _wordsReader;
  final LearningProgressReader _progressReader;

  /// 使用统计埋点端口；未注入（测试/未装配）时为 null，埋点静默跳过。
  final UsageStatsRecorder? _usageStats;

  // ── 词书目录 ──────────────────────────────────────────────
  List<Book> _books = const [];
  List<Book> get books => _books;

  // ── 当前选中词书 ──────────────────────────────────────────
  Book? _currentBook;
  Book? get currentBook => _currentBook;

  int _currentBookId = 0;
  int get currentBookId => _currentBookId;

  // ── 单词列表（MEM/F2：分页窗口，整书 Word 不再一次性进内存） ──────────
  /// 列表浏览窗口页大小。首屏一次加载，滚动临近末尾时经 [loadMore] 续页。
  static const int pageSize = 200;

  List<Word> _words = const [];
  List<Word> get words => _words;

  /// 当前词书单词总数（SQL COUNT 口径；验收上与词书标注 wordCount 一致）。
  int _totalWords = 0;
  int get totalWords => _totalWords;

  /// 窗口之后是否还有更多单词（可继续 [loadMore]）。
  bool _hasMore = false;
  bool get hasMore => _hasMore;

  bool _loadingMore = false;
  bool get loadingMore => _loadingMore;

  BookStatistics? _statistics;
  BookStatistics? get statistics => _statistics;

  // ── 状态标志 ──────────────────────────────────────────────
  // MW-45：请求代际——切换词书时自增；每个异步阶段回来后校验代际与 bookId，
  // 过期响应直接丢弃，杜绝「A 词书的分页串进 B 词书列表」的跨书污染。
  int _bookGeneration = 0;
  @visibleForTesting
  int get debugBookGeneration => _bookGeneration;

  bool _loading = false;
  bool get loading => _loading;

  bool _wordsLoading = false;
  bool get wordsLoading => _wordsLoading;

  String? _error;
  String? get error => _error;

  /// 加载词书目录与当前选中词书。
  ///
  /// MW-45：load 与 selectAndLoad 并发时（词书页 initState 立即 selectAndLoad，
  /// create 同时触发 load），load 的迟到的 currentBookId 不得覆写用户刚选中的
  /// 词书，也不得让在途 loadWords 被误判 stale 而永久停在加载态。
  Future<void> load() async {
    final generation = _bookGeneration;
    final loadingBookId = _currentBookId;
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final books = await _catalogReader.listBooks();
      final selectedId = await _selectionWriter.getCurrentBookId();
      // 期间用户已显式选书（代际推进或 bookId 变化）：本次 load 的持久化选中
      // 结果整体丢弃——目录仍可入缓存，但绝不回写 _currentBook*。
      final stale = generation != _bookGeneration || (_currentBookId != loadingBookId && _currentBookId != selectedId);
      if (!stale) {
        _books = books;
        _currentBookId = selectedId;
        if (_currentBookId > 0) {
          _currentBook = await _catalogReader.findById(_currentBookId);
        }
        // 兜底：若当前词书不在列表中（如已被删除），清除无效 ID
        if (_currentBook != null && !_books.any((b) => b.id == _currentBookId)) {
          _currentBook = null;
          _currentBookId = 0;
        }
      } else {
        _books = books;
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
    // MW-45：代际先行自增——此前在途的旧词书分页/统计响应全部作废。
    _bookGeneration++;
    await _selectionWriter.selectBook(book.id);
    _currentBook = book;
    _currentBookId = book.id;
    notifyListeners();
    await loadWords();
  }

  /// 加载当前词书的单词列表（MEM/F2：总量 COUNT + 首页窗口 + 全书已学统计）。
  ///
  /// MW-45：每个 await 后校验代际 + bookId，切换词书后的过期响应整体丢弃
  /// （不写 _words/_totalWords/_statistics 任何一个字段）。
  Future<void> loadWords() async {
    if (_currentBookId == 0) return;
    final generation = _bookGeneration;
    final bookId = _currentBookId;
    final book = _currentBook;
    _wordsLoading = true;
    notifyListeners();

    try {
      final total = await _wordsReader.countWords(bookId);
      if (_stale(generation, bookId)) return;
      // 验收守护：词书标注词数必须与实际总数一致，不一致立即暴露
      final expected = book?.wordCount ?? 0;
      if (expected > 0 && total != expected) {
        debugLog('[BookState] 词数不一致! book=$bookId 标注=$expected 实载=$total');
      }
      final page = await _wordsReader.loadWordPage(bookId, offset: 0, limit: BookState.pageSize);
      if (_stale(generation, bookId)) return;
      _totalWords = total;
      _words = page;
      _hasMore = _words.length < _totalWords;
      // 通过 learning 模块提供的契约读取真实已学数（全书口径：单列文本瞬时查询）
      final learned = await _progressReader.countLearnedWords(await _wordsReader.loadWordTexts(bookId));
      if (_stale(generation, bookId)) return;
      final statistics = BookStatistics(
        // 优先使用词书自身的 wordCount；若缺失则回退到 COUNT 查询总数
        totalWords: expected > 0 ? expected : _totalWords,
        learnedWords: learned,
      );
      _statistics = statistics;
      // 使用统计：词书进度是**状态量**，覆盖写（见 UsageStatsRecorder.syncBookProgress）。
      // 这里是全库唯一算出「该词书已学/总量」的地方，故埋点也放这里，避免第二套口径。
      final recorder = _usageStats;
      if (recorder != null) {
        unawaited(recorder.syncBookProgress(wordCount: statistics.totalWords, learned: statistics.learnedWords));
      }
      _error = null;
    } catch (e) {
      if (_stale(generation, bookId)) return;
      _words = const [];
      _totalWords = 0;
      _hasMore = false;
      _error = e.toString(); // 向 UI 层反馈错误，避免静默失败
    } finally {
      if (!_stale(generation, bookId)) {
        _wordsLoading = false;
      }
      notifyListeners();
    }
  }

  /// MW-45：代际或词书 ID 已变化 = 本请求已过期。
  bool _stale(int generation, int bookId) => generation != _bookGeneration || bookId != _currentBookId;

  /// 加载下一页窗口（无限滚动）。加载中/无更多/首屏加载中时为 no-op，可安全重复触发。
  ///
  /// MW-45：捕获发起时的 bookId/offset/代际三元组，响应回来三者全部仍匹配
  /// 才允许 append——旧词书的分页响应绝不污染新词书列表。
  Future<void> loadMore() async {
    if (!_hasMore || _loadingMore || _wordsLoading || _currentBookId == 0) return;
    final generation = _bookGeneration;
    final bookId = _currentBookId;
    final expectedOffset = _words.length;
    _loadingMore = true;
    notifyListeners();

    try {
      final page = await _wordsReader.loadWordPage(bookId, offset: expectedOffset, limit: BookState.pageSize);
      // 过期响应：词书已切换或列表已重建（代际变）或 offset 已被他人推进。
      if (_stale(generation, bookId) || _words.length != expectedOffset) return;
      if (page.isNotEmpty) {
        _words = [..._words, ...page];
      }
      // 未取满一页即到底；空页同样收敛，避免异常数据下死循环请求
      _hasMore = page.length >= BookState.pageSize;
    } catch (e) {
      if (!_stale(generation, bookId)) {
        _error = e.toString();
      }
    } finally {
      if (!_stale(generation, bookId)) {
        _loadingMore = false;
      }
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
    _totalWords = words.length;
    _hasMore = false;
    notifyListeners();
  }
}
