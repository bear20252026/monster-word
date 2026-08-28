// 由 Claude 团队生成 | Monster Word App
//
// 共享模型层 — 尖叫币流水值对象
//
// ScareCoinEntry 是纯粹的领域模型，不依赖任何基础设施或框架，
// 仅描述一条尖叫币流水的事实（时间、变动量、原因）。因其被多个 feature
// （account / checkin / scare_coin）与 legacy 页面共享，故下沉至共享 models，
// 使各 feature 仅依赖 lib/models 而非 scare_coin 内部。
class ScareCoinEntry {
  final DateTime time;
  final int delta;
  final String reason;

  ScareCoinEntry({required this.time, required this.delta, required this.reason});

  Map<String, dynamic> toJson() => {'t': time.millisecondsSinceEpoch, 'd': delta, 'r': reason};

  factory ScareCoinEntry.fromJson(Map<String, dynamic> json) => ScareCoinEntry(
    time: DateTime.fromMillisecondsSinceEpoch(json['t'] as int),
    delta: json['d'] as int,
    reason: json['r'] as String,
  );
}
