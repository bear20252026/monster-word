// 由 Claude 团队生成 | 移植自 v3.2 events/ 学习相关事件
// 学习模块事件：签到、卡片操作、学习卡片选项、单词列表变更
import '../models/bb_word_process.dart';

// ============================================================
// CheckInEvent — 签到事件
// 原版：events/CheckInEvent.java
// 触发源：签到模块 → 监听者：主界面
// ============================================================
class CheckInEvent {
  final String checkDate;
  const CheckInEvent({required this.checkDate});
}

// ============================================================
// CheckReWardEvent — 检查奖励事件
// 原版：events/CheckReWardEvent.java（空类，仅作信号）
// 触发源：任务模块 → 监听者：奖励模块
// ============================================================
class CheckReWardEvent {
  const CheckReWardEvent();
}

// ============================================================
// CardActionEvent — 卡片操作事件
// 原版：events/CardActionEvent.java
// 触发源：卡片模块 → 监听者：主界面
// 字段：action (CardAction)
// ============================================================
class CardActionEvent {
  final CardAction action;
  const CardActionEvent({required this.action});
}

/// 卡片动作类型（对应原版 bean/CardAction）
enum CardActionType {
  unknown,
  flip,       // 翻卡片
  next,       // 下一个
  previous,   // 上一个
  know,       // 认识
  dontKnow,   // 不认识
  skip,       // 跳过
  collect,    // 收藏
  playAudio,  // 播放发音
}

/// 卡片动作数据
class CardAction {
  final CardActionType type;
  final int? cardId;
  final Object? extra;

  const CardAction({required this.type, this.cardId, this.extra});
}

// ============================================================
// LearnCardOptionEvent — 学习卡片选项操作
// 原版：events/LearnCardOptionEvent.java
// 触发源：学习卡片 → 监听者：学习模块
// 选项类型：更多词根、单词详情、打开面板、点击例句、显示例句
// ============================================================
class LearnCardOptionEvent {
  static const int optionMoreRoot = 1;
  static const int optionWordDetail = 2;
  static const int optionOpenWordPanel = 3;
  static const int optionClickSentence = 4;
  static const int optionDisplaySentence = 5;

  final int type;
  final Object? extraData;
  final Object? extraData2;

  const LearnCardOptionEvent({
    required this.type,
    this.extraData,
    this.extraData2,
  });
}

// ============================================================
// WordListChangedEvent — 单词列表变更事件
// 原版：events/WordListChangedEvent.java
// 触发源：单词模块 → 监听者：列表界面
// ============================================================
class WordListChangedEvent {
  static const int typeLearnRecord = 1;
  static const int typeNewWord = 2;

  final int type;
  const WordListChangedEvent({required this.type});
}

// ============================================================
// WordSimplePopPanelDismissEvent — 简义弹窗关闭事件
// 原版：events/WordSimplePopPanelDismissEvent.java（空类，仅作信号）
// 触发源：弹窗模块 → 监听者：学习模块
// ============================================================
class WordSimplePopPanelDismissEvent {
  const WordSimplePopPanelDismissEvent();
}
