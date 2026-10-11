import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:word_app/core/utils/swallowed_error_report.dart';
import 'package:word_app/features/learning/application/learning_favorites_store.dart';
import 'package:word_app/models/word.dart';
import 'package:word_app/features/learning/application/favorites_port.dart';
import 'package:word_app/features/learning/application/learning_queue_port.dart';

/// 收藏单词的读取与操作状态。
///
/// 持久化仍完全委托 [FavRepository]；该状态只维护可供页面订阅的不可变词形集合、
/// 收藏数和加载状态，并通过 [LearningQueueRepository] 解析完整词表中的收藏词。
class LearningFavoritesState extends ChangeNotifier implements LearningFavoritesStore {
  LearningFavoritesState({required this._favoritesPort, required this._queuePort}) {
    unawaited(refresh());
  }

  final FavoritesPort _favoritesPort;
  final LearningQueuePort _queuePort;

  Set<String> _favoriteWords = const {};
  bool _isLoading = true;

  @override
  Set<String> get favoriteWords => Set.unmodifiable(_favoriteWords);
  @override
  int get favoriteCount => _favoriteWords.length;
  @override
  bool get isLoading => _isLoading;

  @override
  bool isFavorite(String word) => _favoriteWords.contains(word);

  @override
  Future<void> refresh() async {
    _isLoading = true;
    notifyListeners();
    try {
      _favoriteWords = await _favoritesPort.getFavoriteWords();
    } catch (e, s) {
      // 构造期 unawaited(refresh()) 的兜底：DAO 读库异常不能进 unhandled
      //（吞掉后保持空集合降级，收藏按钮仍可点击重试）。
      reportSwallowedError('收藏词集合加载失败', e, s);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  @override
  Future<bool> toggle(String word) async {
    try {
      await _favoritesPort.toggleFavorite(word);
      _favoriteWords = await _favoritesPort.getFavoriteWords();
    } catch (e, s) {
      // 调用方多为 fire-and-forget（learn_page 收藏按钮）：写库失败在此接住
      // 并上报，返回持久层未变的旧状态，不把异常抛进 unhandled。
      reportSwallowedError('收藏切换写入失败', e, s);
      notifyListeners();
      return _favoriteWords.contains(word);
    }
    notifyListeners();
    return _favoriteWords.contains(word);
  }

  @override
  Future<List<Word>> loadFavoriteWords({required Iterable<Word> currentQueue}) {
    return _queuePort.loadFavoriteWords(currentQueue: currentQueue.toList());
  }
}
