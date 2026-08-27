import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../../core/di/service_locator.dart';
import '../../../repositories/fav_repository.dart';
import '../../../repositories/mastered_repository.dart';
import '../../../state/review_state.dart';
import '../application/book_words_reader.dart';
import '../application/mastered_words_reader.dart';
import '../application/new_words_reader.dart';
import '../application/review_audio_player.dart';
import '../application/review_queue_reader.dart';
import '../application/review_rating_writer.dart';
import '../data/learning_progress_repository.dart';
import '../data/learning_queue_repository.dart';
import '../data/review_schedule_repository.dart';
import 'learning_collections_state.dart';
import 'learning_favorites_state.dart';
import 'learning_mastered_state.dart';
import 'learning_queue_state.dart';
import 'learning_queue_word_lists_state.dart';
import 'learning_session_state.dart';
import 'learning_statistics_state.dart';
import 'new_words_state.dart';
import 'review_audio_state.dart';
import 'review_queue_state.dart';
import 'review_session_state.dart';
import 'review_word_actions_state.dart';

/// 学习功能域的根 Provider 装配。
///
/// 按原有顺序保留依赖关系和生命周期：正式复习调度仓储先于遗留兼容状态创建，
/// 评分端口先于正式复习会话创建。应用根仅组合功能域装配，不感知学习功能内部的
/// Provider 类型或迁移细节。
Widget buildLearningFeatureScope({required Widget child}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<ReviewScheduleRepository>.value(value: sl<ReviewScheduleRepository>()),
      Provider<LearningQueueRepository>.value(value: sl<LearningQueueRepository>()),
      ChangeNotifierProvider(
        create: (_) => LearningFavoritesState(
          favoriteRepository: sl<FavRepository>(),
          queueRepository: sl<LearningQueueRepository>(),
        ),
      ),
      ChangeNotifierProvider(create: (_) => LearningMasteredState(masteredRepository: sl<MasteredRepository>())),
      ChangeNotifierProvider(
        create: (_) => LearningSessionState(
          queueRepository: sl<LearningQueueRepository>(),
          progressRepository: sl<LearningProgressRepository>(),
          reviewSchedule: sl<ReviewScheduleRepository>(),
        ),
      ),
      ChangeNotifierProxyProvider<LearningSessionState, LearningQueueState>(
        create: (_) => LearningQueueState(),
        update: (_, session, queue) => (queue ?? LearningQueueState())..synchronizeFrom(session),
      ),
      ChangeNotifierProxyProvider2<LearningQueueState, ReviewScheduleRepository, LearningStatisticsState>(
        create: (_) => LearningStatisticsState(),
        update: (_, queue, schedule, statistics) =>
            (statistics ?? LearningStatisticsState())..synchronize(queue: queue.snapshot, schedule: schedule),
      ),
      ChangeNotifierProxyProvider2<LearningFavoritesState, LearningMasteredState, LearningCollectionsState>(
        create: (_) => LearningCollectionsState(),
        update: (_, favorites, mastered, collections) =>
            (collections ?? LearningCollectionsState())..synchronize(favorites: favorites, mastered: mastered),
      ),
      ChangeNotifierProxyProvider2<LearningQueueState, ReviewScheduleRepository, LearningQueueWordListsState>(
        create: (_) => LearningQueueWordListsState(),
        update: (_, queue, schedule, wordLists) =>
            (wordLists ?? LearningQueueWordListsState())..synchronize(queue: queue.snapshot, schedule: schedule),
      ),
      ChangeNotifierProxyProvider2<LearningQueueState, ReviewScheduleRepository, ReviewQueueState>(
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
        create: (_) =>
            ReviewWordActionsState(favRepository: sl<FavRepository>(), masteredRepository: sl<MasteredRepository>())
              ..initialize(),
      ),
      ChangeNotifierProvider(create: (_) => ReviewAudioState(audioPlayer: sl<ReviewAudioPlayer>())),
      Provider<BookWordsReader>.value(value: sl<BookWordsReader>()),
      Provider<MasteredWordsReader>.value(value: sl<MasteredWordsReader>()),
      Provider<NewWordsReader>.value(value: sl<NewWordsReader>()),
      Provider<ReviewQueueReader>.value(value: sl<ReviewQueueReader>()),
      ChangeNotifierProvider(create: (_) => sl<NewWordsState>()..initialize()),
      ChangeNotifierProvider(create: (_) => sl<ReviewState>()),
    ],
    child: child,
  );
}
