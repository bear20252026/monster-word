// 搜索功能域 · 例句解析端口。
//
// 页面只读取此端口；具体解析由 data 层适配器实现。

import '../domain/search_example.dart';

/// 从词库原始 JSON 字符串中提取结构化例句。
abstract interface class ExampleReader {
  /// 解析原始 example JSON，返回结构化例句列表。
  List<SearchExample> parse(String raw);
}
