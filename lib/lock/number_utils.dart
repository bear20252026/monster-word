// 由 Claude 团队生成 | 移植自 v3.2 lock/NumberUtils.java
// 数字格式化工具

class NumberUtils {
  /// 数字前补零（0-9 补一位）
  static String zeroAdd(int i) {
    if (i > 9) {
      return i.toString();
    }
    return '0$i';
  }
}
