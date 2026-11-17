import 'package:flutter/foundation.dart';

import 'package:word_app/core/application/restore_cache_reset.dart';
import 'package:word_app/features/learning/application/new_words_store.dart';
import 'package:word_app/models/word.dart';
import 'package:word_app/features/learning/application/new_words_reader.dart';
import 'package:word_app/features/learning/application/new_words_writer_port.dart';

/// 生词本的可观察展示状态。
///
/// 该状态只协调界面展示和用户操作；读取通过 [NewWordsReader]，持久化写入事实由 [NewWordsWriterPort] 管理。
class NewWordsState extends ChangeNotifier implements NewWordsStore {
  NewWordsState({required this._newWordsReader, required this._writerPort}) {
    // 第四轮审计 M18（2026-11-17）：备份恢复后重读生词集合（仓储句柄与
    // 共享 ID 缓存已由库关闭广播复位）。
    RestoreCacheResetBus.register(reloadForRestore);
  }

  @override
  void dispose() {
    RestoreCacheResetBus.unregister(reloadForRestore);
    super.dispose();
  }

  final NewWordsReader _newWordsReader;
  final NewWordsWriterPort _writerPort;
  final Set<int> _wordIds = {};
  Future<void>? _initialization;
  bool _initialized = false;

  /// 恢复后强制重载：清单飞 future 让 initialize 语义重新可用。
  Future<void> reloadForRestore() async {
    _initialization = null;
    _initialized = false;
    await initialize();
  }

  @override
  bool get initialized => _initialized;
  @override
  int get count => _wordIds.length;

  @override
  bool isNewWord(int wordId) => _wordIds.contains(wordId);

  @override
  Future<void> initialize() {
    return _initialization ??= _loadInitialRecords();
  }

  Future<void> _loadInitialRecords() async {
    final words = await _newWordsReader.loadWords();
    _wordIds
      ..clear()
      ..addAll(words.map((word) => word.id));
    _initialized = true;
    notifyListeners();
  }

  @override
  Future<bool> toggleNewWord(Word word, {String source = 'manual'}) async {
    await initialize();
    final isAdded = await _writerPort.toggleNewWord(word, source: source);
    if (isAdded) {
      _wordIds.add(word.id);
    } else {
      _wordIds.remove(word.id);
    }
    notifyListeners();
    return isAdded;
  }

  Future<bool> removeNewWord(Word word) async {
    await initialize();
    final wasRemoved = await _writerPort.removeNewWord(word.id);
    if (wasRemoved) {
      _wordIds.remove(word.id);
      notifyListeners();
    }
    return wasRemoved;
  }
}
