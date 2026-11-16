// 尖叫币功能域聚合门面（结构修复步骤4，2026-11-16）。
//
// 原上帝端口拆为 4 个窄端口（CoinLedger/CheckInCalendar/ProtectionCard/
// AnswerReward），本门面 implements 四者、成员签名零改动——既有消费方与测试
// 假件（implements ScareCoinStore）零破坏；新消费方应按需依赖窄端口。
// 实现类仍 implements ScareCoinStore ⇒ 自动满足四窄端口，共享串行闸/降级/
// 时钟回拨水位的单实例不被拆散。
import 'package:word_app/features/scare_coin/application/answer_reward.dart';
import 'package:word_app/features/scare_coin/application/check_in_calendar.dart';
import 'package:word_app/features/scare_coin/application/coin_ledger.dart';
import 'package:word_app/features/scare_coin/application/protection_card.dart';
import 'package:word_app/models/scare_coin_entry.dart';

/// 尖叫币功能域的读写聚合门面（共享 core 契约）。
///
/// 尖叫币账本与签到历史保持独立事实模型；本端口不依赖学习、复习或账号状态。
/// 该契约被 account / checkin 等多个 feature 及 legacy 页面共享，故提升到核心层。
/// 新代码请优先依赖窄端口（[CoinLedger]/[CheckInCalendar]/[ProtectionCard]/
/// [AnswerReward]），仅在确实需要跨组能力时用本门面。
abstract interface class ScareCoinStore implements CoinLedger, CheckInCalendar, ProtectionCard, AnswerReward {
  @override
  int get checkInReward;

  @override
  Future<int> balance();

  @override
  Future<Set<String>> checkinDates();

  @override
  Future<int> streak();

  @override
  Future<List<ScareCoinEntry>> history();

  @override
  Future<String> lastCheckInDate();

  @override
  bool isSameDay(String isoDate, DateTime time);

  @override
  Future<int?> checkIn();

  @override
  Future<int?> makeupYesterday();

  @override
  Future<int> grant({required int delta, required String reason});

  @override
  Future<int?> grantOnce({required int delta, required String reason, required String eventKey});

  @override
  int get protectionCap;

  @override
  Future<int> protectionCount();

  @override
  Future<int> addProtection({required int count, required String reason});

  @override
  int get answerRewardDailyCap;

  @override
  Future<int> grantAnswerReward();
}
