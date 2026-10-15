// 使用统计的端口（application 层）。
//
// 为什么把「什么时候上报」这类判断放在 application 而不是直接写进 data 层：
// 它是有真实分支的业务规则（间隔、退避、补传、保留期），需要能被本机直接跑断言。
// 本仓 `flutter test` 受 365vpn 影响不可用，所以**纯 Dart 的 application/domain
// 能在本地真跑测试**这件事本身就是设计约束（见 lib/features/telemetry/README.md）。
//
// 本文件不得 import flutter/*。

import 'package:word_app/features/telemetry/domain/usage_daily_stats.dart';

/// 本地按天统计的读写。
abstract class UsageStatsStore {
  /// 读某天的统计；没有则返回 null。
  Future<UsageDailyStats?> readDay(String day);

  /// 覆盖写入某天。实现方需保证「读-改-写」在同一事务里，
  /// 否则前台时长与模块计数会互相覆盖。
  Future<void> writeDay(UsageDailyStats stats);

  /// 取出**尚未上报**且**有活动**的日子，按日期升序，最多 [limit] 条。
  Future<List<UsageDailyStats>> readPending({int limit});

  /// 标记这些天已上报。
  Future<void> markUploaded(Iterable<String> days);

  /// 删除 [before] 之前的已上报数据（保留期清理；未上报的不删，避免丢数据）。
  Future<void> pruneUploadedBefore(DateTime before);

  /// 上一次成功上报的时间；从未上报过返回 null。
  Future<DateTime?> readLastUploadAt();

  /// 记录一次成功上报。
  Future<void> writeLastUploadAt(DateTime at);

  /// 失败后的下次允许尝试时间（退避）；没有则返回 null。
  Future<DateTime?> readNextAttemptAt();

  /// 写入退避时间；传 null 清除。
  Future<void> writeNextAttemptAt(DateTime? at);

  /// 清空全部本地统计（含未上报的）。
  ///
  /// 用户把开关关掉时调用：既然承诺「关了就不收集」，就不该把关之前攒下的数据
  /// 留着等哪天又被打开。
  Future<void> clearAll();
}

/// 上报通道。
abstract class UsageStatsUploader {
  /// 上报一批数据。**返回是否成功**，实现方不得抛异常
  /// （上报失败不该影响任何用户可见行为）。
  Future<bool> upload(UsageStatsReport report);
}

/// 上报信封所需的运行环境信息（设备标识、版本、平台…）。
///
/// 做成端口而不是直接读 `Platform`/`package_info`：一是让 collector 保持纯 Dart，
/// 二是这些值在测试里必须可替换。
abstract class UsageStatsEnvironment {
  /// 稳定的随机设备标识（首次生成后持久化）。
  Future<String> deviceId();

  Future<String> appVersion();

  Future<int> appBuild();

  /// `windows` / `android` / `linux` / `macos`。
  String platform();

  /// 系统版本串。
  String osVersion();

  /// 界面语言，如 `zh_CN`。
  String locale();
}

/// 当前登录账号的服务端用户标识。
///
/// ⚠️ **这是「按人看」的前提，也是本功能隐私边界变化的分界线。**
/// 一旦上报带上它，数据就从「不可识别到个人的设备级统计」变成
/// 「可识别到个人的行为记录」—— 隐私披露必须同步写明（见 legal_documents.dart）。
/// 2026-10-14 业主明确要求管理端按人看，故加上；此前刻意不绑。
///
/// 返回 null 表示**没有可关联的账号**（本机模式，或尚未登录）。服务端把这种上报
/// 归到「未绑定账号」，不丢数据。
///
/// 只传 UUID 不传用户名：用户名的权威来源是账号服务，客户端再存一份必然漂移。
/// 管理页展示名字时由统计服务向账号服务解析。
abstract class UsageStatsIdentity {
  Future<String?> userId();
}

/// 开关（用户在设置里可改；默认值由编译期常量决定）。
abstract class UsageStatsSettings {
  Future<bool> isEnabled();

  Future<void> setEnabled(bool value);
}

/// 「更多设置」页需要的最小面：读开关状态 + 改开关。
///
/// 为什么单独抽一个窄接口，而不是让设置页直接读 [UsageStatsCollector]：
///   1. **架构守卫 R4 禁止跨 feature import 对方的 presentation 层**，只允许
///      import 对方的 application 层抽象。设置页属 settings feature，所以它只能
///      依赖这里（本文件即 application 层）。
///   2. 设置页并不需要 collector 的累计能力，只需要「读开关 / 改开关」两件事。
///      窄接口让测试可以给一个几行的假实现，不必拼出整套 store/uploader/env。
///
/// `UsageStatsCollector` 直接 implements 本接口（它本来就有这两个成员）。
/// 关掉开关时会连带清除本机未上报的统计 —— 那是 collector 的实现细节，
/// 调用方（设置页）不需要知道，但用户会看到那句提示。
abstract class UsageStatsController {
  bool get isEnabled;

  Future<void> setEnabled(bool value);
}

/// 业务侧埋点入口（窄接口）。
///
/// 为什么不让学习/词书/签到直接依赖 [UsageStatsCollector]：
///   1. 那些 feature 只需要「记一笔」，不需要上报调度、保留期、开关读写的全部能力；
///      窄接口让它们的测试给几行假实现即可（与 [UsageStatsController] 同一思路）。
///   2. 埋点契约集中在一处，将来加字段/改语义时改动面可控。
///
/// ⚠️ 实现方（`UsageStatsCollector`）在开关关闭时**全部空转**，调用方无需自行判断；
/// 调用方也不得在这里传任何词文本、搜索词等「学习内容」——那与隐私披露冲突
/// （见 lib/features/telemetry/README.md 与 legal_documents.dart）。
abstract class UsageStatsRecorder {
  /// 完成一个学习会话（学习页 / 正式复习页各算一次）。
  Future<void> recordStudySession();

  /// 记录一批答题结果。[reviewed] 是词次，[correct] 是其中答对的词次。
  Future<void> recordAnswers({required int reviewed, required int correct});

  /// 记录新学词数（累加）。
  Future<void> recordNewWordsLearned(int count);

  /// 同步当前词书的进度（覆盖写：它是状态量，不是累加量）。
  Future<void> syncBookProgress({required int wordCount, required int learned});

  /// 同步连续签到天数（覆盖写：状态量）。
  Future<void> syncStreak(int days);

  /// 记录获得的虚拟道具（尖叫币）数量（累加）。
  Future<void> recordCoinsEarned(int count);

  /// 打开某个模块，[module] 必须是 `UsageDailyStats.knownModules` 里的键。
  Future<void> recordModuleOpen(String module);
}
