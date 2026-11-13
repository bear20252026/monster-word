import 'package:word_app/core/repositories/word_repository.dart';
import 'package:word_app/core/utils/swallowed_error_report.dart';
import 'package:word_app/features/dictionary/application/dictionary_search_reader.dart';
import 'package:word_app/models/word.dart';

/// 基于 [WordRepository] 的词典搜索适配器。
///
/// P1-6（架构审计 2026-11-12）：此前本适配器自带一套「前缀 + 全表 LIKE」实现，
/// 与搜索域的 [WordRepository.searchWords]（三层索引 + 中文二元组预筛）构成
/// **同库双栈**——两套语义、两套性能，中文查询在词典侧恒走全表扫描。
/// 现统一委托 [WordRepository.searchWords] 单栈：英文吃 BINARY 索引、中文吃
/// 二元组倒排，词典与搜索域结果口径一致。
///
/// 端口三方法保留（消费方契约不变），语义统一为「智能搜索」：
/// - [searchSmart]：索引路径完整结果（英文优先、中文兜底）。
/// - [searchByPrefix] / [searchFuzzy]：同走索引路径（索引内部已含前缀层与
///   中缀/中文层），不再各自维护一套 SQL。
class ServiceDictionarySearchReader implements DictionarySearchReader {
  ServiceDictionarySearchReader({required this.repository});

  final WordRepository repository;

  @override
  Future<List<Word>> searchByPrefix(String prefix) => _search(prefix, limit: 20);

  @override
  Future<List<Word>> searchFuzzy(String query) => _search(query, limit: 40);

  @override
  Future<List<Word>> searchSmart(String query) => _search(query, limit: 40);

  Future<List<Word>> _search(String query, {required int limit}) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];
    try {
      return await repository.searchWords(trimmed, limit: limit);
    } catch (e, s) {
      reportSwallowedError('DictionarySearchReader 搜索失败', e, s);
      return [];
    }
  }
}
