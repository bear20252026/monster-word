// 由 Claude 团队生成 | 移植自 v3.2 lock/LangView.java
// 锁屏 View 接口

/// 锁屏 View 接口，定义锁屏 UI 更新方法
abstract class LockView {
  /// 初始化单词显示
  void initWord(Map<String, dynamic> wordProcess);

  /// 加载例句数据
  /// [sentences] 例句数据列表
  /// [examples] 例句 HTML 数组
  /// [mp3Paths] 音频路径数组
  /// [word] 当前单词
  void loadExampleData(List<Map<String, dynamic>> sentences, List<String> examples, List<String> mp3Paths, String word);

  /// 例句加载完成
  void loadExampleFinish(Map<String, dynamic> wordProcess);

  /// 设置是否正在加载例句
  void setProcessingExample(bool processing);

  /// 显示指定位置的例句
  void showExampleItemAt(int index);

  /// 更新日期时间显示
  /// [time] 时间字符串
  /// [dateCn] 中文日期
  /// [dateEn] 英文日期
  void updateDateTime(String time, String dateCn, String dateEn);

  /// 更新电量显示
  /// [isCharging] 是否充电中
  /// [percent] 电量百分比
  void updatePower(bool isCharging, int percent);
}
