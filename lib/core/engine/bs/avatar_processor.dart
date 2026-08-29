// 移植自 v3.2 bs/AvatarProcessor.java
// 用户头像处理器：加载头像、下载头像、获取默认头像

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:word_app/core/infrastructure/app_preferences.dart';
import 'package:word_app/core/services/api_services.dart';

/// 用户头像处理器（翻译自 AvatarProcessor.java）
///
/// 负责加载和缓存用户头像，支持主题切换（light/dark/black 默认头像）。
class AvatarProcessor {
  /// 加载头像到 ImageProvider（原版 loadAvatarTo）
  /// 返回加载的 ImageProvider，如果无头像则返回默认头像
  static ImageProvider loadAvatar({int themeType = 0}) {
    final userInfo = _getUserInfo();
    if (userInfo == null) return _getDefaultAvatar(themeType);

    final photo = userInfo.avatar;
    if (photo.isEmpty) return _getDefaultAvatar(photo.isEmpty ? 0 : themeType);

    // 尝试本地缓存
    final localPath = '${CoolHttpClientV3.localFilePath}$photo';
    final file = File(localPath);
    if (file.existsSync()) {
      return FileImage(file);
    }

    return _getDefaultAvatar(themeType);
  }

  /// 异步加载头像（带网络下载，原版 downloadAvatar 逻辑）
  /// 返回加载完成的 ImageProvider
  static Future<ImageProvider> loadAvatarAsync({int themeType = 0}) async {
    final userInfo = _getUserInfo();
    if (userInfo == null) return _getDefaultAvatar(themeType);

    final photo = userInfo.avatar;
    if (photo.isEmpty) return _getDefaultAvatar(themeType);

    // 尝试本地缓存
    final localPath = '${CoolHttpClientV3.localFilePath}$photo';
    final file = File(localPath);
    if (file.existsSync()) {
      return FileImage(file);
    }

    // 网络下载
    try {
      final url = '${CoolHttpClientV3.baseImgUrl}$photo';
      final client = HttpClient();
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close();
      if (response.statusCode == 200) {
        final bytes = await response.fold<List<int>>([], (prev, chunk) => prev..addAll(chunk));
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes);
        client.close();
        return FileImage(file);
      }
      client.close();
    } catch (_) {
      // 下载失败
    }

    return _getDefaultAvatar(themeType);
  }

  /// 获取头像字节数据（用于分享等场景，原版 getSharedAvatarBitmap）
  static Future<Uint8List?> getAvatarBytes({int themeType = 0}) async {
    final userInfo = _getUserInfo();
    if (userInfo == null) return null;

    final photo = userInfo.avatar;
    if (photo.isEmpty) return null;

    final localPath = '${CoolHttpClientV3.localFilePath}$photo';
    final file = File(localPath);
    if (file.existsSync()) {
      return file.readAsBytes();
    }

    // 尝试下载
    try {
      final url = '${CoolHttpClientV3.baseImgUrl}$photo';
      final client = HttpClient();
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close();
      if (response.statusCode == 200) {
        final bytes = await response.fold<List<int>>([], (prev, chunk) => prev..addAll(chunk));
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes);
        client.close();
        return Uint8List.fromList(bytes);
      }
      client.close();
    } catch (_) {
      // 下载失败
    }

    return null;
  }

  /// 获取默认头像资源路径（根据主题，原版 getDefaultIconFace）
  static String getDefaultAvatarAsset(int themeType) {
    switch (themeType) {
      case 1:
        return 'assets/images/icon_user_none_dark.png';
      case 2:
        return 'assets/images/icon_user_none_black.png';
      default:
        return 'assets/images/icon_user_none_light.png';
    }
  }

  /// 获取默认头像 ImageProvider
  static AssetImage _getDefaultAvatar(int themeType) {
    return AssetImage(getDefaultAvatarAsset(themeType));
  }

  /// 获取当前用户信息
  static UserInfoBean? _getUserInfo() {
    // 从 SharedPreferences 读取用户信息
    // 实际实现需要从 UserPreferences 读取
    return null; // TODO: 接入实际用户数据
  }
}
