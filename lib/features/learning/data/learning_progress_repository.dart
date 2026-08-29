import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:word_app/core/infrastructure/wordbook_database.dart' show Book;
import 'package:word_app/models/word.dart';

/// 已保存的学习队列进度。
///
/// 队列快照目前只用于保持既有存储合同；恢复词书仍由学习会话在显式加载词书时完成。
class LearningProgressSnapshot {
  const LearningProgressSnapshot({required this.bookId, required this.currentIndex, required this.queueWordIds});

  final String bookId;
  final int currentIndex;
  final List<int> queueWordIds;
}

/// 当前学习队列进度的持久化边界。
///
/// 保留历史 `SharedPreferences` 键和值结构，避免队列命令迁移影响已有用户的学习进度。
class LearningProgressRepository {
  static const currentBookPrefKey = 'current_book_v1';
  static const currentIndexPrefKey = 'current_index_v1';
  static const queueSnapshotPrefKey = 'queue_snapshot_v1';

  Future<void> save({required Book? currentBook, required int currentIndex, required List<Word> queue}) async {
    if (currentBook == null) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(currentBookPrefKey, currentBook.id.toString());
    await prefs.setInt(currentIndexPrefKey, currentIndex);
    await prefs.setString(queueSnapshotPrefKey, jsonEncode(queue.map((word) => word.id).toList()));
  }

  Future<LearningProgressSnapshot?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final bookId = prefs.getString(currentBookPrefKey);
    if (bookId == null) return null;

    final rawQueue = prefs.getString(queueSnapshotPrefKey);
    return LearningProgressSnapshot(
      bookId: bookId,
      currentIndex: prefs.getInt(currentIndexPrefKey) ?? 0,
      queueWordIds: _decodeQueueWordIds(rawQueue),
    );
  }

  List<int> _decodeQueueWordIds(String? rawQueue) {
    if (rawQueue == null) return const [];
    try {
      final decoded = jsonDecode(rawQueue);
      if (decoded is! List) return const [];
      return decoded.whereType<num>().map((id) => id.toInt()).toList(growable: false);
    } on FormatException {
      return const [];
    }
  }
}
