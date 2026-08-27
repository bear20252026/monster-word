import 'package:flutter/foundation.dart';

import '../../../models/word.dart';
import '../../../repositories/new_word_repository.dart';

/// 生词本的可观察展示状态。
///
/// 该状态只协调界面展示和用户操作，持久化事实始终由 [NewWordRepository] 管理。
class NewWordsState extends ChangeNotifier {
  NewWordsState({required NewWordRepository newWordRepository}) : _newWordRepository = newWordRepository;

  final NewWordRepository _newWordRepository;
  final Set<int> _wordIds = {};
  Future<void>? _initialization;
  bool _initialized = false;

  bool get initialized => _initialized;
  int get count => _wordIds.length;

  bool isNewWord(int wordId) => _wordIds.contains(wordId);

  Future<void> initialize() {
    return _initialization ??= _loadInitialRecords();
  }

  Future<void> _loadInitialRecords() async {
    final records = await _newWordRepository.getNewWords();
    _wordIds
      ..clear()
      ..addAll(records.map((record) => record.wordId));
    _initialized = true;
    notifyListeners();
  }

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
