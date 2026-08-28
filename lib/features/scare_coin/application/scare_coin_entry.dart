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
