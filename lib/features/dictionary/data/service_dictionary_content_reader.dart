import '../../../models/word.dart';
import '../../../services/dictionary_service.dart';
import '../application/dictionary_content_reader.dart';

/// 基于既有 DictionaryService 的字典内容查询适配器。
class ServiceDictionaryContentReader implements DictionaryContentReader {
  ServiceDictionaryContentReader({required DictionaryService service}) : _service = service;

  final DictionaryService _service;

  @override
  Future<List<Word>> getDerivedWords(String word) => _service.getDerivedWords(word);

  @override
  Future<List<Word>> getSynonyms(String word) => _service.getSynonyms(word);

  @override
  Future<List<Map<String, String>>> getExamExamples(String word) => _service.getExamExamples(word);
}
