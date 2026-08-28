import 'package:flutter/foundation.dart';

import '../../../repositories/fav_repository.dart';
import '../../../repositories/mastered_repository.dart';

/// 正式复习页按词用户操作的协调状态。
///
/// 收藏与手动掌握均保留各自独立的字符串集合语义。本状态只缓存展示所需
/// 快照、转发操作并通知页面，避免 `ReviewPage` 自行维护未持久化的副本。
class ReviewWordActionsState extends ChangeNotifier {
  ReviewWordActionsState({required this._favRepository, required this._masteredRepository});

  final FavRepository _favRepository;
  final MasteredRepository _masteredRepository;

  Set<String> _favoriteWords = const {};
  Set<String> _masteredWords = const {};
  bool _initialized = false;
  Future<void>? _initializing;

  bool get initialized => _initialized;
  bool isFavorite(String word) => _favoriteWords.contains(word);
  bool isManuallyMastered(String word) => _masteredWords.contains(word);

  Future<void> initialize() {
    if (_initialized) return Future.value();
    return _initializing ??= _loadInitialSnapshots();
  }

  Future<void> _loadInitialSnapshots() async {
    try {
      final favorites = await _favRepository.getFavoriteWords();
      final mastered = await _masteredRepository.getMasteredWords();
      _favoriteWords = Set.unmodifiable(favorites);
      _masteredWords = Set.unmodifiable(mastered);
      _initialized = true;
      notifyListeners();
    } finally {
      _initializing = null;
    }
  }

  /// 切换字符串收藏标记，并返回操作后的收藏状态。
  Future<bool> toggleFavorite(String word) async {
    await _ensureInitialized();
    await _favRepository.toggleFavorite(word);
    final isFavorite = _favRepository.isFavorite(word);
    _favoriteWords = {..._favoriteWords, if (isFavorite) word}..removeWhere((item) => !isFavorite && item == word);
    notifyListeners();
    return isFavorite;
  }

  /// 确保单词被标记为手动掌握；已标记时不反转为未掌握。
  Future<bool> markManuallyMastered(String word) async {
    await _ensureInitialized();
    if (_masteredWords.contains(word)) return false;

    await _masteredRepository.toggleMastered(word);
    _masteredWords = {..._masteredWords, word};
    notifyListeners();
    return true;
  }

  Future<void> _ensureInitialized() async {
    if (!_initialized) await initialize();
  }
}
