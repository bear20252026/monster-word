// 查词工具：下拉词典窗口
// 已接入 SkinSystem 主题
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../data/app_preferences.dart';
import '../data/example_parser.dart';
import 'package:provider/provider.dart';

import '../data/wordbook_database.dart';
import '../state/learning_state.dart';
import '../theme/skin_system.dart';
import '../tokens/design_tokens.dart';
import 'dictionary_page.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});
  static const routeName = '/search';

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _controller = TextEditingController();
  List<Word> _results = [];
  Word? _selectedWord;
  List<String> _searchHistory = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _loadHistory() {
    _searchHistory = AppPreferences().getSearchHistory();
  }

  Future<void> _saveToHistory(String word) async {
    await AppPreferences().addSearchHistory(word);
    _loadHistory();
  }

  Future<void> _clearHistory() async {
    await AppPreferences().clearSearchHistory();
    setState(() => _searchHistory = []);
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) {
      setState(() { _results = []; _selectedWord = null; });
      return;
    }
    setState(() {});
    final results = await WordBookDatabase.instance.searchWords(query.trim(), limit: 30);
    setState(() {
      _results = results;
      _selectedWord = results.isNotEmpty ? results.first : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin.colors;

    return Scaffold(
      backgroundColor: skin.pageBg,
      body: SafeArea(
        child: Column(
          children: [
            _buildSearchBar(skin),
            Expanded(
              child: _selectedWord != null
                  ? _buildWordDetail(_selectedWord!, skin)
                  : _results.isNotEmpty
                      ? _buildResultList(skin)
                      : _searchHistory.isNotEmpty
                          ? _buildHistory(skin)
                          : _buildEmpty(skin),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar(ThemeVars skin) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      decoration: BoxDecoration(
        color: skin.cardBg,
        border: Border(bottom: BorderSide(color: skin.divider)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F0F0),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  const Icon(Icons.search, size: 20, color: Color(0xFF999999)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: '输入要查询的英文或中文',
                        hintStyle: MistralTypography.bodyMd.copyWith(
                          color: const Color(0xFFBBBBBB),
                          fontSize: 15,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.only(bottom: 12),
                      ),
                      style: MistralTypography.bodyMd.copyWith(color: skin.text1),
                      onChanged: _search,
                      onSubmitted: _search,
                    ),
                  ),
                  if (_controller.text.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        _controller.clear();
                        _search('');
                      },
                      child: const Icon(Icons.clear, size: 18, color: Color(0xFF999999)),
                    )
                  else
                    const Icon(Icons.qr_code_scanner, size: 20, color: Color(0xFF666666)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Text('取消',
              style: TextStyle(fontSize: 16, color: Color(0xFF1F1F1F))),
          ),
        ],
      ),
    );
  }

  Widget _buildResultList(ThemeVars skin) {
    return ListView.builder(
      itemCount: _results.length,
      itemBuilder: (context, i) {
        final w = _results[i];
        return ListTile(
          title: Text(w.word,
            style: MistralTypography.bodyMd.copyWith(
              fontWeight: FontWeight.w600,
              color: skin.text1,
            )),
          subtitle: Text(
            w.interpret.split('\n').first,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: MistralTypography.caption.copyWith(color: skin.text3),
          ),
          selected: _selectedWord?.word == w.word,
          selectedTileColor: skin.cardBgAlt,
          onTap: () {
            _saveToHistory(w.word);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => DictionaryPage(word: w),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildWordDetail(Word word, ThemeVars skin) {
    final examples = ExampleParser.parse(word.example);
    final state = context.watch<LearningState>();
    final isFav = state.isFavorite(word.word);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(word.word,
                  style: MistralTypography.heading2.copyWith(
                    color: skin.text1,
                    fontWeight: FontWeight.bold,
                  )),
              ),
              IconButton(
                icon: Icon(
                  isFav ? Icons.star : Icons.star_border,
                  color: isFav ? Colors.amber : skin.text3,
                  size: 24,
                ),
                onPressed: () => state.toggleFavorite(word.word),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (word.usPron.isNotEmpty || word.ukPron.isNotEmpty)
            Row(
              children: [
                if (word.usPron.isNotEmpty)
                  Text('美 /${word.usPron}/  ',
                    style: MistralTypography.bodyMd.copyWith(color: skin.text3)),
                if (word.ukPron.isNotEmpty)
                  Text('英 /${word.ukPron}/',
                    style: MistralTypography.bodyMd.copyWith(color: skin.text3)),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _playAudio(word.word),
                  child: Icon(Icons.volume_up, color: skin.accent, size: 22),
                ),
              ],
            ),
          Divider(height: 32, color: skin.divider),
          ...word.interpretLines.map((line) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(line,
              style: MistralTypography.bodyMd.copyWith(color: skin.text1, height: 1.5)),
          )),
          if (examples.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('例句',
              style: MistralTypography.bodyMd.copyWith(
                fontWeight: FontWeight.w600,
                color: skin.text1,
              )),
            const SizedBox(height: 8),
            ...examples.take(3).map((ex) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: skin.cardBgAlt,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      style: MistralTypography.bodySm.copyWith(color: skin.text1, height: 1.4),
                      children: ex.highlightedParts.map((p) => TextSpan(
                        text: p.text,
                        style: p.highlight
                            ? TextStyle(fontWeight: FontWeight.bold, color: skin.accent)
                            : null,
                      )).toList(),
                    ),
                  ),
                  if (ex.cn.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(ex.cn,
                      style: MistralTypography.caption.copyWith(color: skin.text3)),
                  ],
                ],
              ),
            )),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DictionaryPage(word: word),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: skin.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
              ),
              child: Text(
                '查看完整字典',
                style: MistralTypography.bodyMd.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistory(ThemeVars skin) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Text('最近搜索',
                style: MistralTypography.bodyMd.copyWith(
                  fontWeight: FontWeight.w600,
                  color: skin.text1,
                )),
              const Spacer(),
              GestureDetector(
                onTap: _clearHistory,
                child: Text('清除',
                  style: MistralTypography.bodySm.copyWith(color: skin.text3)),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _searchHistory.length,
            itemBuilder: (context, i) {
              final word = _searchHistory[i];
              return ListTile(
                leading: Icon(Icons.history, color: skin.text3, size: 20),
                title: Text(word,
                  style: MistralTypography.bodyMd.copyWith(color: skin.text1)),
                onTap: () {
                  _controller.text = word;
                  _search(word);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmpty(ThemeVars skin) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search, size: 64, color: skin.divider),
          const SizedBox(height: 16),
          Text('输入单词开始查询',
            style: MistralTypography.bodyMd.copyWith(color: skin.text3)),
        ],
      ),
    );
  }

  Future<void> _playAudio(String word) async {
    try {
      final player = AudioPlayer();
      await player.play(UrlSource(
        'http://dict.youdao.com/dictvoice?audio=${Uri.encodeComponent(word)}&type=2',
      ));
    } catch (_) {}
  }
}
