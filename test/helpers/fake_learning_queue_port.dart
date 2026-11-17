// 第四轮审计 M10（2026-11-17）：LearningQueuePort 共享可配置假件。
//
// 此前同一端口在 13 个测试文件各有一套 implements——端口每演进一次要改
// 13 处，漏改即假绿（Dart implements 不继承默认方法，第二轮已实测踩坑）。
// 现收敛为单套：
//   - 默认零行为（空队列），覆盖 10 处 no-op 桩；
//   - 注入 words 即「返回固定词表 + shuffle/limit 语义」，覆盖 3 处词表桩；
//   - favoriteWords 可注入（默认空），供收藏会话测试。
// 带记录/阻塞/Completer 门控的变体属于被测行为的一部分，仍留在各自测试
// 文件内（helpers/fakes.dart 头注释同款口径）——本假件只收敛「同构」部分。
import 'package:word_app/features/learning/application/learning_queue_port.dart';
import 'package:word_app/models/book.dart';
import 'package:word_app/models/word.dart';

class FakeLearningQueuePort implements LearningQueuePort {
  FakeLearningQueuePort({this.words = const [], this.favoriteWords = const []});

  /// 注入的固定词表（loadBook 返回它，shuffle/limit 语义与真实适配器一致）。
  final List<Word> words;

  /// 注入的收藏词表（loadFavoriteWords 返回它；默认空）。
  final List<Word> favoriteWords;

  /// loadBook 调用记录（供需要断言调用参数的测试消费；不强制）。
  final List<({Book book, int? limit, bool shuffle})> loadBookCalls = [];

  @override
  Future<List<Word>> loadBook(Book book, {int? limit, required bool shuffle}) async {
    loadBookCalls.add((book: book, limit: limit, shuffle: shuffle));
    final queue = List<Word>.from(words);
    if (shuffle) queue.shuffle();
    return (limit == null || limit >= queue.length) ? queue : queue.sublist(0, limit);
  }

  @override
  Future<List<Word>> loadFavoriteWords({required List<Word> currentQueue}) async => List<Word>.from(favoriteWords);
}
