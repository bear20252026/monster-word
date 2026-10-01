// 由 Claude 团队生成 | Monster Word App
// 依赖注入容器 — 使用 get_it 实现服务定位器模式

import 'dart:async';

import 'package:get_it/get_it.dart';

import 'package:word_app/core/infrastructure/user_database.dart';
import 'package:word_app/core/infrastructure/wordbook_database.dart';
import 'package:word_app/features/book/data/book_repository.dart';
import 'package:word_app/features/book/data/book_repository_impl.dart';
import 'package:word_app/core/repositories/word_repository.dart';
import 'package:word_app/core/repositories/word_repository_impl.dart';
import 'package:word_app/core/repositories/user_repository.dart';
import 'package:word_app/core/repositories/user_repository_impl.dart';
import 'package:word_app/core/repositories/note_repository.dart';
import 'package:word_app/core/repositories/note_repository_impl.dart';
import 'package:word_app/core/repositories/fav_repository.dart';
import 'package:word_app/core/repositories/fav_repository_impl.dart';
import 'package:word_app/features/learning/data/mastered_repository.dart';
import 'package:word_app/features/learning/data/mastered_repository_impl.dart';
import 'package:word_app/core/repositories/new_word_repository.dart';
import 'package:word_app/core/repositories/new_word_repository_impl.dart';
import 'package:word_app/core/audio/audio_service.dart';
import 'package:word_app/core/audio/audio_service_impl.dart';
import 'package:word_app/core/audio/system_tts.dart';
import 'package:word_app/features/account/data/user_service.dart';
import 'package:word_app/features/account/data/user_service_impl.dart';
import 'package:word_app/features/learning/data/learning_progress_repository.dart';
import 'package:word_app/features/learning/data/repository_mastered_words_reader.dart';
import 'package:word_app/features/learning/data/repository_new_words_reader.dart';
import 'package:word_app/features/learning/data/repository_review_queue_reader.dart';
import 'package:word_app/features/learning/data/learning_queue_repository.dart';
import 'package:word_app/features/learning/data/review_schedule_repository.dart';
import 'package:word_app/features/learning/application/mastered_words_reader.dart';
import 'package:word_app/features/learning/application/new_words_reader.dart';
import 'package:word_app/features/learning/application/new_words_writer_port.dart';
import 'package:word_app/features/learning/application/review_audio_player.dart';
import 'package:word_app/features/learning/application/review_queue_reader.dart';
import 'package:word_app/features/learning/data/repository_new_words_writer_port.dart';

/// 全局服务定位器实例
final GetIt sl = GetIt.instance;

/// 幂等注册（审计 I9）：已注册则跳过，消灭 20 组 if-register 样板。
/// setupServiceLocator 在测试中被重复调用时不会重复注册。
void _reg<T extends Object>(T Function() factory) {
  if (!sl.isRegistered<T>()) {
    sl.registerLazySingleton<T>(factory);
  }
}

/// 注册所有依赖
///
/// 在 main() 中调用，必须在 runApp() 之前完成。
///
/// 使用方式：
/// ```dart
/// void main() {
///   setupServiceLocator();
///   runApp(const MyApp());
/// }
///
/// // 在需要的地方获取服务：
/// final reviewSchedule = sl<ReviewScheduleRepository>();
/// ```
Future<void> setupServiceLocator() async {
  // ========== Data Layer（数据层）==========
  // 数据库单例（只注册一次）
  _reg<WordBookDatabase>(() => WordBookDatabase.instance);
  _reg<UserDatabase>(() => UserDatabase.instance);

  // ========== Repository Layer（仓库层）==========
  // BookRepository
  _reg<BookRepository>(() => BookRepositoryImpl(sl<WordBookDatabase>()));

  // WordRepository
  _reg<WordRepository>(() => WordRepositoryImpl(sl<WordBookDatabase>()));

  // UserRepository
  _reg<UserRepository>(() => UserRepositoryImpl());

  // NoteRepository
  _reg<NoteRepository>(() => NoteRepositoryImpl());

  // FavRepository
  _reg<FavRepository>(() => FavRepositoryImpl());

  // MasteredRepository
  _reg<MasteredRepository>(() => MasteredRepositoryImpl());

  // NewWordRepository
  _reg<NewWordRepository>(() => NewWordRepositoryImpl(sl<UserDatabase>()));

  // MasteredWordsReader
  _reg<MasteredWordsReader>(
    () => RepositoryMasteredWordsReader(
      masteredRepository: sl<MasteredRepository>(),
      wordRepository: sl<WordRepository>(),
    ),
  );

  // NewWordsReader
  _reg<NewWordsReader>(
    () => RepositoryNewWordsReader(newWordRepository: sl<NewWordRepository>(), wordRepository: sl<WordRepository>()),
  );

  // NewWordsWriterPort
  _reg<NewWordsWriterPort>(() => RepositoryNewWordsWriterPort(sl<NewWordRepository>()));

  // ReviewQueueReader
  _reg<ReviewQueueReader>(() => const RepositoryReviewQueueReader());

  // LearningQueueRepository（遗留学习会话队列加载命令边界）
  _reg<LearningQueueWordSource>(() => WordBookLearningQueueWordSource(database: sl<WordBookDatabase>()));
  _reg<LearningQueueRepository>(
    () => LearningQueueRepository(wordSource: sl<LearningQueueWordSource>(), favRepository: sl<FavRepository>()),
  );

  // LearningProgressRepository（遗留学习会话进度持久化边界）
  _reg<LearningProgressRepository>(() => LearningProgressRepository());

  // ReviewScheduleRepository（正式复习 FSRS 调度与评分事实来源）
  _reg<ReviewScheduleRepository>(() => ReviewScheduleRepository());

  // ========== Service Layer（服务层）==========
  // AudioService（音频播放）
  _reg<AudioService>(() => AudioServiceImpl());

  // ReviewAudioPlayer / ReviewAudioState（正式复习发音边界）
  _reg<ReviewAudioPlayer>(() => ReviewAudioPlayer(playAudio: (word) => sl<AudioService>().playWordAudio(word)));

  // UserService（用户）
  _reg<UserService>(() => UserServiceImpl(userRepo: sl<UserRepository>(), noteRepo: sl<NoteRepository>()));
}

/// 释放所有可释放资源（在应用退出时调用）
///
/// 测试可 await：只 dispose AudioService + sl.reset，不引入 Timer/平台挂起。
/// 生产关窗请额外调用 [disposePlatformSingletons]。
Future<void> disposeServiceLocator() async {
  if (sl.isRegistered<AudioService>()) {
    try {
      sl<AudioService>().dispose();
    } catch (_) {}
  }
  await sl.reset();
}

/// 生产 detach 专用：释放平台单例（TTS / FSRS SQLite）。测试环境勿 await。
void disposePlatformSingletons() {
  unawaited(() async {
    try {
      await SystemTts().dispose();
    } catch (_) {}
    try {
      if (sl.isRegistered<ReviewScheduleRepository>()) {
        await sl<ReviewScheduleRepository>().close();
      }
    } catch (_) {}
  }());
}

/// 重置所有注册（用于测试）
Future<void> resetServiceLocator() async {
  await sl.reset();
}
