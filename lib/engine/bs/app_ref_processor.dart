// 移植自 v3.2 bs/AppRefProcessor.java
// 应用推荐处理器：加载推荐应用图标、打开/下载推荐应用
// 复用 api_services.dart 中已有的 AppRec / AppIcon / GetAppConfiguration

import 'dart:io';

import 'package:flutter/material.dart';

import '../../services/api_services.dart';

/// 应用推荐处理器（翻译自 AppRefProcessor.java）
///
/// 从推荐列表中选择合适的推荐应用（优先已安装的），
/// 提供图标加载、打开应用、跳转下载等功能。
class AppRefProcessor {
  static const _qtListenPkgName = 'com.qingting.listening';
  static const _appQListenUrl = 'https://a.app.qq.com/o/simple.jsp?pkgname=$_qtListenPkgName';

  /// 公共常量（原版 PublicConstants）
  static String localFilePath = ''; // 需在应用启动时设置
  static String baseImgUrl = 'https://img.beingfine.cn/';

  /// 缓存的推荐列表（原版 PublicConstants.appRecList）
  static List<AppRec>? appRecList;

  final AppRec _appRec;

  AppRefProcessor({bool forceFirst = false}) : _appRec = _selectAppRec(forceFirst);

  /// 从推荐列表中选择合适的推荐应用
  static AppRec _selectAppRec(bool forceFirst) {
    final list = appRecList;
    if (list != null && list.isNotEmpty) {
      if (forceFirst) return list.first;

      // 优先选择已安装的应用
      for (final rec in list) {
        if (rec.pkg.isNotEmpty && _isAppInstalled(rec.pkg)) {
          return rec;
        }
      }
      return list.first;
    }
    return AppRec.getDefaultAppRec();
  }

  /// 获取应用名称
  String get appName => _appRec.name;

  /// 获取应用简介
  String get appIntro => _appRec.intro;

  /// 获取应用包名
  String get appPkgName {
    final pkg = _appRec.pkg;
    return pkg.isNotEmpty ? pkg : _qtListenPkgName;
  }

  /// 获取应用下载/详情 URL
  String get appUrl {
    final url = _appRec.url;
    return url.isNotEmpty ? url : _appQListenUrl;
  }

  /// 打开应用（已安装则启动，否则跳转下载）
  Future<void> openApp(BuildContext context) async {
    final pkg = appPkgName;
    final url = appUrl;

    if (_isAppInstalled(pkg)) {
      await _launchApp(pkg);
    } else if (_appRec.type == 2) {
      await _openUrl(url);
    } else {
      await _openAppStore(pkg);
    }
  }

  /// 跳转下载应用
  Future<void> gotoDownloadApp(BuildContext context) async {
    final pkg = appPkgName;
    final url = appUrl;

    if (_appRec.type == 2) {
      await _openUrl(url);
    } else {
      await _openAppStore(pkg);
    }
  }

  /// 获取推荐应用图标路径（根据主题选择 light/dark/black）
  String? getAppIconPath(AppIcon? icon, int themeType) {
    if (icon == null) return null;
    switch (themeType) {
      case 1:
        return icon.dark.isNotEmpty ? icon.dark : null;
      case 2:
        return icon.black.isNotEmpty ? icon.black : null;
      default:
        return icon.light.isNotEmpty ? icon.light : null;
    }
  }

  /// 获取图标 Provider（本地文件优先，否则网络下载）
  ImageProvider? getIconProvider(int themeType) {
    final iconPath = getAppIconPath(_appRec.icon, themeType);
    if (iconPath == null || iconPath.isEmpty) return null;

    // 尝试本地缓存
    if (localFilePath.isNotEmpty) {
      final file = File('$localFilePath$iconPath');
      if (file.existsSync()) {
        return FileImage(file);
      }
    }

    // 网络下载
    return NetworkImage('$baseImgUrl$iconPath');
  }

  /// 批量下载推荐应用图标（后台执行，原版 downloadAppRefIcon）
  static Future<void> downloadAppRefIcons(List<AppRec> list) async {
    if (list.isEmpty) return;

    final iconPaths = <String>[];
    for (final rec in list) {
      final icon = rec.icon;
      if (icon != null) {
        if (icon.light.isNotEmpty) iconPaths.add(icon.light);
        if (icon.dark.isNotEmpty) iconPaths.add(icon.dark);
        if (icon.black.isNotEmpty) iconPaths.add(icon.black);
      }
    }
    if (iconPaths.isEmpty) return;

    for (final path in iconPaths) {
      if (localFilePath.isEmpty) continue;
      final file = File('$localFilePath$path');
      if (file.existsSync()) continue;

      try {
        final url = '$baseImgUrl$path';
        final client = HttpClient();
        final request = await client.getUrl(Uri.parse(url));
        final response = await request.close();
        if (response.statusCode == 200) {
          final bytes = await response.fold<List<int>>([], (prev, chunk) => prev..addAll(chunk));
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes);
        }
        client.close();
      } catch (_) {
        // 下载失败忽略
      }
    }
  }

  // --- 平台相关（需要 url_launcher 包）---

  static bool _isAppInstalled(String pkg) {
    // TODO: 实际实现需要调用 platform channel 检测应用是否安装
    return false;
  }

  static Future<void> _launchApp(String pkg) async {
    // TODO: 实际实现需要 url_launcher 包
    // await launch('package:$pkg');
  }

  static Future<void> _openUrl(String url) async {
    // TODO: 实际实现需要 url_launcher 包
    // await launch(url);
  }

  static Future<void> _openAppStore(String pkg) async {
    // TODO: 实际实现需要 url_launcher 包
    // await launch('market://details?id=$pkg');
  }
}
