import 'package:flutter/foundation.dart';

import '../../../models/word.dart';
import '../application/dictionary_content_reader.dart';
import '../application/dictionary_favorite_writer.dart';
import '../application/dictionary_new_word_writer.dart';
import '../application/dictionary_search_reader.dart';
import '../domain/definition_item.dart';
import '../domain/example_sentence.dart';
import '../domain/phonetic_info.dart';

/// 词典详情页状态。
///
/// 封装当前单词的详情数据、收藏/生词状态，以及派生词/同义词/例句等附加内容。
/// 通过 [DictionarySearchReader] / [DictionaryContentReader] 读取数据，
/// 通过 [DictionaryFavoriteWriter] / [DictionaryNewWordWriter] 执行写操作。
class DictionaryDetailState extends ChangeNotifier {
  DictionaryDetailState({
    required this._searchReader,
    required this._contentReader,
    required this._favoriteWriter,
    required this._newWordWriter,
  });

  final DictionarySearchReader _searchReader;
  final DictionaryContentReader _contentReader;
  final DictionaryFavoriteWriter _favoriteWriter;
  final DictionaryNewWordWriter _newWordWriter;

  // ── 当前单词 ──────────────────────────────────────────────
  Word? _word;
  Word? get word => _word;

  PhoneticInfo? _phonetic;
  PhoneticInfo? get phonetic => _phonetic;

  List<DefinitionItem> _definitions = const [];
  List<DefinitionItem> get definitions => _definitions;

  // ── 附加内容 ──────────────────────────────────────────────
  List<Word> _derivedWords = const [];
  List<Word> get derivedWords => _derivedWords;

  List<Word> _synonyms = const [];
  List<Word> get synonyms => _synonyms;

  List<ExampleSentence> _examExamples = const [];
  List<ExampleSentence> get examExamples => _examExamples;

  // ── 状态标志 ──────────────────────────────────────────────
  bool _isFavorite = false;
  bool get isFavorite => _isFavorite;

  bool _isNewWord = false;
  bool get isNewWord => _isNewWord;

  bool _loading = false;
  bool get loading => _loading;

  String? _error;
  String? get error => _error;

  // ── 搜索 ──────────────────────────────────────────────────
  List<Word> _searchResults = const [];
  List<Word> get searchResults => _searchResults;

  bool _searching = false;
  bool get searching => _searching;

  /// 加载指定单词的详情。
  Future<void> loadWord(Word word) async {
    _word = word;
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      // 解析音标
      _phonetic = _parsePhonetic(word);
      // 解析释义
      _definitions = DefinitionItem.fromParsed(word.parsedDefinitions);
      // 收藏/生词状态
      _isFavorite = _favoriteWriter.isFavorite(word.word);
      _isNewWord = _newWordWriter.isNewWord(word.id);
      // 加载附加内容
      await _loadExtraContent(word);
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// 按单词字符串加载（先查库再加载）。
  Future<bool> loadByWordString(String wordStr) async {
    _searching = true;
    notifyListeners();
    try {
      final results = await _searchReader.searchSmart(wordStr);
      if (results.isEmpty) return false;
      await loadWord(results.first);
      return true;
    } finally {
      _searching = false;
      notifyListeners();
    }
  }

  /// 执行搜索并缓存结果。
  Future<void> search(String query) async {
    if (query.trim().isEmpty) {
      _searchResults = const [];
      notifyListeners();
      return;
    }
    _searching = true;
    notifyListeners();
    try {
      _searchResults = await _searchReader.searchSmart(query.trim());
    } finally {
      _searching = false;
      notifyListeners();
    }
  }

  /// 切换收藏状态。
  Future<void> toggleFavorite() async {
    if (_word == null) return;
    _isFavorite = await _favoriteWriter.toggleFavorite(_word!.word);
    notifyListeners();
  }

  /// 切换生词状态。
  Future<void> toggleNewWord({String source = 'dictionary'}) async {
    if (_word == null) return;
    _isNewWord = await _newWordWriter.toggleNewWord(_word!, source: source);
    notifyListeners();
  }

  // ── 私有方法 ──────────────────────────────────────────────

  Future<void> _loadExtraContent(Word word) async {
    try {
      _derivedWords = await _contentReader.getDerivedWords(word.word);
    } catch (_) {
      _derivedWords = const [];
    }
    try {
      _synonyms = await _contentReader.getSynonyms(word.word);
    } catch (_) {
      _synonyms = const [];
    }
    try {
      final raw = await _contentReader.getExamExamples(word.word);
      _examExamples = raw.map((m) {
        return ExampleSentence.fromRaw(
          english: m['english'] ?? '',
          chinese: m['chinese'] ?? '',
          highlight: m['highlight'],
        );
      }).toList();
    } catch (_) {
      _examExamples = const [];
    }
  }

  PhoneticInfo? _parsePhonetic(Word word) {
    final audioUrlsStr = word.audioUrls;
    if (audioUrlsStr.isNotEmpty) {
      // 格式：uk:uk_url,us:us_url
      final map = <String, String>{};
      final parts = audioUrlsStr.split(',');
      for (final part in parts) {
        final keyValue = part.split(':');
        if (keyValue.length == 2) {
          map[keyValue[0].trim()] = keyValue[1].trim();
        }
      }
      return PhoneticInfo(
        english: word.ukPron,
        american: word.usPron,
        ukAudio: map['uk'],
        usAudio: map['us'],
      );
    }
    // 从音标字段直接构建
    if (word.ukPron.isNotEmpty || word.usPron.isNotEmpty) {
      return PhoneticInfo.fromRaw(
        english: word.ukPron,
        american: word.usPron,
      );
    }
    return null;
  }
}
