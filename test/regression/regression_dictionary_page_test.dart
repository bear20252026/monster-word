// ============================================================
// 回归测试 — 词典详情页（REG-DICT-xxx / REG-DOCK-xxx）
// 规则：每个 REG-ID 对应一个已修复线上 bug，测试永久保留，
//       任何导致本文件失败的改动都必须先证明 bug 不会复发。
// 台账：docs/regression_ledger.md
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:word_app/core/parsers/example_parser.dart';
import 'package:word_app/features/dictionary/application/dictionary_content_reader.dart';
import 'package:word_app/features/dictionary/application/dictionary_favorite_writer.dart';
import 'package:word_app/features/dictionary/application/dictionary_new_word_writer.dart';
import 'package:word_app/features/dictionary/application/dictionary_search_reader.dart';
import 'package:word_app/features/dictionary/presentation/dictionary_page.dart';
import 'package:word_app/models/sentence_models.dart';
import 'package:word_app/features/word_browse/application/sentence_favorites_store.dart';
import 'package:word_app/models/word.dart';
import 'package:word_app/widgets/app_dock.dart';
import 'package:word_app/widgets/mw_card.dart';

// ── Mock 实现（与 dictionary_detail_state_test 同款）─────────

class _FakeSearchReader implements DictionarySearchReader {
  @override
  Future<List<Word>> searchByPrefix(String prefix) async => const [];

  @override
  Future<List<Word>> searchFuzzy(String query) async => const [];

  @override
  Future<List<Word>> searchSmart(String query) async => const [];
}

class _FakeContentReader implements DictionaryContentReader {
  _FakeContentReader({this.derived = const [], this.examples = const [], this.realExamSentences = const []});

  final List<Word> derived;
  final List<ExampleSentence> examples;
  final List<Map<String, String>> realExamSentences;

  @override
  Future<List<Word>> getDerivedWords(String word) async => derived;

  @override
  Future<List<Word>> getSynonyms(String word) async => const [];

  @override
  Future<List<ExampleSentence>> getExamExamples(String word) async => examples;

  @override
  Future<List<Map<String, String>>> getRealExamSentences(String word) async => realExamSentences;

  @override
  Future<List<CollinsSense>> getCollinsSenses(String word) async => const [];
}

class _FakeSentenceFavoritesStore implements SentenceFavoritesStore {
  @override
  Future<List<FavSentenceData>> list() async => const [];

  @override
  Future<bool> remove({required int wordId, required String sentenceId}) async => false;

  @override
  Future<bool> isFavorite({required int wordId, required String sentenceId}) async => false;

  @override
  Future<bool> toggle({
    required int wordId,
    required String sentenceId,
    required String english,
    required String chinese,
    String source = '',
  }) async => true;
}

class _FakeFavoriteWriter implements DictionaryFavoriteWriter {
  @override
  Future<bool> toggleFavorite(String word) async => true;

  @override
  bool isFavorite(String word) => false;

  @override
  Future<Set<String>> getFavoriteWords() async => {};
}

class _FakeNewWordWriter implements DictionaryNewWordWriter {
  @override
  Future<bool> toggleNewWord(Word word, {String source = 'dictionary'}) async => true;

  @override
  bool isNewWord(int wordId) => false;
}

// ── 测试数据 ───────────────────────────────────────────────

const _mainWordCn = '主词专属释义乙';
const _derivedWordCn = '派生词专属释义甲';

Word _wordWithDef(String headword, String cnDef) =>
    Word(word: headword, interpret: '[{"t":"n.","def":[{"en":"eng","cn":"$cnDef"}]}]');

Future<void> _pumpDictionaryPage(
  WidgetTester tester, {
  required Word word,
  List<Word> derived = const [],
  List<ExampleSentence> examples = const [],
  List<Map<String, String>> realExamSentences = const [],
}) async {
  // 端口 Provider 挂在 MaterialApp.builder（等价于真实 App 的顶层 feature scope，
  // 位于 Navigator 之上）——这样 push 出的新路由页面同样能读到端口。
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MultiProvider(
        providers: [
          Provider<DictionarySearchReader>.value(value: _FakeSearchReader()),
          Provider<DictionaryContentReader>.value(
            value: _FakeContentReader(derived: derived, examples: examples, realExamSentences: realExamSentences),
          ),
          Provider<DictionaryFavoriteWriter>.value(value: _FakeFavoriteWriter()),
          Provider<DictionaryNewWordWriter>.value(value: _FakeNewWordWriter()),
          // ExampleTile（例句卡）消费句收藏 store，测试桩同样挂上
          Provider<SentenceFavoritesStore>.value(value: _FakeSentenceFavoritesStore()),
        ],
        child: child!,
      ),
      home: DictionaryPage(word: word),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('REG-DICT-001: 词典详情页自挂载 DetailState，裸 push 不再 Provider not found', (tester) async {
    // 症状：release 真机词典详情页多个区块显示「页面出错了」；
    // 根因：error_boundary.log 实锤 Provider<DictionaryDetailState> not found ——
    //       buildDictionaryDetailScope 定义后全工程零调用，页面所有 Consumer 构建即崩。
    // 修复：commit 305113b —— DictionaryPage.build 自包裹 buildDictionaryDetailScope。
    // 本测试模拟路由裸 push（content_routes 正常路径），修复前此用例抛
    // ProviderNotFoundException，修复后页面完整渲染（标签栏 + 释义区块）。
    await _pumpDictionaryPage(tester, word: _wordWithDef('alpha', _mainWordCn));

    expect(find.text('页面出错了'), findsNothing);
    expect(find.byType(DictionaryPage), findsOneWidget);
    // TabBar 六个标签正常渲染（此前整个标签区都是错误占位块）
    expect(find.text('柯林斯'), findsOneWidget);
    expect(find.text('派生'), findsOneWidget);
    // 释义区块读到当前词的数据（此前整个区块都是错误占位块）
    expect(find.textContaining(_mainWordCn), findsWidgets);
  });

  testWidgets('REG-DICT-002: 派生词跳转创建全新 DetailState，不再复用上一词数据', (tester) async {
    // 症状：词典页点派生词/近义词跳转后，新词头配旧词释义（数据错配）；
    // 根因：跳转用 ChangeNotifierProvider.value 复用同一 DetailState 实例，
    //       而该实例只 loadWord 过主词。
    // 修复：commit 305113b —— 跳转直接 push DictionaryPage，新页自建全新 scope。
    // 修复前：点击时 context.read 即抛 ProviderNotFound（与 REG-DICT-001 同源），
    //         即使不抛，释义区也只会显示主词数据。
    const mainWord = 'alpha';
    const derivedWord = 'alphabetism';
    await _pumpDictionaryPage(
      tester,
      word: _wordWithDef(mainWord, _mainWordCn),
      derived: [_wordWithDef(derivedWord, _derivedWordCn)],
    );

    // 切到「派生」标签并点击派生词条目
    await tester.tap(find.text('派生'));
    await tester.pumpAndSettle();
    expect(find.text(derivedWord), findsOneWidget);
    await tester.tap(find.text(derivedWord));
    await tester.pumpAndSettle();

    // 新页面栈顶是派生词的词典页，且释义是派生词自己的数据
    expect(find.text(derivedWord), findsOneWidget);
    expect(find.textContaining(_derivedWordCn), findsWidgets);
    expect(find.textContaining(_mainWordCn), findsNothing, reason: '新词页不得再显示上一词的释义（数据错配）');
  });

  testWidgets('REG-DICT-003: 例句 tab 渲染解析后的例句而非裸 JSON，真题 tab 读扩展数据', (tester) async {
    // 症状：词典详情页「例句」tab 显示整段原始 JSON（{"fid":...,"sid":...,"e":...}），
    //       「真题」tab 与例句 tab 内容完全相同（双写）；
    // 根因：ServiceDictionaryContentReader.getExamExamples 把 word.example 的结构化
    //       JSON 当纯文本 split('\n') 逐行塞进例句列表，未走 ExampleParser；
    //       真题 tab 复用同一 state.examExamples，dictionary_extra.json 真题零消费。
    // 修复：v2.7.45 —— getExamExamples 统一走 ExampleParser（单一事实来源）；
    //       真题 tab 改读 getRealExamSentences（dictionary_extra.json）；
    //       例句卡复用 ExampleTile（高亮/发音/句收藏/来源）。
    const examplePlainText = 'Anyone can download the free app.';
    await _pumpDictionaryPage(
      tester,
      word: _wordWithDef('app', _mainWordCn),
      examples: [
        ExampleSentence(
          en: 'Anyone can <b>download</b> the free <b>app</b>.',
          cn: '任何人都可以免费下载这款应用。',
          source: 'VOA慢速-科技报道',
          audioUrl: 'https://audio.beingfine.cn/sentence/audio/9025550003604481.mp3',
        ),
      ],
      realExamSentences: [
        {'sentence': 'The new programming language makes it easier to write apps.', 'source': 'CET-4'},
      ],
    );

    // 例句 tab：渲染解析后的句子（<b> 已转为高亮 span），无裸 JSON 字段
    await tester.tap(find.text('例句'));
    await tester.pumpAndSettle();
    expect(find.textContaining(examplePlainText, findRichText: true), findsOneWidget);
    expect(find.textContaining('"fid"'), findsNothing, reason: '例句区不得出现原始 JSON 字段（乱码根因）');
    expect(find.textContaining('{"v":1'), findsNothing);
    expect(find.text('VOA慢速-科技报道'), findsOneWidget, reason: '例句来源应随 ExampleTile 展示');

    // 真题 tab：读 dictionary_extra 真数据并带来源徽章，不再与例句双写
    await tester.tap(find.text('真题'));
    await tester.pumpAndSettle();
    expect(find.textContaining('The new programming language'), findsOneWidget);
    expect(find.text('CET-4'), findsOneWidget);
    expect(find.textContaining(examplePlainText), findsNothing, reason: '真题 tab 不得再复用例句数据（双写）');
  });

  testWidgets('REG-DICT-005: 派生/近义 tab 卡片化（MwCard + 发音按钮），空状态统一图标化', (tester) async {
    // 症状：派生/近义 tab 仍是裸 GestureDetector 卡片（无按压反馈、无阴影、
    //       两 tab 圆角还不一致 lg/xl），空状态是旧式「标题+灰字」灰盒，
    //       与已精致化的柯林斯/例句/真题 tab 风格割裂；
    // 修复：v2.7.47 —— 两 tab 统一 MwCard（24px 圆角 + 双层阴影 +
    //       ScaleDownOnPress 按压反馈），空状态统一 _emptyTab，
    //       派生卡带音标时显示发音按钮（与页头同款 accent 淡底）。
    await _pumpDictionaryPage(
      tester,
      word: _wordWithDef('alpha', _mainWordCn),
      derived: [
        Word(
          word: 'alphabetism',
          interpret: '[{"t":"n.","def":[{"en":"eng","cn":"$_derivedWordCn"}]}]',
          usPron: 'ˌælfəˈbetɪzəm',
        ),
        Word(word: 'alphabetical', interpret: '[{"t":"adj.","def":[{"en":"eng","cn":"字母表的"}]}]'),
      ],
    );

    // 派生 tab：MwCard 卡片 + 有音标的词条带发音按钮 + 导航箭头仍在
    await tester.tap(find.text('派生'));
    await tester.pumpAndSettle();
    expect(find.byType(MwCard), findsWidgets, reason: '派生词条目必须用 MwCard 卡片化，不得回退裸 Container');
    // 页头发音按钮 + 有音标派生词的卡片发音按钮 = 2 个 volume_up
    expect(find.byIcon(Icons.volume_up), findsNWidgets(2), reason: '有音标的派生词应显示发音按钮（页头另有一个）');
    expect(find.text('ˌælfəˈbetɪzəm'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_forward_ios), findsWidgets);

    // 近义 tab 空状态：统一 _emptyTab 图标化，不再是旧式标题灰盒
    await tester.tap(find.text('近义'));
    await tester.pumpAndSettle();
    expect(find.text('暂无近义词'), findsOneWidget);
    expect(find.text('近义词'), findsNothing, reason: '旧式空状态灰盒（标题「近义词」）已废弃');
  });

  testWidgets('REG-DOCK-001: FloatingDock.clearance = 底部安全区 + 16 margin + 64 栏高', (tester) async {
    // 症状：词书选择页底部工具栏与主壳悬浮 Dock 完全重叠；
    // 根因：MainShell 将 Dock 悬浮于内容之上（安全区上方 + 16 margin + 64 栏高），
    //       页面底部固定内容未预留该高度。
    // 修复：commit 305113b —— FloatingDock.clearance 作为单一事实来源，
    //       页面底部固定内容（lib_select 工具栏等）必须预留此值。
    // 本测试锁定 clearance 契约：MainShell 定位与 Dock 自身边距任一变化，
    // 必须同步调整此测试与所有预留点。
    double? clearance;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(padding: EdgeInsets.only(bottom: 12)),
        child: Builder(
          builder: (context) {
            clearance = FloatingDock.clearance(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    expect(clearance, 12 + 16 + 64);
  });
}
