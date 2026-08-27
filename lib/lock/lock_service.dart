// 由 Claude 团队生成 | 移植自 v3.2 lock/ActivityTaskService.java
// 锁屏服务 - Platform Channel 接口

import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

/// 锁屏服务，通过 Platform Channel 与原生 Android 通信
/// 实现锁屏显示、解锁、Activity 管理等功能
class LockService {
  static const MethodChannel _channel = MethodChannel('cn.com.langeasy.lock/service');

  static const EventChannel _eventChannel = EventChannel('cn.com.langeasy.lock/events');

  // === 锁屏控制 ===

  /// 显示锁屏
  static Future<bool> showLockScreen() async {
    try {
      final result = await _channel.invokeMethod('showLockScreen');
      return result == true;
    } on PlatformException catch (e) {
      debugPrint('LockService.showLockScreen error: ${e.message}');
      return false;
    }
  }

  /// 关闭锁屏
  static Future<void> closeLockScreen() async {
    try {
      await _channel.invokeMethod('closeLockScreen');
    } on PlatformException catch (e) {
      debugPrint('LockService.closeLockScreen error: ${e.message}');
    }
  }

  /// 解锁
  static Future<void> unlock() async {
    try {
      await _channel.invokeMethod('unlock');
    } on PlatformException catch (e) {
      debugPrint('LockService.unlock error: ${e.message}');
    }
  }

  // === Activity 管理 ===

  /// 将指定任务移到前台
  static Future<void> bringTaskToFront(int taskId, String className) async {
    try {
      await _channel.invokeMethod('bringTaskToFront', {'taskId': taskId, 'className': className});
    } on PlatformException catch (e) {
      debugPrint('LockService.bringTaskToFront error: ${e.message}');
    }
  }

  /// 确保启动指定 Activity
  static Future<void> ensureLaunchActivity(String packageName, String className, int flags) async {
    try {
      await _channel.invokeMethod('ensureLaunchActivity', {
        'packageName': packageName,
        'className': className,
        'flags': flags,
      });
    } on PlatformException catch (e) {
      debugPrint('LockService.ensureLaunchActivity error: ${e.message}');
    }
  }

  // === 系统信息 ===

  /// 获取电池信息
  /// 返回 {'isCharging': bool, 'percent': int}
  static Future<Map<String, dynamic>> getBatteryInfo() async {
    try {
      final result = await _channel.invokeMethod('getBatteryInfo');
      return Map<String, dynamic>.from(result);
    } on PlatformException catch (e) {
      debugPrint('LockService.getBatteryInfo error: ${e.message}');
      return {'isCharging': false, 'percent': 0};
    }
  }

  /// 检查是否有运行中的主 Activity
  /// 返回任务 ID，-1 表示未找到
  static Future<int> getBringTaskId() async {
    try {
      final result = await _channel.invokeMethod('getBringTaskId');
      return result as int? ?? -1;
    } on PlatformException catch (e) {
      debugPrint('LockService.getBringTaskId error: ${e.message}');
      return -1;
    }
  }

  // === 音频播放 ===

  /// 播放单词发音
  static Future<void> playWordAudio(String word) async {
    try {
      await _channel.invokeMethod('playWordAudio', {'word': word});
    } on PlatformException catch (e) {
      debugPrint('LockService.playWordAudio error: ${e.message}');
    }
  }

  /// 播放例句音频
  static Future<void> playSentenceAudio(String mp3Path) async {
    try {
      await _channel.invokeMethod('playSentenceAudio', {'mp3Path': mp3Path});
    } on PlatformException catch (e) {
      debugPrint('LockService.playSentenceAudio error: ${e.message}');
    }
  }

  /// 暂停音频
  static Future<void> pauseAudio() async {
    try {
      await _channel.invokeMethod('pauseAudio');
    } on PlatformException catch (e) {
      debugPrint('LockService.pauseAudio error: ${e.message}');
    }
  }

  // === 锁屏状态事件流 ===

  /// 监听锁屏状态变化事件
  /// 事件类型：'screenOn', 'screenOff', 'unlock', 'wordChanged'
  static Stream<Map<String, dynamic>> get lockEventStream {
    return _eventChannel.receiveBroadcastStream().map((event) => Map<String, dynamic>.from(event));
  }
}
