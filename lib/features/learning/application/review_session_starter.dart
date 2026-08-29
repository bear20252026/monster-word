import 'package:word_app/features/learning/application/review_queue_reader.dart';

/// 正式复习会话初始化命令。
typedef ReviewSessionInitializer = Future<void> Function(ReviewQueueSnapshot snapshot);

/// 正式复习会话启动结果。
enum ReviewSessionStartResult { ready, failed }

/// 正式复习会话启动协调器。
///
/// 队列快照由页面组合层提供，会话状态负责保存加载阶段和异常；本协调器只确保
/// 启动异步任务不会把已处理的加载错误作为未捕获页面异常再次抛出。
class ReviewSessionStarter {
  const ReviewSessionStarter({required this._snapshot, required this._initialize});

  final ReviewQueueSnapshot _snapshot;
  final ReviewSessionInitializer _initialize;

  Future<ReviewSessionStartResult> start() async {
    try {
      await _initialize(_snapshot);
      return ReviewSessionStartResult.ready;
    } catch (_) {
      return ReviewSessionStartResult.failed;
    }
  }
}
