// 由 Claude 团队生成 | Monster Word App
// 收藏例句数据访问层：管理用户收藏的例句
// 使用 SharedPreferences 存储（轻量级，无需额外数据库表）

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../models/sentence_models.dart';

/// 收藏例句 DAO（数据访问对象）
class FavSentenceDao {
  static final FavSentenceDao instance = FavSentenceDao._();
  FavSentenceDao._();

  static const String _keyList = 'fav_sentence_list';

  List<FavSentenceData> _cache = [];
  bool _loaded = false;

  /// 加载所有收藏例句
  Future<List<FavSentenceData>> loadAll() async {
    if (_loaded) return _cache;

    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_keyList);
    if (jsonStr == null || jsonStr.isEmpty) {
      _cache = [];
      _loaded = true;
      return _cache;
    }

    try {
      final List<dynamic> jsonList = jsonDecode(jsonStr);
      _cache = jsonList.map((e) => FavSentenceData.fromJson(e as Map<String, dynamic>)).toList();
      // 按更新时间倒序排列
      _cache.sort((a, b) => b.updateTime.compareTo(a.updateTime));
    } catch (e) {
      _cache = [];
    }

    _loaded = true;
    return _cache;
  }

  /// 保存所有收藏例句
  Future<void> _saveAll() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(_cache.map((e) => e.toJson()).toList());
    await prefs.setString(_keyList, jsonStr);
  }

  /// 添加收藏例句
  Future<bool> addFavSentence({
    required String word,
    required int wordId,
    required String sentenceId,
    required SentenceData sentenceData,
    String wordUsage = '',
    int type = 0,
  }) async {
    await loadAll();

    // 检查是否已收藏
    if (isFavSentence(wordId, sentenceId)) {
      return false;
    }

    final now = DateTime.now();
    final updateTime =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';

    final favData = FavSentenceData(
      word: word,
      wordId: wordId,
      sentenceId: sentenceId,
      sentenceData: sentenceData,
      wordUsage: wordUsage,
      updateTime: updateTime,
      type: type,
    );

    _cache.insert(0, favData);
    await _saveAll();
    return true;
  }

  /// 取消收藏例句
  Future<bool> removeFavSentence(int wordId, String sentenceId) async {
    await loadAll();

    final index = _cache.indexWhere((e) => e.wordId == wordId && e.sentenceId == sentenceId);

    if (index == -1) return false;

    _cache.removeAt(index);
    await _saveAll();
    return true;
  }

  /// 切换收藏状态
  Future<bool> toggleFavSentence({
    required String word,
    required int wordId,
    required String sentenceId,
    required SentenceData sentenceData,
    String wordUsage = '',
    int type = 0,
  }) async {
    if (isFavSentence(wordId, sentenceId)) {
      return removeFavSentence(wordId, sentenceId);
    } else {
      return addFavSentence(
        word: word,
        wordId: wordId,
        sentenceId: sentenceId,
        sentenceData: sentenceData,
        wordUsage: wordUsage,
        type: type,
      );
    }
  }

  /// 检查是否已收藏
  bool isFavSentence(int wordId, String sentenceId) {
    return _cache.any((e) => e.wordId == wordId && e.sentenceId == sentenceId);
  }

  /// 获取收藏例句数量
  int get favCount => _cache.length;

  /// 按单词获取收藏的例句
  List<FavSentenceData> getFavSentencesByWord(String word) {
    return _cache.where((e) => e.word == word).toList();
  }

  /// 按单词ID获取收藏的例句
  List<FavSentenceData> getFavSentencesByWordId(int wordId) {
    return _cache.where((e) => e.wordId == wordId).toList();
  }

  /// 清空缓存（用于刷新）
  void clearCache() {
    _cache = [];
    _loaded = false;
  }
}
