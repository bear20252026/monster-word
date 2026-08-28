import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../models/word.dart';
import '../../../repositories/fav_repository.dart';
import '../data/learning_queue_repository.dart';

/// 收藏单词的读取与操作状态。
///
/// 持久化仍完全委托 [FavRepository]；该状态只维护可供页面订阅的不可变词形集合、
/// 收藏数和加载状态，并通过 [LearningQueueRepository] 解析完整词表中的收藏词。
class LearningFavoritesState extends ChangeNotifier {
  LearningFavoritesState({required this._favoriteRepository, required this._queueRepository}) {
    unawaited(refresh());
  }

  final FavRepository _favoriteRepository;
  final LearningQueueRepository _queueRepository;

  Set<String> _favoriteWords = const {};
  bool _isLoading = true;

  Set<String> get favoriteWords => Set.unmodifiable(_favoriteWords);
  int get favoriteCount => _favoriteWords.length;
  bool get isLoading => _isLoading;

  bool isFavorite(String word) => _favoriteWords.contains(word);

  Future<void> refresh() async {
    _isLoading = true;
    notifyListeners();
    try {
      _favoriteWords = (await _favoriteRepository.getFavoriteWords()).toSet();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> toggle(String word) async {
    await _favoriteRepository.toggleFavorite(word);
    _favoriteWords = (await _favoriteRepository.getFavoriteWords()).toSet();
    notifyListeners();
    return _favoriteWords.contains(word);
  }

  Future<List<Word>> loadFavoriteWords({required Iterable<Word> currentQueue}) {
    return _queueRepository.loadFavoriteWords(currentQueue: currentQueue);
  }
}
