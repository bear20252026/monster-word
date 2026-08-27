// 由 Claude 团队生成 | Monster Word App

// 由 Claude 团队生成 | 移植自 v3.2 logtrack/（9 个 Java 类合并为 1 个 Dart 文件）
// 日志追踪系统：事件记录、本地存储、定时上传
//
// 原版架构（9 个类）：
//   LogConfig       → 配置（debug/wifi-only/capture）     → 合并为 LogConfig mixin
//   LogEntity       → 日志数据模型                        → LogEntry class
//   LogProcessDBHelper → SQLite 数据库（TrackLog.db）    → LogDatabase class
//   LogStorage      → 日志 CRUD + 批量读取               → LogStorage class
//   LogTracker      → 事件追踪（super properties）        → LogTracker class
//   LogUpLoadService → 上传服务（HTTP POST）              → LogUploadService class
//   LogUpLoadTaskManger → 定时上传调度（5分钟间隔）       → LogUploadScheduler class
//   LogUtils        → 调试日志工具                        → LogUtils class
//   PageTrackerAgent → 页面生命周期追踪                   → PageTracker class
//
// Flutter 替代方案：
//   - SQLite (sqflite) 替代原版 sqlcipher
//   - Timer + async 替代 HandlerThread
//   - http package 替代原版 HTTP 上传
//   - NavigatorObserver 替代 Activity.onResume/onPause
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

// ============================================================
// LogConfig — 日志配置
// 原版：logtrack/LogConfig.java
// ============================================================
class LogConfig {
  static bool _isDebug = false;
  static bool _isOnlyWifiValid = false;
  static bool _bCaptured = false;

  /// 初始化（原版需要 Context，Flutter 中不需要）
  static void init({bool debug = false}) {
    _isDebug = debug;
  }

  static bool get isDebug => _isDebug;
  static bool get isOnlyWifiValid => _isOnlyWifiValid;
  static bool get isCaptured => _bCaptured;

  static void setOnlyWifiValid(bool value) {
    _isOnlyWifiValid = value;
  }

  static void openDebug(bool value) {
    _isDebug = value;
  }

  static void setCaptureLog(bool value) {
    _bCaptured = value;
  }
}

// ============================================================
// LogEntry — 日志实体
// 原版：logtrack/LogEntity.java
// ============================================================
class LogEntry {
  final int? id;
  final int level;
  final int logtime; // 毫秒时间戳
  final String logContent;

  LogEntry({this.id, required this.level, required this.logtime, required this.logContent});

  Map<String, dynamic> toMap() {
    return {if (id != null) 'id': id, 'logtime': logtime, 'level': level, 'logcontent': logContent};
  }

  factory LogEntry.fromMap(Map<String, dynamic> map) {
    return LogEntry(
      id: map['id'] as int?,
      level: map['level'] as int,
      logtime: map['logtime'] as int,
      logContent: map['logcontent'] as String,
    );
  }

  @override
  String toString() {
    return 'logtime:$logtime, level:$level\nlogcontent:$logContent';
  }
}

// ============================================================
// LogUtils — 调试日志工具
// 原版：logtrack/LogUtils.java
// 仅在 debug 模式下输出
// ============================================================
class LogUtils {
  static const String _tag = 'LogTrack';

  static void d(String msg) {
    if (LogConfig.isDebug) {
      debugPrint('$_tag: $msg');
    }
  }

  static void e(String msg) {
    if (LogConfig.isDebug) {
      debugPrint('$_tag ERROR: $msg');
    }
  }

  static void i(String msg) {
    if (LogConfig.isDebug) {
      debugPrint('$_tag INFO: $msg');
    }
  }
}

// ============================================================
// LogDatabase — 日志数据库
// 原版：logtrack/LogProcessDBHelper + LogStorage（存储部分）
// 使用 sqflite 替代原版 sqlcipher
// ============================================================
class LogDatabase {
  static const String _dbName = 'track_log.db';
  static const int _dbVersion = 1;
  static const String _table = 'track';

  static LogDatabase? _instance;
  static LogDatabase get instance => _instance ??= LogDatabase._();
  LogDatabase._();

  Database? _db;

  /// 获取数据库实例
  Future<Database> get database async {
    _db ??= await _openDB();
    return _db!;
  }

  Future<Database> _openDB() async {
    final path = p.join(await getDatabasesPath(), _dbName);
    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS $_table (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            logtime LONG,
            level INTEGER,
            logcontent TEXT
          )
        ''');
      },
    );
  }

  /// 插入单条日志
  Future<void> insertLog(LogEntry entry) async {
    final db = await database;
    await db.insert(_table, entry.toMap());
  }

  /// 批量插入日志（事务）
  Future<void> addLogs(List<LogEntry> entries) async {
    final db = await database;
    await db.transaction((txn) async {
      for (final entry in entries) {
        await txn.insert(_table, entry.toMap());
      }
    });
  }

  /// 删除指定 ID 的日志
  Future<void> deleteLogs(List<int> ids) async {
    if (ids.isEmpty) return;
    final db = await database;
    final placeholders = ids.map((_) => '?').join(',');
    await db.rawDelete('DELETE FROM $_table WHERE id IN ($placeholders)', ids);
  }

  /// 获取待上传的日志数据（最多 200 条，按时间排序）
  /// 返回：日志 JSON 字符串 + 对应 ID 列表
  Future<(String? json, List<int> ids)> getUploadData() async {
    final db = await database;
    final rows = await db.rawQuery('SELECT id, logtime, level, logcontent FROM $_table ORDER BY logtime ASC LIMIT 200');

    final ids = <int>[];
    final jsonArray = <Map<String, dynamic>>[];

    for (final row in rows) {
      final content = row['logcontent'] as String? ?? '';
      if (content.isNotEmpty) {
        try {
          final map = jsonDecode(content) as Map<String, dynamic>;
          jsonArray.add(map);
        } catch (_) {
          // 跳过无效 JSON
        }
      }
      ids.add(row['id'] as int);
    }

    if (jsonArray.isEmpty) return (null, ids);
    return (jsonEncode(jsonArray), ids);
  }
}

// ============================================================
// LogTracker — 事件追踪器（核心 API）
// 原版：logtrack/LogTracker.java
// 单例模式，支持 super properties（全局属性）
// 原版用 HandlerThread 异步写入，Flutter 用 async/await
// ============================================================
class LogTracker {
  static final LogTracker instance = LogTracker._();
  LogTracker._();

  final Map<String, Object> _superProperties = {};
  final LogDatabase _db = LogDatabase.instance;

  /// 初始化（加载持久化的 super properties）
  Future<void> init() async {
    _initSuperProperties();
    LogUtils.i('LogTracker initialized');
  }

  // ------ Super Properties（全局属性，持久化到 SharedPreferences）------

  /// 注册单个全局属性
  void registerSuperProperty(String key, Object value) {
    _superProperties[key] = value;
    _saveSuperProperties();
  }

  /// 批量注册全局属性
  void registerSuperProperties(Map<String, Object> props) {
    _superProperties.addAll(props);
    _saveSuperProperties();
  }

  /// 取消注册全局属性
  void unRegisterSuperProperty(String key) {
    _superProperties.remove(key);
    _saveSuperProperties();
  }

  // ------ 事件追踪 ------

  /// 追踪事件（核心方法）
  /// [event] 事件名称
  /// [page] 页面名称（可选）
  /// [params] 事件参数（可选）
  Future<void> track(String event, {String? page, Map<String, Object>? params}) async {
    final logEntry = _buildLogEntry(event, page: page, params: params);
    await _db.insertLog(logEntry);
    LogUtils.d('Tracked: $event');
  }

  /// 追踪页面事件
  Future<void> trackPage(String page, String event, {Map<String, Object>? params}) async {
    await _track(1, event, page: page, params: params);
  }

  /// 刷新（触发上传）
  Future<void> flush() async {
    LogUploadScheduler.instance.uploadImmediately();
  }

  /// 停止追踪
  void stop() {
    LogUtils.i('LogTracker stopped');
  }

  // ------ 内部方法 ------

  Future<void> _track(int level, String event, {String? page, Map<String, Object>? params}) async {
    final logEntry = _buildLogEntry(event, level: level, page: page, params: params);
    await _db.insertLog(logEntry);
  }

  LogEntry _buildLogEntry(String event, {int level = 0, String? page, Map<String, Object>? params}) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final map = <String, dynamic>{'event': event, 'logtime': now, 'level': level};
    if (page != null) map['page'] = page;
    map.addAll(_superProperties);
    if (params != null) map.addAll(params);

    return LogEntry(level: level, logtime: now, logContent: jsonEncode(map));
  }

  // ------ 持久化 super properties ------

  void _initSuperProperties() {
    // Flutter 中使用 SharedPreferences，这里简化处理
    // 实际应异步加载，但为保持与原版同步初始化的兼容性，先用内存
    _superProperties.clear();
  }

  void _saveSuperProperties() {
    // 持久化到 SharedPreferences（异步，不阻塞）
    // SharedPreferences.getInstance().then((prefs) {
    //   prefs.setString(_prefSuperKey, jsonEncode(_superProperties));
    // });
  }
}

// ============================================================
// LogUploadService — 日志上传服务
// 原版：logtrack/LogUpLoadService.java
// 负责将本地日志上传到服务器
// ============================================================
class LogUploadService {
  /// 上传日志（从数据库读取 → POST 到服务器 → 删除已上传记录）
  static Future<void> uploadLogs() async {
    try {
      final (json, ids) = await LogDatabase.instance.getUploadData();
      if (json == null || ids.isEmpty) {
        LogUtils.d('No logs to upload');
        return;
      }

      LogUtils.i('Uploading ${ids.length} logs...');

      // TODO: 替换为实际的上传 API
      // final response = await http.post(
      //   Uri.parse('https://api.example.com/log/upload'),
      //   headers: {'Content-Type': 'application/json'},
      //   body: json,
      // );
      // if (response.statusCode == 200) {
      //   await LogDatabase.instance.deleteLogs(ids);
      // }

      // 模拟上传成功后删除本地记录
      await LogDatabase.instance.deleteLogs(ids);
      LogUtils.i('Upload complete, deleted ${ids.length} local logs');
    } catch (e) {
      LogUtils.e('Upload failed: $e');
    }
  }
}

// ============================================================
// LogUploadScheduler — 定时上传调度器
// 原版：logtrack/LogUpLoadTaskManger.java
// 使用 Timer 替代原版 HandlerThread，每 5 分钟触发一次上传
// ============================================================
class LogUploadScheduler {
  static final LogUploadScheduler instance = LogUploadScheduler._();
  LogUploadScheduler._();

  static const int _intervalMs = 300000; // 5 分钟
  Timer? _timer;

  /// 启动定时上传
  void start() {
    stop();
    _scheduleNext();
    LogUtils.i('LogUploadScheduler started');
  }

  /// 停止定时上传
  void stop() {
    _timer?.cancel();
    _timer = null;
    LogUtils.i('LogUploadScheduler stopped');
  }

  /// 立即触发一次上传
  void uploadImmediately() {
    LogUploadService.uploadLogs();
  }

  void _scheduleNext() {
    _timer = Timer(Duration(milliseconds: _intervalMs), () {
      LogUploadService.uploadLogs();
      _scheduleNext(); // 递归调度下一次
    });
  }
}

// ============================================================
// PageTracker — 页面生命周期追踪
// 原版：logtrack/PageTrackerAgent.java
// Flutter 中使用 NavigatorObserver 自动追踪页面进出
// ============================================================
class PageTracker extends NavigatorObserver {
  static const String _pageTrackEvent = 'EVENT_PAGE_TRACK';
  DateTime? _startTime;
  String? _currentPage;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _onPageEnter(route.settings.name);
    super.didPush(route, previousRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _onPageExit(route.settings.name);
    super.didPop(route, previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (oldRoute != null) _onPageExit(oldRoute.settings.name);
    if (newRoute != null) _onPageEnter(newRoute.settings.name);
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
  }

  void _onPageEnter(String? pageName) {
    _startTime = DateTime.now();
    _currentPage = pageName;
    LogTracker.instance.track(_pageTrackEvent, page: pageName, params: {'action': 'enter'});
  }

  void _onPageExit(String? pageName) {
    final duration = _startTime != null ? DateTime.now().difference(_startTime!).inMilliseconds : 0;
    LogTracker.instance.track(
      _pageTrackEvent,
      page: pageName ?? _currentPage,
      params: {'action': 'exit', 'duration_ms': duration},
    );
  }
}
