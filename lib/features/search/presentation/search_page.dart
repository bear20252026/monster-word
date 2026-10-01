// 搜索功能域 · 搜索页面。
//
// 本文件是搜索功能的完整 UI，从 lib/pages/search_page.dart 迁入。
// 依赖全部通过 application 端口注入，不直连旧 data 层或跨 feature presentation。

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:word_app/core/audio/audio_playback_state.dart';
import 'package:word_app/core/presentation/responsive.dart';
import 'package:word_app/models/word.dart';
import 'package:word_app/theme/skin_system.dart';
import 'package:word_app/widgets/common/mw_empty_state.dart';
import 'package:word_app/widgets/common/mw_skeleton.dart';
import 'package:word_app/tokens/design_tokens.dart';
import 'package:word_app/widgets/breathing_word.dart';
import 'package:word_app/widgets/halo_search.dart';
import 'package:word_app/widgets/scale_down_on_press.dart';
import 'package:word_app/app/router/route_names.dart';
import 'package:word_app/features/search/application/example_reader.dart';
import 'package:word_app/features/search/application/favorites_accessor.dart';
import 'package:word_app/features/search/application/search_history_store.dart';
import 'package:word_app/features/search/application/word_search_reader.dart';
import 'package:word_app/features/search/domain/search_example.dart';
import 'package:word_app/core/utils/swallowed_error_report.dart';
import 'package:word_app/core/application/app_messages.dart';

/// 搜索功能域的完整页面。
///
/// 通过 Provider 向上层读取 [WordSearchReader] / [SearchHistoryStore] /
/// [ExampleReader] / [FavoritesAccessor] / [AudioPlaybackState]。
class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  /// R4：路由唯一事实来源 RouteNames.search
  static const String routeName = RouteNames.search;

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
    // 内存审计 P1：未取消防抖 Timer，输入后 300ms 内退出页面会在 State
    // 已 dispose 后触发 _search（setState after dispose 必崩）。
    _debounce?.cancel();
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
    if (!mounted) return;
    _loadHistory();
  }

  Future<void> _clearHistory() async {
    await context.read<SearchHistoryStore>().clear();
    if (!mounted) return;
    setState(() => _searchHistory = []);
  }

  /// 防抖：输入时 300ms 合并查询（体验审计 P0——每个按键触发一次全库检索）
  Timer? _debounce;
  int _searchSeq = 0;

  void _onQueryChanged(String query) {
    if (query.trim().isEmpty) {
      _debounce?.cancel();
      _search(query);
      return;
    }
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () => _search(query));
  }

  Future<void> _search(String query) async {
    // Timer 回调入口：State 可能已随页面退出被 dispose，先做存活检查。
    if (!mounted) return;
    if (query.trim().isEmpty) {
      setState(() {
        _results = [];
        _selectedWord = null;
        _hasSearched = false;
        _lastQuery = '';
      });
      return;
    }
    final seq = ++_searchSeq;
    setState(() => _isLoading = true);
    // 容错：查询异常必须复位 loading（此前异常会永久卡死骨架屏）
    try {
      final results = await context.read<WordSearchReader>().search(query.trim());
      if (!mounted || seq != _searchSeq) return; // 过期响应丢弃
      setState(() {
        _results = results;
        _selectedWord = results.isNotEmpty ? results.first : null;
        _hasSearched = true;
        _lastQuery = query.trim();
        _isLoading = false;
      });
    } catch (e, s) {
      // 审计 I90：搜索失败聚合观测的源头打点（此前静默复位，失败率不可见）
      reportSwallowedError('单词搜索失败: ${query.trim()}', e, s);
      if (!mounted || seq != _searchSeq) return;
      setState(() {
        _results = [];
        _selectedWord = null;
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
              textStyle: MwTypography.bodyMd.copyWith(color: skin.text1),
              hintStyle: MwTypography.bodyMd.copyWith(
                color: context.skin.colors.text2,
                fontSize: AppFontSizes.bodyXl * resp.fontScale,
              ),
              onChanged: _onQueryChanged,
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
                  : Icon(Icons.qr_code_scanner, size: 20, color: context.skin.colors.text2),
            ),
          ),
          const SizedBox(width: 12),
          ScaleDownOnPress(
            onTap: () => Navigator.pop(context),
            child: Text(
              '取消',
              style: TextStyle(fontSize: AppFontSizes.bodyMd * resp.fontScale, color: skin.text1),
            ),
          ),
        ],
      ),
    );
  }

  // ─── 加载中 ──────────────────────────────────────────────────────────────

  Widget _buildLoading(ThemeVars skin) {
    // 骨架屏：用结果列表的形状预判加载后的样子，替代转圈
    return ListView.builder(
      itemCount: 6,
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      itemBuilder: (_, _) => const MwSkeletonListItem(),
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
            color: _selectedWord?.word == w.word ? skin.accent.withValues(alpha: AppAlphas.o08) : Colors.transparent,
            child: Container(
              decoration: _selectedWord?.word == w.word
                  ? BoxDecoration(
                      border: Border(left: BorderSide(color: skin.accent, width: 3)),
                    )
                  : null,
              child: ListTile(
                title: Text(
                  w.word,
                  style: MwTypography.bodyMd.copyWith(
                    fontWeight: FontWeight.w600,
                    color: _selectedWord?.word == w.word ? skin.accent : skin.text1,
                  ),
                ),
                subtitle: Text(
                  w.firstInterpretLine,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: MwTypography.caption.copyWith(color: skin.text3),
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
                  style: MwTypography.heading2.copyWith(color: skin.text1, fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                icon: Icon(
                  isFav ? Icons.star : Icons.star_border,
                  color: isFav ? MwColors.warning : skin.text3,
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
                  Text('美 /${word.usPron}/  ', style: MwTypography.bodyMd.copyWith(color: skin.text3)),
                if (word.ukPron.isNotEmpty)
                  Text('英 /${word.ukPron}/', style: MwTypography.bodyMd.copyWith(color: skin.text3)),
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
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: Text(line, style: MwTypography.bodyMd.copyWith(color: skin.text1, height: 1.5)),
                ),
              ),
          if (examples.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              '例句',
              style: MwTypography.bodyMd.copyWith(fontWeight: FontWeight.w600, color: skin.text1),
            ),
            const SizedBox(height: 8),
            ...examples.take(3).map((ex) => _buildExampleCard(ex, skin)),
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
                foregroundColor: AppColors.white100,
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(context.design.radius.lg)),
              ),
              child: Text(
                '查看完整字典',
                style: MwTypography.bodyMd.copyWith(color: AppColors.white100, fontWeight: FontWeight.w600),
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
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(color: skin.cardBgAlt, borderRadius: BorderRadius.circular(context.design.radius.md)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              style: MwTypography.bodySm.copyWith(color: skin.text1, height: 1.4),
              children: ex.highlightedParts
                  .map(
                    (p) => TextSpan(
                      text: p.text,
                      style: p.highlight ? TextStyle(fontWeight: FontWeight.bold, color: skin.accent) : null,
                    ),
                  )
                  .toList(),
            ),
          ),
          if (ex.cn.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(ex.cn, style: MwTypography.caption.copyWith(color: skin.text3)),
          ],
          if (ex.audioUrl != null && ex.audioUrl!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
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
                style: MwTypography.bodyMd.copyWith(fontWeight: FontWeight.w600, color: skin.text1),
              ),
              const Spacer(),
              ScaleDownOnPress(
                onTap: _clearHistory,
                child: Text('清除', style: MwTypography.bodySm.copyWith(color: skin.text3)),
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
                  title: Text(word, style: MwTypography.bodyMd.copyWith(color: skin.text1)),
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
    return MwEmptyState(
      kind: MwEmptyKind.search,
      title: '未找到匹配的单词',
      subtitle: _lastQuery.isNotEmpty ? '搜索词: "$_lastQuery"，试试其他关键词' : '请检查拼写，或尝试搜索其他关键词',
    );
  }

  Widget _buildEmpty(ThemeVars skin) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search, size: 64, color: skin.divider),
          const SizedBox(height: 16),
          Text('输入单词开始查询', style: MwTypography.bodyMd.copyWith(color: skin.text3)),
          const SizedBox(height: 24),
          // 示例单词呼吸轮换：同一时刻只显示一个词（原波浪滚动文字已废弃）
          BreathingWord(
            words: const ['abandon', 'ability', 'above', 'accept', 'achieve'],
            style: TextStyle(
              fontSize: AppFontSizes.micro,
              color: skin.text3.withValues(alpha: AppAlphas.o50),
              letterSpacing: 1,
            ),
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
            .showSnackBar(const SnackBar(content: Text(AppMessages.audioLoadFailed), duration: Duration(seconds: 2)));
      }
    }
  }
}
