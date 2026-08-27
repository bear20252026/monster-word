// 由 Claude 团队生成 | Monster Word App
// 依赖注入容器 — 使用 get_it 实现服务定位器模式

import 'package:get_it/get_it.dart';

import '../../data/user_database.dart';
import '../../data/wordbook_database.dart';
import '../../repositories/book_repository.dart';
import '../../repositories/book_repository_impl.dart';
import '../../repositories/word_repository.dart';
import '../../repositories/word_repository_impl.dart';
import '../../repositories/user_repository.dart';
import '../../repositories/user_repository_impl.dart';
import '../../repositories/note_repository.dart';
import '../../repositories/note_repository_impl.dart';
import '../../repositories/fav_repository.dart';
import '../../repositories/fav_repository_impl.dart';
import '../../repositories/mastered_repository.dart';
import '../../repositories/mastered_repository_impl.dart';
import '../../repositories/new_word_repository.dart';
import '../../repositories/new_word_repository_impl.dart';
import '../../services/learn_service.dart';
import '../../services/learn_service_impl.dart';
import '../../services/review_service.dart';
import '../../services/review_service_impl.dart';
import '../../services/audio_service.dart';
import '../../services/audio_service_impl.dart';
import '../../services/checkin_service.dart';
import '../../services/checkin_service_impl.dart';
import '../../services/user_service.dart';
import '../../services/user_service_impl.dart';
import '../../services/stats_service.dart';
import '../../services/stats_service_impl.dart';
import '../../repositories/stats_repository.dart';
import '../../repositories/stats_repository_impl.dart';
import '../../features/learning/application/book_words_reader.dart';
import '../../features/learning/data/learning_progress_repository.dart';
import '../../features/learning/data/learning_queue_repository.dart';
import '../../features/learning/data/review_schedule_repository.dart';
import '../../features/learning/application/mastered_words_reader.dart';
import '../../features/learning/application/new_words_reader.dart';
import '../../features/learning/application/review_audio_player.dart';
import '../../features/learning/application/review_queue_reader.dart';
import '../../features/learning/presentation/new_words_state.dart';
import '../../state/learn_state.dart';
import '../../state/review_state.dart';
import '../../state/user_stats_state.dart';
import '../../state/settings_state.dart';
import '../../state/player_state.dart';

/// 全局服务定位器实例
final GetIt sl = GetIt.instance;

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
/// final learnService = sl<LearnService>();
/// ```
Future<void> setupServiceLocator() async {
  // ========== Data Layer（数据层）==========
  // 数据库单例（只注册一次）
  if (!sl.isRegistered<WordBookDatabase>()) {
    sl.registerLazySingleton<WordBookDatabase>(() => WordBookDatabase.instance);
  }
  if (!sl.isRegistered<UserDatabase>()) {
    sl.registerLazySingleton<UserDatabase>(() => UserDatabase.instance);
  }

  // ========== Repository Layer（仓库层）==========
  // BookRepository
  if (!sl.isRegistered<BookRepository>()) {
    sl.registerLazySingleton<BookRepository>(() => BookRepositoryImpl(sl<WordBookDatabase>()));
  }

  // WordRepository
  if (!sl.isRegistered<WordRepository>()) {
    sl.registerLazySingleton<WordRepository>(() => WordRepositoryImpl(sl<WordBookDatabase>()));
  }

  // UserRepository
  if (!sl.isRegistered<UserRepository>()) {
    sl.registerLazySingleton<UserRepository>(() => UserRepositoryImpl());
  }

  // NoteRepository
  if (!sl.isRegistered<NoteRepository>()) {
    sl.registerLazySingleton<NoteRepository>(() => NoteRepositoryImpl());
  }

  // FavRepository
  if (!sl.isRegistered<FavRepository>()) {
    sl.registerLazySingleton<FavRepository>(() => FavRepositoryImpl());
  }

  // MasteredRepository
  if (!sl.isRegistered<MasteredRepository>()) {
    sl.registerLazySingleton<MasteredRepository>(() => MasteredRepositoryImpl());
  }

  // NewWordRepository
  if (!sl.isRegistered<NewWordRepository>()) {
    sl.registerLazySingleton<NewWordRepository>(() => NewWordRepositoryImpl(sl<UserDatabase>()));
  }

  // BookWordsReader
  if (!sl.isRegistered<BookWordsReader>()) {
    sl.registerLazySingleton<BookWordsReader>(() => BookWordsReader(wordRepository: sl<WordRepository>()));
  }

  // MasteredWordsReader
  if (!sl.isRegistered<MasteredWordsReader>()) {
    sl.registerLazySingleton<MasteredWordsReader>(
      () => MasteredWordsReader(masteredRepository: sl<MasteredRepository>(), wordRepository: sl<WordRepository>()),
    );
  }

  // NewWordsReader
  if (!sl.isRegistered<NewWordsReader>()) {
    sl.registerLazySingleton<NewWordsReader>(
      () => NewWordsReader(newWordRepository: sl<NewWordRepository>(), wordRepository: sl<WordRepository>()),
    );
  }

  // NewWordsState
  if (!sl.isRegistered<NewWordsState>()) {
    sl.registerLazySingleton<NewWordsState>(() => NewWordsState(newWordRepository: sl<NewWordRepository>()));
  }

  // ReviewQueueReader
  if (!sl.isRegistered<ReviewQueueReader>()) {
    sl.registerLazySingleton<ReviewQueueReader>(() => ReviewQueueReader(wordRepository: sl<WordRepository>()));
  }

  // LearningQueueRepository（遗留学习会话队列加载命令边界）
  if (!sl.isRegistered<LearningQueueWordSource>()) {
    sl.registerLazySingleton<LearningQueueWordSource>(
      () => WordBookLearningQueueWordSource(database: sl<WordBookDatabase>()),
    );
  }
  if (!sl.isRegistered<LearningQueueRepository>()) {
    sl.registerLazySingleton<LearningQueueRepository>(
      () => LearningQueueRepository(wordSource: sl<LearningQueueWordSource>(), favRepository: sl<FavRepository>()),
    );
  }

  // LearningProgressRepository（遗留学习会话进度持久化边界）
  if (!sl.isRegistered<LearningProgressRepository>()) {
    sl.registerLazySingleton<LearningProgressRepository>(() => LearningProgressRepository());
  }

  // ReviewScheduleRepository（正式复习 FSRS 调度与评分事实来源）
  if (!sl.isRegistered<ReviewScheduleRepository>()) {
    sl.registerLazySingleton<ReviewScheduleRepository>(() => ReviewScheduleRepository());
  }

  // ========== Service Layer（服务层）==========
  // AudioService（音频播放）
  if (!sl.isRegistered<AudioService>()) {
    sl.registerLazySingleton<AudioService>(() => AudioServiceImpl());
  }

  // ReviewAudioPlayer / ReviewAudioState（正式复习发音边界）
  if (!sl.isRegistered<ReviewAudioPlayer>()) {
    sl.registerLazySingleton<ReviewAudioPlayer>(
      () => ReviewAudioPlayer(playAudio: (word) => sl<AudioService>().playWordAudio(word)),
    );
  }

  // LearnService（学习流程）
  if (!sl.isRegistered<LearnService>()) {
    sl.registerLazySingleton<LearnService>(
      () => LearnServiceImpl(
        wordRepo: sl<WordRepository>(),
        audioService: sl<AudioService>(),
        favRepo: sl<FavRepository>(),
      ),
    );
  }

  // ReviewService（复习流程）
  if (!sl.isRegistered<ReviewService>()) {
    sl.registerLazySingleton<ReviewService>(
      () => ReviewServiceImpl(wordRepo: sl<WordRepository>(), audioService: sl<AudioService>()),
    );
  }

  // CheckInService（签到）
  if (!sl.isRegistered<CheckInService>()) {
    sl.registerLazySingleton<CheckInService>(() => CheckInServiceImpl(userRepo: sl<UserRepository>()));
  }

  // UserService（用户）
  if (!sl.isRegistered<UserService>()) {
    sl.registerLazySingleton<UserService>(
      () => UserServiceImpl(userRepo: sl<UserRepository>(), noteRepo: sl<NoteRepository>()),
    );
  }

  // StatsService（学习统计）
  if (!sl.isRegistered<StatsService>()) {
    sl.registerLazySingleton<StatsService>(() => StatsServiceImpl(userRepo: sl<UserRepository>()));
  }

  // StatsRepository（统计数据仓库）
  if (!sl.isRegistered<StatsRepository>()) {
    sl.registerLazySingleton<StatsRepository>(() => StatsRepositoryImpl(statsService: sl<StatsService>()));
  }

  // ========== ViewModel Layer（视图模型层）==========
  // LearnState（学习状态）
  if (!sl.isRegistered<LearnState>()) {
    sl.registerLazySingleton<LearnState>(
      () => LearnState(
        learnService: sl<LearnService>(),
        audioService: sl<AudioService>(),
        favRepository: sl<FavRepository>(),
      ),
    );
  }

  // ReviewState（复习状态）
  if (!sl.isRegistered<ReviewState>()) {
    sl.registerLazySingleton<ReviewState>(() => ReviewState(reviewService: sl<ReviewService>()));
  }

  // UserStatsState（用户统计状态）
  if (!sl.isRegistered<UserStatsState>()) {
    sl.registerLazySingleton<UserStatsState>(() => UserStatsState(statsService: sl<StatsService>()));
  }

  // SettingsState（设置状态）
  if (!sl.isRegistered<SettingsState>()) {
    sl.registerLazySingleton<SettingsState>(() => SettingsState());
  }

  // PlayerState（播放状态）
  if (!sl.isRegistered<PlayerState>()) {
    sl.registerLazySingleton<PlayerState>(() => PlayerState(audioService: sl<AudioService>()));
  }
}

/// 释放所有可释放资源（在应用退出时调用）
Future<void> disposeServiceLocator() async {
  if (sl.isRegistered<AudioService>()) {
    sl<AudioService>().dispose();
  }
  await sl.reset();
}

/// 重置所有注册（用于测试）
Future<void> resetServiceLocator() async {
  await sl.reset();
}
