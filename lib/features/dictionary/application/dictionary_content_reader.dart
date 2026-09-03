import 'package:word_app/core/parsers/example_parser.dart';
import 'package:word_app/models/word.dart';

/// 词典内容页所需的只读查询端口。
abstract interface class DictionaryContentReader {
  Future<List<Word>> getDerivedWords(String word);

  Future<List<Word>> getSynonyms(String word);

  /// 词库例句（word.example JSON，经 [ExampleParser] 解析为统一结构）。
  ///
  /// 返回 core [ExampleSentence]：单一事实来源，UI 层直接复用 [ExampleTile] 渲染，
  /// 不再经 feature 域模型二次映射（v2.7.45 收口，修复裸 JSON 渲染乱码）。
  Future<List<ExampleSentence>> getExamExamples(String word);

  /// 真题例句（dictionary_extra.json 扩展数据，带 CET-4/CET-6/考研等来源标注）。
  /// 返回 {'sentence': 句子, 'source': 来源}。
  Future<List<Map<String, String>>> getRealExamSentences(String word);
}
