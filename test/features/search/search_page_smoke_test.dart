// 临时复现：SearchPage 在真实 provider 树下构建抛异常（错误边界"页面出错了"）
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:word_app/features/search/application/example_reader.dart';
import 'package:word_app/features/search/application/search_history_store.dart';
import 'package:word_app/features/search/application/word_search_reader.dart';
import 'package:word_app/features/search/data/example_parser_adapter.dart';
import 'package:word_app/features/search/presentation/search_page.dart';
import 'package:word_app/models/word.dart';
import 'package:word_app/models/book.dart';
import 'package:word_app/core/audio/audio_playback_state.dart';
import 'package:word_app/core/audio/audio_service.dart';
import 'package:word_app/features/learning/application/learning_favorites_store.dart';
import 'package:word_app/features/learning/presentation/learning_favorites_state.dart';
import 'package:word_app/features/learning/application/favorites_port.dart';
import 'package:word_app/features/learning/application/learning_queue_port.dart';

class _MockWordSearchReader implements WordSearchReader {
  @override
  Future<List<Word>> search(String query, {int? limit}) async => [];
}

class _MockHistoryStore implements SearchHistoryStore {
  @override
  List<String> read() => [];
  @override
  Future<void> add(String word) async {}
  @override
  Future<void> clear() async {}
}

class _MockFavoritesPort implements FavoritesPort {
  @override
  Future<Set<String>> getFavoriteWords() async => {};
  @override
  Future<void> toggleFavorite(String word) async {}
  @override
  bool isFavorite(String word) => false;
}

class _MockQueuePort implements LearningQueuePort {
  @override
  Future<List<Word>> loadBook(Book book, {int? limit, required bool shuffle}) async => [];
  @override
  Future<List<Word>> loadFavoriteWords({required List<Word> currentQueue}) async => [];
}

class _MockAudioService implements AudioService {
  @override
  Future<void> playWordAudio(String word, {String accent = 'us', String? audioUrl}) async {}
  @override
  Future<void> playFromUrl(String url) async {}
  @override
  Future<void> stop() async {}
  @override
  bool get isPlaying => false;
  @override
  void dispose() {}
}

void main() {
  testWidgets('SearchPage 在完整 provider 下正常渲染', (tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<WordSearchReader>(create: (_) => _MockWordSearchReader()),
          Provider<SearchHistoryStore>(create: (_) => _MockHistoryStore()),
          Provider<ExampleReader>(create: (_) => const ExampleParserAdapter()),
          ChangeNotifierProvider<LearningFavoritesState>(
            create: (_) => LearningFavoritesState(
              favoritesPort: _MockFavoritesPort(),
              queuePort: _MockQueuePort(),
            ),
          ),
          ListenableProxyProvider<LearningFavoritesState, LearningFavoritesStore>(
            update: (_, state, _) => state,
          ),
          ChangeNotifierProvider<AudioPlaybackState>(
            create: (_) => AudioPlaybackState(audioService: _MockAudioService()),
          ),
        ],
        child: const MaterialApp(home: SearchPage()),
      ),
    );
    // 跑马灯动画常驻，pumpAndSettle 会超时；固定 pump 验证渲染无异常
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(SearchPage), findsOneWidget);
    expect(find.text('输入要查询的英文或中文'), findsOneWidget);
  });
}
