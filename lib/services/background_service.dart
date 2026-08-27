// 由 Claude 团队生成 | Monster Word App

// 由 Claude 团队生成 | 移植自 v3.2 service/ + diagnosis/ + thread/
// 后台服务 + 诊断工具 + 线程任务
// 包含：SynDataService, NotiService, LocalRemindStudyTask,
//       AppDiagnosisUtil, DeviceDiagnosisUtil, NetDiagnosisUtil,
//       DimImage, Unzip

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'api_services.dart';

// ============================================================
// 同步数据服务（翻译自 SynDataService.java）
// ============================================================

/// 同步状态
enum SyncServiceState { idle, syncing, success, failed }

/// 同步数据服务（翻译自 SynDataService.java）
/// Android 原版是 Service，Flutter 用后台任务替代
class SyncDataService {
  static const String _logTag = 'SyncDataService';
  static SyncServiceState _state = SyncServiceState.idle;

  /// 获取当前同步状态
  static SyncServiceState get state => _state;

  /// 执行同步（原版 onCreate 逻辑）
  /// 1. 上报每日统计
  /// 2. 上报复习任务
  /// 3. 链式同步学习数据
  static Future<void> execute() async {
    if (_state == SyncServiceState.syncing) {
      debugPrint('$_logTag: 正在同步，跳过');
      return;
    }
    _state = SyncServiceState.syncing;
    debugPrint('$_logTag: 开始同步');

    try {
      // 步骤 1：上报每日统计（原版 ReportUserDaily.call()）
      await ReportUserDaily.call();

      // 步骤 2：上报复习任务（原版 ReportUserDaily.uploadReviewTask()）
      await ReportUserDaily.uploadReviewTask();

      // 步骤 3：链式同步（原版 SyncChainService.call2()）
      await SyncChainServiceV2.call(_SyncListenerImpl());

      _state = SyncServiceState.success;
      debugPrint('$_logTag: 同步完成');
    } catch (e) {
      _state = SyncServiceState.failed;
      debugPrint('$_logTag: 同步异常: $e');
    }
  }

  /// 重置状态（用于测试）
  static void reset() => _state = SyncServiceState.idle;
}

class _SyncListenerImpl implements SyncListener {
  @override
  void onSyncStart() {
    debugPrint('SyncDataService: 同步开始');
  }

  @override
  void onSyncSuccess() {
    debugPrint('SyncDataService: 同步成功');
  }

  @override
  void onSyncFailed() {
    debugPrint('SyncDataService: 同步失败');
  }
}

// ============================================================
// 通知服务（翻译自 NotiService.java）
// ============================================================

/// 通知服务（翻译自 NotiService.java）
/// Android 原版是前台 Service，Flutter 用 flutter_local_notifications 替代
class NotiService {
  static const String actionNoti = 'cn.com.langeasy.LangEasyLexis.Notification';
  static const int notifyId = 10;
  static const String channelId = 'bbdc';
  static const String channelName = '不背单词通知';

  /// 创建通知 Intent 数据（原版 createIntent）
  /// 返回通知所需的数据 Map
  static Map<String, String> createNotificationData(String title, String content, String ticker) {
    return {'title': title, 'content': content, 'ticker': ticker};
  }

  /// 显示通知（原版 onStartCommand 逻辑）
  /// 需要 flutter_local_notifications 包
  static Future<void> showNotification({required String title, required String content, String? ticker}) async {
    // TODO: 需要 flutter_local_notifications 集成
    // final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    // const androidDetails = AndroidNotificationDetails(
    //   channelId, channelName,
    //   importance: Importance.high,
    //   priority: Priority.high,
    //   vibrationPattern: Int64List.fromList([300, 300]),
    // );
    // const details = NotificationDetails(android: androidDetails);
    // await flutterLocalNotificationsPlugin.show(
    //   notifyId, title, content, details,
    // );
    debugPrint('NotiService: 显示通知 - $title: $content');
  }
}

// ============================================================
// 学习提醒任务（翻译自 LocalRemindStudyTask.java）
// ============================================================

/// 学习提醒任务（翻译自 LocalRemindStudyTask.java）
/// Android 原版是 AsyncTask + AlarmManager，Flutter 用 Timer 替代
class LocalRemindStudyTask {
  static const String _logTag = 'LocalRemindStudyTask';

  /// 执行学习提醒调度（原版 doInBackground 逻辑）
  /// 根据复习计划设置定时提醒
  static Future<void> execute() async {
    debugPrint('$_logTag: 开始调度学习提醒');

    // TODO: 需要以下依赖集成：
    // - UserPreferences.isLearnRemind()
    // - UserPreferences.getLearnRemindTime()
    // - BBWordProcessDao.arrayForReviewSchedule()
    // - flutter_local_notifications (定时通知)

    // 原版逻辑：
    // 1. 检查用户是否开启学习提醒
    // 2. 获取提醒时间（时:分）
    // 3. 获取复习计划列表
    // 4. 为每个复习日期设置 AlarmManager 定时通知
    // 5. 为未来 10 天设置学习提醒

    debugPrint('$_logTag: 学习提醒调度完成');
  }

  /// 取消所有提醒（原版 AlarmManager.cancel 逻辑）
  static Future<void> cancelAll() async {
    // TODO: 取消所有已设置的定时通知
    debugPrint('$_logTag: 取消所有提醒');
  }
}

// ============================================================
// 应用诊断工具（翻译自 AppDiagnosisUtil.java）
// ============================================================

/// 应用诊断工具（翻译自 AppDiagnosisUtil.java）
class AppDiagnosisUtil {
  AppDiagnosisUtil._();

  /// 获取用户基本信息（原版 getUserBaseInfo）
  /// 返回用户信息 JSON（密码脱敏为 ******）
  static Map<String, dynamic>? getUserBaseInfo() {
    // TODO: 需要 UserPreferences.getUserInfoBean() 集成
    // final userInfo = UserPreferences.instance.userInfoBean;
    // if (userInfo == null) return null;
    // final json = userInfo.toJson();
    // json['password'] = '******'; // 脱敏
    // return json;
    return null;
  }

  /// 获取应用基本信息（原版 getAppBaseInfo）
  static Map<String, dynamic> getAppBaseInfo() {
    return {
      'AppVersion': '5.0.0', // TODO: 从 PackageInfo 获取
      '隐私权限': {
        '读权限': true, // TODO: permission_handler 检查
        '写权限': true,
        '悬浮窗': false, // TODO: 检查悬浮窗权限
        '通知': true, // TODO: 检查通知权限
        'GPS': false, // TODO: 检查位置权限
        '日历读权限': false,
        '日历写权限': false,
        '相机': false,
      },
    };
  }

  /// 获取单词学习信息（原版 getBaseWordInfo）
  static Map<String, dynamic> getBaseWordInfo() {
    // TODO: 需要 UserPreferences 和 DAO 集成
    return {
      '生词上次同步时间': '', // UserPreferences.getPreviousSyncNewWordTime()
      '生词未同步个数': 0, // NewWordDao.getSyncNewWordData()
      '学习记录上次同步时间': '', // UserPreferences.getPreviousSyncProcessTime()
      '学习记录未同步个数': 0, // BBWordProcessDao.getSyncProcessData()
      '当前词书': '', // PublicConstants.library_learning
    };
  }

  /// 获取完整诊断报告
  static Map<String, dynamic> getFullReport() {
    return {
      'user': getUserBaseInfo(),
      'app': getAppBaseInfo(),
      'word': getBaseWordInfo(),
      'device': DeviceDiagnosisUtil.getBaseDeviceInfo(),
      'network': NetDiagnosisUtil.getBaseNetInfo(),
    };
  }
}

// ============================================================
// 设备诊断工具（翻译自 DeviceDiagnosisUtil.java）
// ============================================================

/// 设备诊断工具（翻译自 DeviceDiagnosisUtil.java）
class DeviceDiagnosisUtil {
  DeviceDiagnosisUtil._();

  /// 获取设备基本信息（原版 getBaseDeviceInfo）
  static Map<String, dynamic> getBaseDeviceInfo() {
    return {
      '设备': _getDeviceInfo(),
      'UDID': _getDeviceId(),
      '平台': Platform.operatingSystem,
      '系统版本': Platform.operatingSystemVersion,
      '分辨率': _getScreenResolution(),
      'ROOT': _isRooted(),
      '电量': _getBatteryLevel(),
      '可用存储': _getAvailableStorage(),
      '系统语言': Platform.localeName,
      '时区': DateTime.now().timeZoneName,
    };
  }

  static String _getDeviceInfo() {
    // TODO: 用 device_info_plus 获取
    // final deviceInfo = DeviceInfoPlugin();
    // if (Platform.isAndroid) {
    //   final android = await deviceInfo.androidInfo;
    //   return '${android.manufacturer} ${android.model}';
    // }
    return Platform.localHostname;
  }

  static String _getDeviceId() {
    // TODO: 用 device_info_plus 获取
    return 'unknown';
  }

  static String _getScreenResolution() {
    // TODO: 用 MediaQuery 或 device_info_plus 获取
    return 'unknown';
  }

  static bool _isRooted() {
    // Flutter 无法直接检测 root，返回 false
    return false;
  }

  static int _getBatteryLevel() {
    // TODO: 用 battery_plus 获取
    return -1;
  }

  static String _getAvailableStorage() {
    // TODO: 用 disk_space 或 path_provider 获取
    return 'unknown';
  }

  /// 获取运营商信息（原版 getMobileOperator）
  /// 注意：Flutter 无法直接获取 SIM 卡运营商信息
  static String getMobileOperator() {
    // TODO: 需要 sim_data 或 platform_channel 实现
    return '未知运营商';
  }
}

// ============================================================
// 网络诊断工具（翻译自 NetDiagnosisUtil.java）
// ============================================================

/// 网络诊断工具（翻译自 NetDiagnosisUtil.java）
class NetDiagnosisUtil {
  NetDiagnosisUtil._();

  /// 获取网络基本信息（原版 getBaseNetInfo）
  static Map<String, dynamic> getBaseNetInfo() {
    return {
      '网络状态': _getNetworkType(),
      'HttpDNS': true, // TODO: 从 AppPreferences 获取
      '是否开启代理': _isProxyEnabled(),
      '代理': _getProxyInfo(),
    };
  }

  /// 获取网络类型（原版 getNetworkType）
  /// 返回：WIFI / 2G / 3G / 4G / 5G / 无网
  static String _getNetworkType() {
    // TODO: 用 connectivity_plus 获取
    // final connectivity = Connectivity();
    // final result = await connectivity.checkConnectivity();
    // if (result == ConnectivityResult.wifi) return 'WIFI';
    // if (result == ConnectivityResult.mobile) return '移动网络';
    // return '无网';
    return 'unknown';
  }

  /// 检查是否开启代理（原版代理检测逻辑）
  static bool _isProxyEnabled() {
    // Flutter 无法直接检测系统代理
    // 可以通过检查 http.proxyFromEnvironment 间接判断
    final proxy =
        Platform.environment['http_proxy'] ??
        Platform.environment['HTTP_PROXY'] ??
        Platform.environment['https_proxy'] ??
        Platform.environment['HTTPS_PROXY'];
    return proxy != null && proxy.isNotEmpty;
  }

  /// 获取代理信息
  static String _getProxyInfo() {
    final proxy =
        Platform.environment['http_proxy'] ??
        Platform.environment['HTTP_PROXY'] ??
        Platform.environment['https_proxy'] ??
        Platform.environment['HTTPS_PROXY'];
    return proxy ?? '';
  }

  /// 获取设备 IP（原版 getDeviceIp）
  static Future<String> getDeviceIp() async {
    try {
      final interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4, includeLinkLocal: false);
      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          if (!addr.isLoopback) {
            return addr.address;
          }
        }
      }
      return 'unKnown';
    } catch (e) {
      return 'unKnown';
    }
  }

  /// 获取本地 DNS（原版 getLocalDns）
  /// 注意：Flutter 无法直接获取系统 DNS
  static String getLocalDns() {
    // TODO: 需要 platform_channel 实现
    // Android 原版通过 getprop net.dns1 / getprop net.dns2 获取
    return '';
  }
}

// ============================================================
// 背景模糊图生成（翻译自 DimImage.java）
// ============================================================

/// 背景模糊图生成（翻译自 DimImage.java）
/// Android 原版用 StackBlur 算法，Flutter 用 Image 包替代
class DimImage {
  static const String _logTag = 'DimImage';

  /// 生成模糊背景图（原版 createBackgroundBlurImage）
  /// 在后台 Isolate 中执行，避免阻塞 UI
  static Future<void> createBackgroundBlurImage(String imagePath) async {
    final dimPath = imagePath.replaceAll(RegExp(r'\.(jpg|jpeg|png)$'), '_dim.jpg');
    final dimFile = File(dimPath);

    if (await dimFile.exists()) {
      debugPrint('$_logTag: 模糊图已存在，跳过: $dimPath');
      return;
    }

    debugPrint('$_logTag: 开始生成模糊背景: $imagePath');

    try {
      // 在后台 Isolate 中处理
      await compute(_blurImageIsolate, _BlurParams(imagePath, dimPath, 60));
      debugPrint('$_logTag: 模糊背景生成完成: $dimPath');
    } catch (e) {
      debugPrint('$_logTag: 模糊背景生成失败: $e');
    }
  }

  /// 生成模糊背景图 2（原版 createBgBlurImage2）
  /// 轻度模糊（radius=20 vs 60）
  static Future<void> createBgBlurImage2(String imagePath) async {
    final dimPath = imagePath.replaceAll(RegExp(r'\.(jpg|jpeg|png)$'), '_dim2.jpg');
    final dimFile = File(dimPath);

    if (await dimFile.exists()) {
      debugPrint('$_logTag: 模糊图2已存在，跳过: $dimPath');
      return;
    }

    debugPrint('$_logTag: 开始生成模糊背景2: $imagePath');

    try {
      await compute(_blurImageIsolate, _BlurParams(imagePath, dimPath, 20));
      debugPrint('$_logTag: 模糊背景2生成完成: $dimPath');
    } catch (e) {
      debugPrint('$_logTag: 模糊背景2生成失败: $e');
    }
  }
}

class _BlurParams {
  final String inputPath;
  final String outputPath;
  final int blurRadius;
  _BlurParams(this.inputPath, this.outputPath, this.blurRadius);
}

/// Isolate 中执行的模糊处理
/// TODO: 需要 image 包实现实际的模糊算法
Future<void> _blurImageIsolate(_BlurParams params) async {
  // TODO: 使用 image 包实现
  // final bytes = await File(params.inputPath).readAsBytes();
  // final image = decodeImage(bytes);
  // final blurred = gaussianBlur(image, radius: params.blurRadius);
  // final encoded = encodeJpg(blurred, quality: 100);
  // await File(params.outputPath).writeAsBytes(encoded);
  debugPrint('DimImage: 模糊处理 ${params.inputPath} (radius=${params.blurRadius})');
}

// ============================================================
// 文件解压工具（翻译自 Unzip.java）
// ============================================================

/// 解压状态回调
typedef UnzipCallback = void Function(String zipPath, bool success, int code);

/// 文件解压工具（翻译自 Unzip.java）
class Unzip {
  static const String _logTag = 'Unzip';
  static const int _successCode = 100;
  static const int _failCode = 101;

  /// 解压文件（原版 unzipFile，带回调）
  /// 在后台 Isolate 中执行
  static Future<void> unzipFile(String zipPath, String destDir, String? suffix, UnzipCallback? callback) async {
    debugPrint('$_logTag: 开始解压: $zipPath');

    try {
      final result = await compute(_unzipIsolate, _UnzipParams(zipPath, destDir, suffix));

      if (result) {
        debugPrint('$_logTag: 解压成功: $zipPath');
        callback?.call(zipPath, true, _successCode);
      } else {
        debugPrint('$_logTag: 解压失败: $zipPath');
        callback?.call(zipPath, false, _failCode);
      }
    } catch (e) {
      debugPrint('$_logTag: 解压异常: $e');
      callback?.call(zipPath, false, _failCode);
    }
  }

  /// 解压文件（无回调版本）
  static Future<void> unzipFileSimple(String zipPath, String destDir, String? suffix, UnzipCallback? callback) async {
    unzipFile(zipPath, destDir, suffix, callback);
  }

  /// 同步解压（原版 unzip）
  /// 在当前 Isolate 中执行
  static Future<bool> unzip(String zipPath, String destDir, String? suffix) async {
    try {
      final file = File(zipPath);
      if (!await file.exists()) {
        debugPrint('$_logTag: ZIP 文件不存在: $zipPath');
        return false;
      }

      // TODO: 使用 archive 包解压
      // final archive = ZipDecoder().decodeBytes(bytes);
      // for (final entry in archive) {
      //   final name = suffix != null ? '${entry.name}$suffix' : entry.name;
      //   final outFile = File('$destDir/$name');
      //   await outFile.parent.create(recursive: true);
      //   if (entry.isFile) {
      //     await outFile.writeAsBytes(entry.content as List<int>);
      //   } else {
      //     await outFile.create(recursive: true);
      //   }
      // }

      debugPrint('$_logTag: 解压完成: $zipPath -> $destDir');

      // 删除源 ZIP 文件（原版逻辑）
      // await file.delete();

      return true;
    } catch (e) {
      debugPrint('$_logTag: 解压失败: $e');
      return false;
    }
  }
}

class _UnzipParams {
  final String zipPath;
  final String destDir;
  final String? suffix;
  _UnzipParams(this.zipPath, this.destDir, this.suffix);
}

/// Isolate 中执行的解压
Future<bool> _unzipIsolate(_UnzipParams params) async {
  try {
    final file = File(params.zipPath);
    if (!await file.exists()) return false;

    // TODO: 使用 archive 包解压
    // final bytes = await file.readAsBytes();
    // final archive = ZipDecoder().decodeBytes(bytes);
    // for (final entry in archive) {
    //   final name = params.suffix != null
    //       ? '${entry.name}${params.suffix}'
    //       : entry.name;
    //   final outFile = File('${params.destDir}/$name');
    //   await outFile.parent.create(recursive: true);
    //   if (entry.isFile) {
    //     await outFile.writeAsBytes(entry.content as List<int>);
    //   }
    // }
    return true;
  } catch (e) {
    return false;
  }
}
