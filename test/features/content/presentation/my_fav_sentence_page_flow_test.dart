// 句库页（收藏例句）FlowIn 有序流动入场复用测试（与词书网格/单词浏览页同一动效语言）
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:word_app/features/content/presentation/my_fav_sentence_page.dart';
import 'package:word_app/features/word_browse/application/sentence_favorites_store.dart';
import 'package:word_app/models/sentence_models.dart';

class _FakeStore implements SentenceFavoritesStore {
  _FakeStore(this.sentences);

  final List<FavSentenceData> sentences;

  @override
  Future<List<FavSentenceData>> list() async => sentences;

  @override
  Future<List<FavSentenceData>> listPage({required int limit, int offset = 0}) async =>
      sentences.skip(offset).take(limit).toList();

  @override
  Future<int> count() async => sentences.length;

  @override
  Future<bool> remove({required int wordId, required String sentenceId}) async => false;

  @override
  Future<int> removeBatch({required List<({int wordId, String sentenceId})> items}) async => 0;

  @override
  Future<bool> isFavorite({required int wordId, required String sentenceId}) async => false;

  @override
  Future<bool> toggle({
    required int wordId,
    required String sentenceId,
    required String english,
    required String chinese,
    String source = '',
    String word = '',
  }) async => true;
}

FavSentenceData _fav(int wordId, String word, String en, String cn) => FavSentenceData(
  word: word,
  wordId: wordId,
  sentenceId: 'sid-$en',
  sentenceData: SentenceData(sid: 'sid-$en', e: en, c: cn, b: '例句来源'),
  updateTime: '20260928120000',
);

Widget _host(List<FavSentenceData> sentences, {bool disableAnimations = false}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: disableAnimations),
      child: Provider<SentenceFavoritesStore>.value(value: _FakeStore(sentences), child: const MyFavSentencePage()),
    ),
  );
}

Finder _cardOpacity(int wordId, String en) =>
    find.descendant(of: find.byKey(ValueKey('fav-sentence-flow-$wordId-sid-$en')), matching: find.byType(Opacity));

void main() {
  testWidgets('例句卡按索引波次入场：靠后的卡起跑更晚，最终完全呈现', (tester) async {
    await tester.pumpWidget(
      _host([
        _fav(1, 'apple', 'An apple a day.', '一天一苹果。'),
        _fav(2, 'banana', 'I like bananas.', '我喜欢香蕉。'),
        _fav(3, 'cherry', 'Cherries are red.', '樱桃是红的。'),
      ]),
    );
    // frame0: 加载中 → _loadData 完成 → 列表帧（FlowIn 起点态）
    await tester.pump();
    await tester.pump();
    await tester.pump();

    // 入场起点：各卡均不可见（波次尚未起跑）
    expect(tester.widgetList<Opacity>(_cardOpacity(1, 'An apple a day.')).first.opacity, lessThan(0.05));
    expect(tester.widgetList<Opacity>(_cardOpacity(3, 'Cherries are red.')).first.opacity, lessThan(0.05));

    // 120ms：第 1 卡已起步，第 3 卡（波次 2，70ms 起跑）刚开始
    await tester.pump(const Duration(milliseconds: 120));
    final first = tester.widgetList<Opacity>(_cardOpacity(1, 'An apple a day.')).first.opacity;
    final third = tester.widgetList<Opacity>(_cardOpacity(3, 'Cherries are red.')).first.opacity;
    expect(first, greaterThan(third));
    expect(third, greaterThan(0));

    await tester.pumpAndSettle();
    expect(tester.widgetList<Opacity>(_cardOpacity(3, 'Cherries are red.')).first.opacity, 1.0);
    expect(find.text('Cherries are red.'), findsOneWidget);
  });

  testWidgets('减弱动态效果时例句卡直接呈现最终态（无 Opacity 包裹）', (tester) async {
    await tester.pumpWidget(_host([_fav(1, 'apple', 'An apple a day.', '一天一苹果。')], disableAnimations: true));
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(find.text('An apple a day.'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('fav-sentence-flow-1-sid-An apple a day.')),
        matching: find.byType(Opacity),
      ),
      findsNothing,
    );
  });
}
