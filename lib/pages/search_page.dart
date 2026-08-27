// 查词工具：下拉词典窗口
// 已接入 SkinSystem 主题
import 'package:flutter/material.dart';

import '../data/app_preferences.dart';
import '../data/example_parser.dart';
import '../hooks/responsive.dart';

import 'package:provider/provider.dart';

import '../core/di/service_locator.dart';
import '../models/word.dart';
import '../repositories/word_repository.dart';
import '../features/player/presentation/audio_playback_state.dart';
import '../features/learning/presentation/learning_favorites_state.dart';
import '../theme/skin_system.dart';
import '../tokens/design_tokens.dart';
import '../widgets/scale_down_on_press.dart';
import '../widgets/halo_search.dart';
import '../widgets/path_marquee.dart';
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
  bool _hasSearched = false;
  String _lastQuery = '';
  Word? _selectedWord;
  List<String> _searchHistory = [];
  bool _isLoading = false;

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
    setState(() {
      _searchHistory = AppPreferences().getSearchHistory();
    });
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
      setState(() {
        _results = [];
        _selectedWord = null;
        _hasSearched = false;
        _lastQuery = '';
      });
      return;
    }
    setState(() => _isLoading = true);
    final wordRepo = sl<WordRepository>();
    final results = await wordRepo.searchWords(query.trim());
    if (mounted) {
      setState(() {
        _results = results;
        _selectedWord = results.isNotEmpty ? results.first : null;
        _hasSearched = true;
        _lastQuery = query.trim();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin.colors;
    final resp = context.responsive;

    return Scaffold(
      backgroundColor: skin.pageBg,
      body: HaloSearchBackground(
        color: skin.accent,
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: resp.contentMaxWidth),
              child: Column(
                children: [
                  _buildSearchBar(skin),
                  Expanded(
                    child: _isLoading
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircularProgressIndicator(color: skin.accent),
                                const SizedBox(height: 12),
                                Text('搜索中…', style: TextStyle(color: skin.text3, fontSize: 14)),
                              ],
                            ),
                          )
                        : _selectedWord != null
                        ? _buildWordDetail(_selectedWord!, skin)
                        : _results.isNotEmpty
                        ? _buildResultList(skin)
                        : _hasSearched
                        ? _buildNoResults(skin)
                        : _searchHistory.isNotEmpty
                        ? _buildHistory(skin)
                        : _buildEmpty(skin),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar(ThemeVars skin) {
    final resp = context.responsive;
    return Container(
      padding: EdgeInsets.fromLTRB(resp.horizontalPadding, 12, resp.horizontalPadding, 8),
      decoration: BoxDecoration(
        color: skin.cardBg,
        border: Border(bottom: BorderSide(color: skin.divider)),
      ),
      child: Row(
        children: [
          Expanded(
            child: HaloSearchField(
              controller: _controller,
              hintText: '输入要查询的英文或中文',
              haloColor: skin.accent,
              bgColor: skin.cardBgAlt,
              textStyle: MistralTypography.bodyMd.copyWith(color: skin.text1),
              hintStyle: MistralTypography.bodyMd.copyWith(color: MistralColors.muted, fontSize: 15 * resp.fontScale),
              onChanged: _search,
              onSubmitted: _search,
              autoFocus: true,
              suffixIcon: _controller.text.isNotEmpty
                  ? GestureDetector(
                      onTap: () {
                        _controller.clear();
                        _search('');
                      },
                      child: Icon(Icons.clear, size: 18, color: skin.text3),
                    )
                  : Icon(Icons.qr_code_scanner, size: 20, color: MistralColors.slate),
            ),
          ),
          const SizedBox(width: 12),
          ScaleDownOnPress(
            onTap: () => Navigator.pop(context),
            child: Text(
              '取消',
              style: TextStyle(fontSize: 16 * resp.fontScale, color: skin.text1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultList(ThemeVars skin) {
    return ListView.builder(
      itemCount: _results.length,
      addAutomaticKeepAlives: false,
      addRepaintBoundaries: true,
      itemBuilder: (context, i) {
        final w = _results[i];
        return ScaleDownOnPress(
          onTap: () {
            _saveToHistory(w.word);
            Navigator.push(context, MaterialPageRoute(builder: (_) => DictionaryPage(word: w)));
          },
          child: ListTile(
            title: Text(
              w.word,
              style: MistralTypography.bodyMd.copyWith(fontWeight: FontWeight.w600, color: skin.text1),
            ),
            subtitle: Text(
              w.firstInterpretLine,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: MistralTypography.caption.copyWith(color: skin.text3),
            ),
            selected: _selectedWord?.word == w.word,
            selectedTileColor: skin.cardBgAlt,
          ),
        );
      },
    );
  }

  Widget _buildWordDetail(Word word, ThemeVars skin) {
    final examples = ExampleParser.parse(word.example);
    final favorites = context.watch<LearningFavoritesState>();
    final isFav = favorites.isFavorite(word.word);
    final resp = context.responsive;
    return SingleChildScrollView(
      padding: EdgeInsets.all(resp.horizontalPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // 返回按钮：关闭内嵌详情，回到搜索结果
              IconButton(
                icon: Icon(Icons.close, color: skin.text3, size: 22),
                tooltip: '关闭',
                onPressed: () => setState(() => _selectedWord = null),
              ),
              Expanded(
                child: Text(
                  word.word,
                  style: MistralTypography.heading2.copyWith(color: skin.text1, fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                icon: Icon(
                  isFav ? Icons.star : Icons.star_border,
                  color: isFav ? MistralColors.warning : skin.text3,
                  size: 24,
                ),
                onPressed: () => favorites.toggle(word.word),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (word.usPron.isNotEmpty || word.ukPron.isNotEmpty)
            Row(
              children: [
                if (word.usPron.isNotEmpty)
                  Text('美 /${word.usPron}/  ', style: MistralTypography.bodyMd.copyWith(color: skin.text3)),
                if (word.ukPron.isNotEmpty)
                  Text('英 /${word.ukPron}/', style: MistralTypography.bodyMd.copyWith(color: skin.text3)),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _playAudio(word.word),
                  child: Icon(Icons.volume_up, color: skin.accent, size: 22),
                ),
              ],
            ),
          Divider(height: 32, color: skin.divider),
          ...(word.hasStructuredDefinitions
                  ? word.formattedDefinitions.split('\n').where((l) => l.trim().isNotEmpty).toList()
                  : word.interpretLines)
              .map(
                (line) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(line, style: MistralTypography.bodyMd.copyWith(color: skin.text1, height: 1.5)),
                ),
              ),
          if (examples.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              '例句',
              style: MistralTypography.bodyMd.copyWith(fontWeight: FontWeight.w600, color: skin.text1),
            ),
            const SizedBox(height: 8),
            ...examples
                .take(3)
                .map(
                  (ex) => Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: skin.cardBgAlt, borderRadius: BorderRadius.circular(AppRadius.md)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RichText(
                          text: TextSpan(
                            style: MistralTypography.bodySm.copyWith(color: skin.text1, height: 1.4),
                            children: ex.highlightedParts
                                .map(
                                  (p) => TextSpan(
                                    text: p.text,
                                    style: p.highlight
                                        ? TextStyle(fontWeight: FontWeight.bold, color: skin.accent)
                                        : null,
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                        if (ex.cn.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(ex.cn, style: MistralTypography.caption.copyWith(color: skin.text3)),
                        ],
                      ],
                    ),
                  ),
                ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => DictionaryPage(word: word)));
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: skin.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
              ),
              child: Text(
                '查看完整字典',
                style: MistralTypography.bodyMd.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistory(ThemeVars skin) {
    final resp = context.responsive;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(resp.horizontalPadding, 16, resp.horizontalPadding, 8),
          child: Row(
            children: [
              Text(
                '最近搜索',
                style: MistralTypography.bodyMd.copyWith(fontWeight: FontWeight.w600, color: skin.text1),
              ),
              const Spacer(),
              ScaleDownOnPress(
                onTap: _clearHistory,
                child: Text('清除', style: MistralTypography.bodySm.copyWith(color: skin.text3)),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _searchHistory.length,
            itemBuilder: (context, i) {
              final word = _searchHistory[i];
              return ScaleDownOnPress(
                onTap: () {
                  _controller.text = word;
                  _search(word);
                },
                child: ListTile(
                  leading: Icon(Icons.history, color: skin.text3, size: 20),
                  title: Text(word, style: MistralTypography.bodyMd.copyWith(color: skin.text1)),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildNoResults(ThemeVars skin) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 64, color: skin.divider),
          const SizedBox(height: 16),
          Text('未找到匹配的单词', style: MistralTypography.bodyMd.copyWith(color: skin.text3)),
          const SizedBox(height: 8),
          Text('请检查拼写，或尝试搜索其他关键词', style: MistralTypography.bodySm.copyWith(color: skin.text3)),
          if (_lastQuery.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              '搜索词: "$_lastQuery"',
              style: MistralTypography.bodySm.copyWith(color: MistralColors.muted, fontStyle: FontStyle.italic),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmpty(ThemeVars skin) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search, size: 64, color: skin.divider),
          const SizedBox(height: 16),
          Text('输入单词开始查询', style: MistralTypography.bodyMd.copyWith(color: skin.text3)),
          const SizedBox(height: 24),
          // 波浪滚动装饰文字
          PathMarquee(
            text: 'abandon · ability · about · above · accept · ',
            pathType: MarqueePathType.sine,
            pathWidth: 260,
            pathHeight: 24,
            speed: 0.5,
            loopDuration: const Duration(seconds: 6),
            textStyle: TextStyle(fontSize: 12, color: skin.text3.withValues(alpha: 0.5), letterSpacing: 1),
          ),
        ],
      ),
    );
  }

  Future<void> _playAudio(String word) async {
    try {
      // 通过播放器功能域播放音频
      await context.read<AudioPlaybackState>().playWord(word);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('发音加载失败，请检查网络'), duration: Duration(seconds: 2)));
      }
    }
  }
}
