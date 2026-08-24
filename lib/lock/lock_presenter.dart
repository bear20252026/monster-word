// 由 Claude 团队生成 | 移植自 v3.2 lock/LockPresenter.java
// 锁屏 Presenter 接口

import 'dart:ui' as ui;

/// 锁屏 Presenter 接口，定义锁屏学习的业务逻辑
abstract class LockPresenter {
  /// 初始化（注册广播接收器等）
  void init();

  /// 销毁（注销广播接收器等）
  void destroy();

  /// 获取背景图片 [正常背景, 模糊背景]
  List<ui.Image?> getBackground(String? imageId);

  /// 更新电量显示
  void updatePower();

  /// 更新日期时间显示
  void updateDateTime();

  /// 设置是否可以播放例句
  void setCanPlayExample(bool canPlay);

  /// 自动播放例句
  /// [index] 例句索引
  /// [forcePlay] 是否强制播放
  /// [mp3Path] 音频路径
  void autoPlayExample(int index, bool forcePlay, String mp3Path);

  /// 切换例句播放/暂停
  void togglePlayExample(int index, bool forcePlay, String mp3Path);

  /// 是否可以显示锁屏
  bool canShowLock();

  /// 切换音标类型（英式/美式）
  void changePhoneticType();

  /// 暂停音频
  void pauseAudio();

  /// 解锁并进入学习页面
  void unlockToLearn();

  /// 自动播放单词发音
  /// [forcePlay] 是否强制播放
  /// [delayMs] 延迟播放毫秒数
  void autoPlayWordAudio(bool forcePlay, int delayMs);

  /// 切换到下一个单词
  void nextWord();
}
