// 搜索功能域 · 例句解析适配器。
//
// 将 lib/data/example_parser.dart 的解析逻辑封装为 application 端口实现。
// 页面通过 ExampleReader 端口访问，不直连旧 data 层。

import '../../../data/example_parser.dart' as legacy;
import '../application/example_reader.dart';
import '../domain/search_example.dart';

/// 将旧 ExampleParser 适配为 ExampleReader 端口。
class ExampleParserAdapter implements ExampleReader {
  const ExampleParserAdapter();

  @override
  List<SearchExample> parse(String raw) {
    final legacyExamples = legacy.ExampleParser.parse(raw);
    return legacyExamples.map((e) => SearchExample(
      en: e.en,
      cn: e.cn,
      source: e.source,
      audioUrl: e.audioUrl,
    )).toList();
  }
}
