import 'dart:async';

import 'package:flutter/foundation.dart';

import '../application/mastered_words_reader.dart';
import '../application/mastered_writer_port.dart';

/// 手动掌握标记的读取与操作状态。
///
/// 读取通过 [MasteredWordsReader]，写入命令通过 [MasteredWriterPort] 委托给掌握仓库适配器，以保持
/// `mastered_words_v1` 的字符串身份和已有用户数据兼容。该状态仅提供页面可订阅的掌握词集合与切换结果。
class LearningMasteredState extends ChangeNotifier {
  LearningMasteredState({
    required this._masteredWordsReader,
    required this._writerPort,
  }) {
    unawaited(refresh());
  }

  final MasteredWordsReader _masteredWordsReader;
  final MasteredWriterPort _writerPort;

  Set<String> _masteredWords = const {};
  bool _isLoading = true;

  Set<String> get masteredWords => Set.unmodifiable(_masteredWords);
  int get masteredCount => _masteredWords.length;
  bool get isLoading => _isLoading;

  bool isMastered(String word) => _masteredWords.contains(word);

  Future<void> refresh() async {
    _isLoading = true;
    notifyListeners();
    try {
      _masteredWords = (await _masteredWordsReader.loadTexts()).toSet();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> toggle(String word) async {
    await _writerPort.toggleMastered(word);
    _masteredWords = (await _masteredWordsReader.loadTexts()).toSet();
    notifyListeners();
    return _masteredWords.contains(word);
  }
}
