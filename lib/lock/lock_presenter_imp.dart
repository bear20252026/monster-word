// 由 Claude 团队生成 | 移植自 v3.2 lock/LockPresenterImp.java
// 锁屏 Presenter 实现

import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import 'date_time_constants.dart';
import 'lock_presenter.dart';
import 'number_utils.dart';

/// 锁屏 Presenter 实现类
/// 负责锁屏学习的业务逻辑：单词切换、音频播放、电量/时间更新等
class LockPresenterImp implements LockPresenter {
  static const String _tag = 'LockPresenterImp';

  final dynamic context; // BuildContext 或 Platform channel
  final dynamic lockView; // LockView 实例

  // 单词数据
  dynamic _wordProcess; // BBWordProcess
  final Map<String, int> _wordSentenceIndex = {};
  bool _canPlay = false;
  bool _isExtensiveListeningPlaying = false;

  // 计数器
  int _count = -1;

  // 定时器
  Timer? _timeTickTimer;
  Timer? _batteryTimer;

  // 示例处理器
  final int _exampleProcessorMode = 1;

  LockPresenterImp(this.context, this.lockView);

  @override
  void init() {
    // 每分钟更新时间
    _timeTickTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      updateDateTime();
    });
    // 初始更新
    updateDateTime();
    // 每5分钟更新电量
    _batteryTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      updatePower();
    });
    updatePower();
  }

  @override
  void destroy() {
    _timeTickTimer?.cancel();
    _batteryTimer?.cancel();
  }

  @override
  List<ui.Image?> getBackground(String? imageId) {
    // TODO: 从本地资源或缓存加载背景图片
    // 返回 [正常背景, 模糊背景]
    return [null, null];
  }

  @override
  void updatePower() {
    // TODO: 通过 Platform Channel 获取电池信息
    // 模拟数据
    final isCharging = false;
    final percent = 85;
    _notifyUpdatePower(isCharging, percent);
  }

  void _notifyUpdatePower(bool isCharging, int percent) {
    try {
      (lockView as dynamic).updatePower(isCharging, percent);
    } catch (e) {
      debugPrint('$_tag: updatePower error: $e');
    }
  }

  @override
  void updateDateTime() {
    final now = DateTime.now();
    final month = now.month;
    final day = now.day;
    final weekday = now.weekday; // 1=Monday, 7=Sunday
    final hour = now.hour;
    final minute = now.minute;

    // weekday 转换：DateTime.weekday 1=Monday, 7=Sunday
    // 原版 weekday 1=Sunday, 7=Saturday
    final weekdayIndex = weekday % 7; // 0=Sunday, 6=Saturday

    final time = '${NumberUtils.zeroAdd(hour)}:${NumberUtils.zeroAdd(minute)}';
    final dateCn = '${month}月$day日 ${DateTimeConstants.weekdayCn[weekdayIndex]}';
    final dateEn =
        '${DateTimeConstants.monthEn[month - 1]} $day ${DateTimeConstants.weekdayEn[weekdayIndex]}';

    try {
      (lockView as dynamic).updateDateTime(time, dateCn, dateEn);
    } catch (e) {
      debugPrint('$_tag: updateDateTime error: $e');
    }
  }

  @override
  void setCanPlayExample(bool canPlay) {
    _canPlay = canPlay;
  }

  @override
  void autoPlayExample(int index, bool forcePlay, String mp3Path) {
    if (_wordProcess == null || !_canPlay) return;

    _wordSentenceIndex[_getWord(_wordProcess)] = index;

    if (forcePlay) {
      _playExample(mp3Path);
    } else if (_getAutoPlay()) {
      _playExample(mp3Path);
    }
  }

  @override
  void togglePlayExample(int index, bool forcePlay, String mp3Path) {
    // TODO: 检查是否正在播放
    // if (SentenceAudioPlayer.isPlaying()) {
    //   pauseAudio();
    // } else {
    //   autoPlayExample(index, true, mp3Path);
    // }
    autoPlayExample(index, true, mp3Path);
  }

  @override
  bool canShowLock() {
    // TODO: 检查用户设置和未完成单词列表
    // return UserPreferences.getBoolean(UserPreferences.ENABLE_LOCK_SCREEN, true)
    //     && getUnFinishedWords().isNotEmpty;
    return true;
  }

  @override
  void changePhoneticType() {
    // TODO: 切换音标类型并刷新显示
    // AppPreferences.save(AppPreferences.PRONOUNCE, !AppPreferences.getBoolean(AppPreferences.PRONOUNCE));
    // autoPlayWordAudio(true, 0);
    // lockView.initWord(_wordProcess);
  }

  @override
  void pauseAudio() {
    // TODO: 暂停音频播放
    // SentenceAudioPlayer.pause();
    // PhoneticAudioPlayer.pause();
  }

  @override
  void unlockToLearn() {
    // TODO: 解锁并跳转到学习页面
    // 通过 Platform Channel 启动 MainActivity
  }

  @override
  void autoPlayWordAudio(bool forcePlay, int delayMs) {
    if (_wordProcess == null) return;

    if (forcePlay) {
      _playWordAudio(delayMs);
    } else if (_getAutoPlay()) {
      _playWordAudio(delayMs);
    }
  }

  /// 加载下一个单词
  void nextWord() {
    _count++;
    _loadCurrentWord();
  }

  /// 加载上一个单词
  void prevWord() {
    if (_count > 0) {
      _count--;
      _loadCurrentWord();
    }
  }

  void _loadCurrentWord() {
    // TODO: 从 LeitnerCard 获取未完成单词列表
    // final unFinishedWords = getUnFinishedWords();
    // if (unFinishedWords.isEmpty) return;
    // final wordProcess = unFinishedWords[_count % unFinishedWords.length];
    // _displayWord(wordProcess);
  }

  void _displayWord(dynamic wordProcess) {
    _wordProcess = wordProcess;
    _initExample(_getExample(_wordProcess), _getWord(_wordProcess));
    try {
      (lockView as dynamic).initWord(_wordProcess);
    } catch (e) {
      debugPrint('$_tag: displayWord error: $e');
    }
  }

  void _playExample(String mp3Path) {
    // TODO: 播放例句音频
    // SentenceAudioPlayer.playAudio(mp3Path);
  }

  void _playWordAudio(int delayMs) {
    if (_wordProcess == null) return;

    if (delayMs > 0) {
      Timer(Duration(milliseconds: delayMs), () {
        _doPlayWordAudio();
      });
    } else {
      _doPlayWordAudio();
    }
  }

  void _doPlayWordAudio() {
    // TODO: 播放单词发音
    // PhoneticAudioPlayer.playAudio(_getWord(_wordProcess));
  }

  void _initExample(String? exampleHtml, String? word) {
    if (exampleHtml == null || word == null) return;

    // TODO: 在后台线程处理例句数据
    // 1. 解析例句 HTML
    // 2. 提取英文/中文文本
    // 3. 生成 WebView HTML
    // 4. 回调 UI 更新
  }

  // 辅助方法：从 wordProcess Map 中获取字段
  String _getWord(dynamic wp) {
    if (wp is Map) return wp['word'] ?? '';
    try {
      return (wp as dynamic).getWord();
    } catch (_) {
      return '';
    }
  }

  String? _getExample(dynamic wp) {
    if (wp is Map) return wp['example'];
    try {
      return (wp as dynamic).getExample();
    } catch (_) {
      return null;
    }
  }

  bool _getAutoPlay() {
    // TODO: 从 UserPreferences 获取自动播放设置
    return true;
  }
}
