import 'package:flutter/foundation.dart';

import '../../../core/learning/new_words_store.dart';
import '../../../models/word.dart';
import '../application/new_words_reader.dart';
import '../../../repositories/new_word_repository.dart';

/// 生词本的可观察展示状态。
///
/// 该状态只协调界面展示和用户操作；读取通过 [NewWordsReader]，持久化写入事实由 [NewWordRepository] 管理。
class NewWordsState extends ChangeNotifier implements NewWordsStore {
  NewWordsState({required this._newWordsReader, required this._newWordRepository});

  final NewWordsReader _newWordsReader;
  final NewWordRepository _newWordRepository;
  final Set<int> _wordIds = {};
  Future<void>? _initialization;
  bool _initialized = false;

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
    final isAdded = await _newWordRepository.toggleNewWord(word, source: source);
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
    final wasRemoved = await _newWordRepository.removeNewWord(word.id);
    if (wasRemoved) {
      _wordIds.remove(word.id);
      notifyListeners();
    }
    return wasRemoved;
  }
}
