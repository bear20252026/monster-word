import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:word_app/core/utils/swallowed_error_report.dart';
import 'package:word_app/features/learning/application/mastered_words_reader.dart';
import 'package:word_app/features/learning/application/mastered_writer_port.dart';

/// 手动掌握标记的读取与操作状态。
///
/// 读取通过 [MasteredWordsReader]，写入命令通过 [MasteredWriterPort] 委托给掌握仓库适配器，以保持
/// `mastered_words_v1` 的字符串身份和已有用户数据兼容。该状态仅提供页面可订阅的掌握词集合与切换结果。
class LearningMasteredState extends ChangeNotifier {
  LearningMasteredState({required this._masteredWordsReader, required this._writerPort}) {
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
    } catch (e, s) {
      // 构造期 unawaited(refresh()) 的兜底：读库异常不能进 unhandled，
      // 降级为空集合（掌握徽标不显示，重进页面可重试）。
      reportSwallowedError('掌握词集合加载失败', e, s);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> toggle(String word) async {
    try {
      await _writerPort.toggleMastered(word);
      _masteredWords = (await _masteredWordsReader.loadTexts()).toSet();
    } catch (e, s) {
      // 调用方为 fire-and-forget：写库失败在此接住上报，返回旧状态。
      reportSwallowedError('掌握标记写入失败', e, s);
      notifyListeners();
      return _masteredWords.contains(word);
    }
    notifyListeners();
    return _masteredWords.contains(word);
  }
}
