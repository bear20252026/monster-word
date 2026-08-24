// 由 Claude 团队生成 | 移植自 v3.2 events/ 日历相关事件
// 日历模块事件：添加日历事件

// ============================================================
// AddCalendarEvent — 添加日历事件
// 原版：events/AddCalendarEvent.java
// 触发源：学习模块 → 监听者：日历模块
// 字段：events (日历事件列表), extraData, extraData2
// ============================================================
class AddCalendarEvent {
  final List<CalendarEventData> events;
  final Object? extraData;
  final Object? extraData2;

  const AddCalendarEvent({
    required this.events,
    this.extraData,
    this.extraData2,
  });
}

/// 日历事件数据（对应原版 CalendarPresenter.CalendarEvent）
class CalendarEventData {
  final String? date;
  final String? title;
  final Object? extra;

  const CalendarEventData({this.date, this.title, this.extra});
}

// ============================================================
// CardActionClickInfo — 卡片动作点击信息
// 原版：events/AddCalendarEvent.CardActionClickInfo（内部类）
// ============================================================
class CardActionClickInfo {
  final int buttonType;
  final int cardId;

  const CardActionClickInfo({required this.buttonType, required this.cardId});
}
