import 'package:word_app/core/infrastructure/wordbook_database.dart';
import 'package:word_app/core/parsers/example_parser.dart';
import 'package:word_app/features/dictionary/application/dictionary_content_reader.dart';
import 'package:word_app/features/dictionary/data/dictionary_extra.dart';

/// 基于 WordBookDatabase 的字典内容查询适配器。
///
/// 实现 [DictionaryContentReader] 端口，封装派生词、近义词、例句与真题例句查询。
/// 直接访问数据库，不经过 [DictionaryService] 中间层。
class ServiceDictionaryContentReader implements DictionaryContentReader {
  ServiceDictionaryContentReader({this._database});

  final WordBookDatabase? _database;

  WordBookDatabase get _db => _database ?? WordBookDatabase.instance;

  @override
  Future<List<Word>> getDerivedWords(String word) async {
    if (word.trim().isEmpty) return [];
    final rows = await _db.db.query(
      'words',
      where: 'main_word = ? AND word != ?',
      whereArgs: [word, word],
      orderBy: 'word',
    );
    return rows.map(Word.fromMap).toList();
  }

  @override
  Future<List<Word>> getSynonyms(String word) async {
    if (word.trim().isEmpty) return [];
    final wordData = await _db.getWord(word);
    if (wordData == null || wordData.confuse.isEmpty) return [];

    final synonyms = wordData.confuse.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    if (synonyms.isEmpty) return [];

    // 性能审计 P3：循环内逐词查询（N+1）改单次批量查询
    return _db.getWordsByNames(synonyms.toSet());
  }

  @override
  Future<List<ExampleSentence>> getExamExamples(String word) async {
    if (word.trim().isEmpty) return [];
    final wordData = await _db.getWord(word);
    if (wordData == null || wordData.example.isEmpty) return [];

    // 根因修复（v2.7.45）：word.example 是结构化 JSON（{"v":1,"data":[...] }），
    // 旧实现 split('\n') 按行当纯文本塞进例句列表——详情页整段裸 JSON 渲染（乱码）。
    // 统一走 [ExampleParser] 单一事实来源（与学习页/导出页一致），
    // 解析失败时返回空列表而非渲染原文。
    return ExampleParser.parse(wordData.example);
  }

  @override
  Future<List<Map<String, String>>> getRealExamSentences(String word) async {
    if (word.trim().isEmpty) return [];
    final extra = await DictionaryExtraStore.forWord(word);
    if (extra == null) return [];
    return extra.examSentences.map((s) => {'sentence': s.sentence, 'source': s.source}).toList();
  }

  @override
  Future<List<CollinsSense>> getCollinsSenses(String word) async {
    if (word.trim().isEmpty) return [];
    final wordData = await _db.getWord(word);
    if (wordData == null || wordData.example.isEmpty) return [];
    return ExampleParser.parseCollins(wordData.example);
  }
}
