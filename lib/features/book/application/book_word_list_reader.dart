import 'package:word_app/models/word.dart';

/// 词书单词列表端口（读）。
///
/// 封装指定词书的单词列表查询逻辑。
abstract class BookWordListReader {
  /// 加载指定词书的【全部】单词（按字母 A-Z 排序）。
  ///
  /// 词书列表页标注的词数必须与返回的列表长度一致（验收标准）。
  /// [bookId] 词书 ID
  ///
  /// MEM/F2：全量加载仅供导出/选书等确需完整数据的场景；列表浏览请改用
  /// [countWords] + [loadWordPage] 分页窗口，整书 Word 不再一次性进内存。
  Future<List<Word>> loadWords(int bookId);

  /// 词书单词总数（SQL COUNT 口径）。
  ///
  /// 分页窗口的总量来源；验收上应与词书标注 wordCount 一致。
  Future<int> countWords(int bookId);

  /// 分页加载单词（lightweight，A-Z 序，与全量排序一致）。
  ///
  /// 列表浏览专用：每次仅取 [limit] 条，滚动临近窗口末尾再取下一页。
  Future<List<Word>> loadWordPage(int bookId, {required int offset, required int limit});

  /// 全书单词文本（单列，A-Z 序）。
  ///
  /// 供统计口径（如已学数按全书计算）瞬时使用，返回值不得长期持有。
  Future<List<String>> loadWordTexts(int bookId);
}
