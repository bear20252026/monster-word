import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../../services/dictionary_service.dart';
import '../application/dictionary_content_reader.dart';
import '../data/service_dictionary_content_reader.dart';

/// 装配字典内容查询功能域。
Widget buildDictionaryFeatureScope({required Widget child}) {
  return Provider<DictionaryContentReader>(
    create: (_) => ServiceDictionaryContentReader(service: DictionaryService.instance),
    child: child,
  );
}
