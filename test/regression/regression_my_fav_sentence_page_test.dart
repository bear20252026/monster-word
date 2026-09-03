// ============================================================
// 回归测试 — 句库页（REG-CONTENT-xxx）
// 规则：每个 REG-ID 对应一个已修复问题，测试永久保留。
// 台账：docs/regression_ledger.md
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:word_app/features/content/presentation/my_fav_sentence_page.dart';
import 'package:word_app/features/word_browse/application/sentence_favorites_store.dart';
import 'package:word_app/models/sentence_models.dart';
import 'package:word_app/widgets/mw_card.dart';

class _FakeStore implements SentenceFavoritesStore {
  _FakeStore(this.sentences);

  final List<FavSentenceData> sentences;

  @override
  Future<List<FavSentenceData>> list() async => sentences;

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

FavSentenceData _fav(String word, String en, String cn, String source) => FavSentenceData(
  word: word,
  wordId: word.hashCode,
  sentenceId: 'sid-$en',
  sentenceData: SentenceData(sid: 'sid-$en', e: en, c: cn, b: source),
  updateTime: '20260903120000',
);

// onGenerateRoute 捕获的最近一次 push 路由名（导航契约断言用）
String? _lastPushedRoute;

Future<void> _pumpPage(WidgetTester tester, List<FavSentenceData> sentences) async {
  _lastPushedRoute = null;
  await tester.pumpWidget(
    MaterialApp(
      onGenerateRoute: (settings) {
        _lastPushedRoute = settings.name;
        return MaterialPageRoute(builder: (_) => const SizedBox.shrink());
      },
      home: Provider<SentenceFavoritesStore>.value(value: _FakeStore(sentences), child: const MyFavSentencePage()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('REG-CONTENT-001: 句库页卡片 MwCard 化 + 编辑态选中/导航契约保持', (tester) async {
    // 问题：句库页例句卡片是裸 GestureDetector+Container（无按压反馈/无阴影，
    //       选中态靠 2px 描边），与词典详情页 ExampleTile/MwCard 风格割裂——
    //       而此页正是 v2.7.45 例句收藏功能（ExampleTile ♡）的落点页。
    // 修复：v2.7.48 —— 卡片升级 MwCard（24px 圆角 + 双层阴影 + 按压反馈），
    //       选中态改 primary 淡底 + 行首 check_circle；非编辑态点击仍 push
    //       RouteNames.sentenceDetail（导航契约不变）。
    await _pumpPage(tester, [
      _fav('app', 'Anyone can download the free app.', '任何人都可以免费下载这款应用。', 'VOA慢速'),
      _fav('book', 'She read a book last night.', '她昨晚读了一本书。', 'CET-4'),
    ]);

    // 卡片化锁定：两条例句 = 两个 MwCard，不得回退裸 Container
    expect(find.byType(MwCard), findsNWidgets(2));
    expect(find.text('Anyone can download the free app.'), findsOneWidget);
    expect(find.text('She read a book last night.'), findsOneWidget);
    expect(find.text('共 2 个例句'), findsOneWidget);

    // 编辑态：进入编辑 → 点击卡片 → 行首出现 check_circle（选中淡底生效）
    await tester.tap(find.text('编辑'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.radio_button_unchecked), findsNWidgets(2));
    await tester.tap(find.text('Anyone can download the free app.'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.check_circle), findsOneWidget, reason: '编辑态点击卡片应选中（MwCard 化后不得丢失）');
    expect(find.byIcon(Icons.radio_button_unchecked), findsOneWidget);

    // 退出编辑态后点击卡片 → 导航契约保持：push sentenceDetail 且带例句参数
    await tester.tap(find.text('完成'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('She read a book last night.'));
    await tester.pumpAndSettle();
    final pushedRoute = _lastPushedRoute;
    expect(pushedRoute, '/sentence_detail', reason: '非编辑态点击卡片仍应跳例句详情页');
  });
}
