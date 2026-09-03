// 由 Claude 团队生成 | Monster Word App

// 紧凑时间串格式化工具（L2 收口：句库页与笔记区此前各自手写 substring 解析）
//
// 输入为词库/收藏记录的紧凑时间串（yyyyMMdd / yyyyMMddHHmmss），
// 解析失败或长度不足时降级返回空串/原文，不抛异常。

/// 句库列表用：yyyyMMdd → MM/dd（长度不足返回空串）
String formatMonthDay(String compact) {
  if (compact.length < 8) return '';
  try {
    final month = compact.substring(4, 6);
    final day = compact.substring(6, 8);
    return '$month/$day';
  } catch (_) {
    return '';
  }
}

/// 笔记区用：yyyyMMddHHmmss → yyyy-MM-dd HH:mm（长度不足时返回原文）
String formatCompactDateTime(String compact) {
  if (compact.length < 14) return compact;
  return '${compact.substring(0, 4)}-${compact.substring(4, 6)}-${compact.substring(6, 8)} '
      '${compact.substring(8, 10)}:${compact.substring(10, 12)}';
}
