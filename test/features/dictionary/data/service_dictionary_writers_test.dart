// 第四轮审计 M1/M2（2026-11-17）：词典域写适配器装配收口回归。
//
// M1：收藏写路径必须经 LearningFavoritesStore 共享快照（写后通知），
//     此前直写 FavRepository 绕过 learning/search/book/content 消费的内存
//     快照且无刷新调用——词典页收藏后其他域星标陈旧。
// M2：生词适配器必须消费 DI 单例仓储——此前自建第二实例，实例级
//     _toggleQueue 串行闸与学习域互不互斥，并发双击 check-then-act 复活。
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:word_app/core/infrastructure/user_database.dart';
import 'package:word_app/core/repositories/new_word_id_cache.dart';
import 'package:word_app/core/repositories/new_word_repository_impl.dart';
import 'package:word_app/features/dictionary/data/service_dictionary_favorite_writer.dart';
import 'package:word_app/features/dictionary/data/service_dictionary_new_word_writer.dart';
import 'package:word_app/features/learning/application/favorites_port.dart';
import 'package:word_app/features/learning/presentation/learning_favorites_state.dart';
import 'package:word_app/models/word.dart';

import '../../../helpers/fake_learning_queue_port.dart';

// ── M1 桩：内存收藏端口（队列端口用 helpers 共享 FakeLearningQueuePort）──

class _MemFavoritesPort implements FavoritesPort {
  final Set<String> words = {};

  @override
  Future<Set<String>> getFavoriteWords() async => Set.of(words);

  @override
  Future<void> toggleFavorite(String word) async {
    if (!words.remove(word)) words.add(word);
  }

  @override
  bool isFavorite(String word) => words.contains(word);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('M1 词典收藏写经共享状态源', () {
    test('toggle 后 Store 快照即时更新且发出通知（search/book 订阅方可见）', () async {
      final port = _MemFavoritesPort();
      final store = LearningFavoritesState(favoritesPort: port, queuePort: FakeLearningQueuePort());
      addTearDown(store.dispose);
      // 构造期 refresh 是异步的：等首载完成。
      await store.refresh();

      final writer = ServiceDictionaryFavoriteWriter(favoritesStore: store);
      var notifications = 0;
      store.addListener(() => notifications++);

      expect(store.isFavorite('alpha'), isFalse);
      final added = await writer.toggleFavorite('alpha');

      expect(added, isTrue);
      // 关键断言：共享快照（而非仅 DB）已更新——其他域 isFavorite 即时可见。
      expect(store.isFavorite('alpha'), isTrue);
      expect(writer.isFavorite('alpha'), isTrue);
      expect(notifications, greaterThan(0), reason: '写后必须 notifyListeners，watch/select 订阅方才刷新');

      final removed = await writer.toggleFavorite('alpha');
      expect(removed, isFalse);
      expect(store.isFavorite('alpha'), isFalse);
    });

    test('空白词形拒写且不通知', () async {
      final store = LearningFavoritesState(favoritesPort: _MemFavoritesPort(), queuePort: FakeLearningQueuePort());
      addTearDown(store.dispose);
      await store.refresh();
      final writer = ServiceDictionaryFavoriteWriter(favoritesStore: store);
      expect(await writer.toggleFavorite('   '), isFalse);
      expect(store.favoriteWords, isEmpty);
    });

    test('getFavoriteWords 返回 Store 快照视图（与收藏页同源）', () async {
      final port = _MemFavoritesPort()..words.add('beta');
      final store = LearningFavoritesState(favoritesPort: port, queuePort: FakeLearningQueuePort());
      addTearDown(store.dispose);
      await store.refresh();
      final writer = ServiceDictionaryFavoriteWriter(favoritesStore: store);
      expect(await writer.getFavoriteWords(), {'beta'});
    });
  });

  group('M2 生词写共享 DI 单例串行闸', () {
    setUpAll(() {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    test('适配器与学习域共用同一仓储：并发双击终态为未加入（双实例则复活竞态）', () async {
      final db = await databaseFactory.openDatabase(inMemoryDatabasePath);
      await db.execute('''
        CREATE TABLE new_words (
          word_id INTEGER PRIMARY KEY,
          word_text TEXT NOT NULL,
          source TEXT NOT NULL DEFAULT 'manual',
          operation_code TEXT NOT NULL DEFAULT 'add',
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          synced_at INTEGER
        )
      ''');
      addTearDown(() => db.close());

      // 生产装配口径：组合根单例（service_locator M2 注册）注入适配器。
      final repo = NewWordRepositoryImpl(UserDatabase.instance, databaseOverride: db);
      final writer = ServiceDictionaryNewWordWriter(repository: repo);
      // 唯一 id：NewWordIdCache 是进程级静态单例，跨用例残留会污染缓存断言。
      final word = Word(id: 987654, word: 'gamma', interpret: '[]');
      // 预热共享缓存（生产首查同款路径），排除冷启动空缓存干扰。
      await NewWordIdCache.instance.ensureLoaded(repo);

      // 词典域（经适配器）与学习域（经同一 DI 单例）同时 toggle 同一词。
      // 共享实例级 _toggleQueue：两次 toggle 严格串行 → 一次 add 一次 remove，
      // 终态未加入。若适配器自建第二实例（修复前），两把闸并行，两个
      // check-then-act 都读到「未加入」都走 add，终态停在已加入——本断言即红。
      final results = await Future.wait([writer.toggleNewWord(word), repo.toggleNewWord(word)]);

      // 入队先后受微任务调度影响（适配器 async 体先挂起），不锁结果顺序；
      // 判别字段是「恰好一次加入一次移除」+ DB 终态。
      expect(results.toSet(), {true, false}, reason: '串行闸下必须一次加入、一次移除');
      expect(await repo.isNewWord(word.id), isFalse, reason: '并发双击终态必须是未加入');
      // 共享 ID 缓存与 DB 终态一致（I34 口径）。
      expect(NewWordIdCache.instance.contains(word.id), isFalse);
    });
  });
}
