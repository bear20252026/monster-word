// 搜索功能域 · 搜索页面。
//
// 本文件是搜索功能的完整 UI，从 lib/pages/search_page.dart 迁入。
// 依赖全部通过 application 端口注入，不直连旧 data 层或跨 feature presentation。

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/audio/audio_playback_state.dart';
import 'package:word_app/core/presentation/responsive.dart';
import '../../../models/word.dart';
import '../../../theme/skin_system.dart';
import '../../../tokens/design_tokens.dart';
import '../../../widgets/halo_search.dart';
import '../../../widgets/path_marquee.dart';
import '../../../widgets/scale_down_on_press.dart';
import '../../../core/router/route_names.dart';
import '../application/example_reader.dart';
import '../application/favorites_accessor.dart';
import '../application/search_history_store.dart';
import '../application/word_search_reader.dart';
import '../domain/search_example.dart';

/// 搜索页路由名。
const String searchRouteName = '/search';

/// 搜索功能域的完整页面。
///
/// 通过 Provider 向上层读取 [WordSearchReader] / [SearchHistoryStore] /
/// [ExampleReader] / [FavoritesAccessor] / [AudioPlaybackState]。
class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  static const String routeName = searchRouteName;

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
      _searchHistory = context.read<SearchHistoryStore>().read();
    });
  }

  Future<void> _saveToHistory(String word) async {
    await context.read<SearchHistoryStore>().add(word);
    _loadHistory();
  }

  Future<void> _clearHistory() async {
    await context.read<SearchHistoryStore>().clear();
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
    final results = await context.read<WordSearchReader>().search(query.trim());
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
                        ? _buildLoading(skin)
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

  // ─── 搜索栏 ──────────────────────────────────────────────────────────────

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

  // ─── 加载中 ──────────────────────────────────────────────────────────────

  Widget _buildLoading(ThemeVars skin) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: skin.accent),
          const SizedBox(height: 12),
          Text('搜索中…', style: TextStyle(color: skin.text3, fontSize: 14)),
        ],
      ),
    );
  }

  // ─── 搜索结果列表 ────────────────────────────────────────────────────────

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
            Navigator.pushNamed(context, RouteNames.dictionary, arguments: w);
          },
          child: Material(
            color: _selectedWord?.word == w.word
                ? skin.accent.withValues(alpha: 0.08)
                : Colors.transparent,
            child: Container(
              decoration: _selectedWord?.word == w.word
                  ? BoxDecoration(
                      border: Border(
                        left: BorderSide(color: skin.accent, width: 3),
                      ),
                    )
                  : null,
              child: ListTile(
                title: Text(
                  w.word,
                  style: MistralTypography.bodyMd.copyWith(
                    fontWeight: FontWeight.w600,
                    color: _selectedWord?.word == w.word ? skin.accent : skin.text1,
                  ),
                ),
                subtitle: Text(
                  w.firstInterpretLine,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: MistralTypography.caption.copyWith(color: skin.text3),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ─── 词义详情 ────────────────────────────────────────────────────────────

  Widget _buildWordDetail(Word word, ThemeVars skin) {
    // 通过端口解析例句（不再直连 example_parser.dart）
    final exampleReader = context.read<ExampleReader>();
    final examples = exampleReader.parse(word.example);

    // 通过端口查询收藏状态（不再直连 LearningFavoritesState）
    final favoritesAccessor = context.read<FavoritesAccessor>();
    final isFav = favoritesAccessor.isFavorite(word.word);
    final resp = context.responsive;

    return SingleChildScrollView(
      padding: EdgeInsets.all(resp.horizontalPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
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
                onPressed: () => favoritesAccessor.toggle(word.word),
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
                  (ex) => _buildExampleCard(ex, skin),
                ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, RouteNames.dictionary, arguments: word);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: skin.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(context.design.radius.lg)),
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

  Widget _buildExampleCard(SearchExample ex, ThemeVars skin) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: skin.cardBgAlt, borderRadius: BorderRadius.circular(context.design.radius.md)),
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
          if (ex.audioUrl != null && ex.audioUrl!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: IconButton(
                icon: Icon(Icons.volume_up_outlined, color: skin.accent, size: 20),
                onPressed: () => context.read<AudioPlaybackState>().playSentence(ex.audioUrl!),
                tooltip: '播放例句',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minHeight: 32, minWidth: 32),
              ),
            ),
        ],
      ),
    );
  }

  // ─── 搜索历史 ────────────────────────────────────────────────────────────

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

  // ─── 无结果 ──────────────────────────────────────────────────────────────

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

  // ─── 空状态 ──────────────────────────────────────────────────────────────

  Widget _buildEmpty(ThemeVars skin) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search, size: 64, color: skin.divider),
          const SizedBox(height: 16),
          Text('输入单词开始查询', style: MistralTypography.bodyMd.copyWith(color: skin.text3)),
          const SizedBox(height: 24),
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

  // ─── 音频播放 ────────────────────────────────────────────────────────────

  Future<void> _playAudio(String word) async {
    try {
      await context.read<AudioPlaybackState>().playWord(word);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('发音加载失败，请检查网络'), duration: Duration(seconds: 2)));
      }
    }
  }
}
