import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import 'package:word_app/app/service_locator.dart';
import 'package:word_app/core/audio/audio_service.dart';
import 'package:word_app/core/repositories/word_repository.dart';
import 'package:word_app/features/learning/application/learning_favorites_store.dart';
import 'package:word_app/features/learning/application/learning_progress_reader.dart';
import 'package:word_app/features/learning/application/learning_session_reader.dart';
import 'package:word_app/features/learning/application/learning_session_starter.dart';
import 'package:word_app/features/learning/application/learning_collections_reader.dart';
import 'package:word_app/features/learning/application/learning_statistics_reader.dart';
import 'package:word_app/features/learning/application/new_words_store.dart';
import 'package:word_app/features/learning/application/book_words_reader.dart';
import 'package:word_app/features/learning/application/mastered_words_reader.dart';
import 'package:word_app/features/learning/application/new_words_reader.dart';
import 'package:word_app/features/learning/application/review_audio_player.dart';
import 'package:word_app/features/learning/application/review_queue_reader.dart';
import 'package:word_app/features/learning/application/review_schedule_reader.dart';
import 'package:word_app/features/learning/application/review_rating_writer.dart';
import 'package:word_app/features/learning/application/learning_queue_port.dart';
import 'package:word_app/features/learning/application/learning_progress_port.dart';
import 'package:word_app/features/learning/application/review_schedule_writer_port.dart';
import 'package:word_app/features/learning/application/choice_generator_port.dart';
import 'package:word_app/features/learning/application/favorites_port.dart';
import 'package:word_app/features/learning/application/mastered_writer_port.dart';
import 'package:word_app/features/learning/application/new_words_writer_port.dart';
import 'package:word_app/features/learning/data/learning_progress_reader_impl.dart';
import 'package:word_app/features/learning/data/learning_progress_repository.dart';
import 'package:word_app/features/learning/data/learning_queue_repository.dart';
import 'package:word_app/features/learning/data/review_schedule_repository.dart';
import 'package:word_app/features/learning/data/repository_review_schedule_reader.dart';
import 'package:word_app/features/learning/data/repository_learning_queue_port.dart';
import 'package:word_app/features/learning/data/repository_learning_progress_port.dart';
import 'package:word_app/features/learning/data/repository_review_schedule_writer_port.dart';
import 'package:word_app/features/learning/data/repository_choice_generator_port.dart';
import 'package:word_app/features/learning/data/repository_favorites_port.dart';
import 'package:word_app/features/learning/data/repository_mastered_writer_port.dart';
import 'package:word_app/features/learning/data/repository_new_words_writer_port.dart';
import 'package:word_app/features/learning/presentation/learning_session_starter_impl.dart';
import 'package:word_app/features/learning/presentation/learning_collections_state.dart';
import 'package:word_app/features/learning/presentation/learning_favorites_state.dart';
import 'package:word_app/features/learning/presentation/learning_mastered_state.dart';
import 'package:word_app/features/learning/presentation/learning_queue_state.dart';
import 'package:word_app/features/learning/presentation/learning_queue_word_lists_state.dart';
import 'package:word_app/features/learning/presentation/learning_session_state.dart';
import 'package:word_app/features/learning/presentation/learning_statistics_state.dart';
import 'package:word_app/features/learning/presentation/new_words_state.dart';
import 'package:word_app/features/learning/presentation/review_audio_state.dart';
import 'package:word_app/features/learning/presentation/review_queue_state.dart';
import 'package:word_app/features/learning/presentation/review_session_state.dart';
import 'package:word_app/features/learning/presentation/review_word_actions_state.dart';

/// 学习功能域的根 Provider 装配。
///
/// 按原有顺序保留依赖关系和生命周期：正式复习调度仓储先于遗留兼容状态创建，
/// 评分端口先于正式复习会话创建。应用根仅组合功能域装配，不感知学习功能内部的
/// Provider 类型或迁移细节。
Widget buildLearningFeatureScope({required Widget child}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<ReviewScheduleRepository>.value(value: sl<ReviewScheduleRepository>()),
      ChangeNotifierProvider<ReviewScheduleReader>(
        create: (_) => RepositoryReviewScheduleReader(repository: sl<ReviewScheduleRepository>()),
      ),
      Provider<LearningQueuePort>.value(value: RepositoryLearningQueuePort(sl<LearningQueueRepository>())),
      Provider<LearningProgressPort>.value(value: RepositoryLearningProgressPort(sl<LearningProgressRepository>())),
      Provider<ReviewScheduleWriterPort>.value(
        value: RepositoryReviewScheduleWriterPort(sl<ReviewScheduleRepository>()),
      ),
      Provider<ChoiceGeneratorPort>.value(value: const RepositoryChoiceGeneratorPort()),
      Provider<FavoritesPort>.value(value: RepositoryFavoritesPort.fromServiceLocator()),
      Provider<MasteredWriterPort>.value(value: RepositoryMasteredWriterPort.fromServiceLocator()),
      Provider<NewWordsWriterPort>.value(value: RepositoryNewWordsWriterPort.fromServiceLocator()),
      ChangeNotifierProvider(
        create: (context) => LearningFavoritesState(
          favoritesPort: context.read<FavoritesPort>(),
          queuePort: context.read<LearningQueuePort>(),
        ),
      ),
      // 以 core 契约类型暴露同一实例：search / book 等消费方仅依赖
      // lib/core/learning 的 LearningFavoritesStore，不触 learning/presentation。
      ListenableProxyProvider<LearningFavoritesState, LearningFavoritesStore>(update: (_, state, _) => state),
      ChangeNotifierProvider(
        create: (context) => LearningMasteredState(
          masteredWordsReader: sl<MasteredWordsReader>(),
          writerPort: context.read<MasteredWriterPort>(),
        ),
      ),
      ChangeNotifierProvider(
        create: (context) => LearningSessionState(
          queuePort: context.read<LearningQueuePort>(),
          progressPort: context.read<LearningProgressPort>(),
          reviewSchedulePort: context.read<ReviewScheduleWriterPort>(),
          choicePort: context.read<ChoiceGeneratorPort>(),
        ),
      ),
      ProxyProvider<LearningSessionState, LearningSessionStarter>(
        update: (_, session, _) => LearningSessionStarterImpl(session),
      ),
      ProxyProvider<LearningSessionState, LearningSessionReader>(
        update: (_, session, _) => LearningSessionStarterImpl(session),
      ),
      ChangeNotifierProxyProvider<LearningSessionState, LearningQueueState>(
        create: (_) => LearningQueueState(),
        update: (_, session, queue) => (queue ?? LearningQueueState())..synchronizeFrom(session),
      ),
      ChangeNotifierProxyProvider2<LearningQueueState, ReviewScheduleReader, LearningStatisticsState>(
        create: (_) => LearningStatisticsState(),
        update: (_, queue, schedule, statistics) =>
            (statistics ?? LearningStatisticsState())..synchronize(queue: queue.snapshot, schedule: schedule),
      ),
      // 只读统计端口：暴露给其它 feature（如 word_browse 的 foot_mark）读取统计。
      // 装配为具体状态实现 core 只读契约，消费方经类型注入依赖 core，而非 learning/presentation。
      ListenableProxyProvider<LearningStatisticsState, LearningStatisticsReader>(update: (_, state, _) => state),
      ChangeNotifierProxyProvider2<LearningFavoritesState, LearningMasteredState, LearningCollectionsState>(
        create: (_) => LearningCollectionsState(),
        update: (_, favorites, mastered, collections) =>
            (collections ?? LearningCollectionsState())..synchronize(favorites: favorites, mastered: mastered),
      ),
      // 只读集合端口：暴露给其它 feature（如 content 的 my_content_page、word_browse 的
      // foot_mark）读取收藏/掌握数量，消费方依赖 core 而非 learning/presentation。
      ListenableProxyProvider<LearningCollectionsState, LearningCollectionsReader>(update: (_, state, _) => state),
      ChangeNotifierProxyProvider2<LearningQueueState, ReviewScheduleReader, LearningQueueWordListsState>(
        create: (_) => LearningQueueWordListsState(),
        update: (_, queue, schedule, wordLists) =>
            (wordLists ?? LearningQueueWordListsState())..synchronize(queue: queue.snapshot, schedule: schedule),
      ),
      ChangeNotifierProxyProvider2<LearningQueueState, ReviewScheduleReader, ReviewQueueState>(
        create: (_) => ReviewQueueState(),
        update: (_, queue, schedule, reviewQueue) =>
            (reviewQueue ?? ReviewQueueState())..synchronize(queue: queue.snapshot, schedule: schedule),
      ),
      ProxyProvider<ReviewScheduleRepository, ReviewRatingWriter>(
        update: (_, schedule, _) => ReviewRatingWriter(writeRating: schedule.rateWord),
      ),
      ChangeNotifierProxyProvider<ReviewRatingWriter, ReviewSessionState>(
        create: (context) =>
            ReviewSessionState(queueReader: sl<ReviewQueueReader>(), ratingWriter: context.read<ReviewRatingWriter>()),
        update: (_, ratingWriter, session) =>
            (session ?? ReviewSessionState(queueReader: sl<ReviewQueueReader>(), ratingWriter: ratingWriter))
              ..updateRatingWriter(ratingWriter),
      ),
      ChangeNotifierProvider(
        create: (context) => ReviewWordActionsState(
          favoritesPort: context.read<FavoritesPort>(),
          masteredReader: sl<MasteredWordsReader>(),
          masteredWriter: context.read<MasteredWriterPort>(),
        )..initialize(),
      ),
      ChangeNotifierProvider(create: (_) => ReviewAudioState(audioPlayer: sl<ReviewAudioPlayer>())),
      Provider<BookWordsReader>.value(value: sl<BookWordsReader>()),
      Provider<MasteredWordsReader>.value(value: sl<MasteredWordsReader>()),
      Provider<NewWordsReader>.value(value: sl<NewWordsReader>()),
      Provider<ReviewQueueReader>.value(value: sl<ReviewQueueReader>()),
      // core 基础设施转发（页面经 Provider 通道消费，禁止直取 sl<>——A3 收口）
      Provider<AudioService>.value(value: sl<AudioService>()),
      Provider<WordRepository>.value(value: sl<WordRepository>()),
      Provider<LearningProgressReader>.value(value: LearningProgressReaderImpl.fromServiceLocator()),
      ChangeNotifierProvider(
        create: (_) =>
            NewWordsState(newWordsReader: sl<NewWordsReader>(), writerPort: sl<NewWordsWriterPort>())..initialize(),
      ),
      ListenableProxyProvider<NewWordsState, NewWordsStore>(update: (_, state, _) => state),
    ],
    child: child,
  );
}
