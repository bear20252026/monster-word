// 壁纸数据模型与持久化
// 对应原版 App 的背景系统：纯色/渐变/照片壁纸
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 壁纸类型
enum WallpaperType {
  solid, // 纯色背景
  gradient, // 渐变背景
  image, // 图片壁纸（assets）
  custom, // 用户自定义上传
}

/// 壁纸数据
class WallpaperItem {
  final String id;
  final String name;
  final WallpaperType type;

  // 纯色/渐变
  final List<Color>? colors;
  final Alignment? begin;
  final Alignment? end;

  // 图片壁纸（assets）
  final String? assetPath;

  // 自定义上传壁纸（本地文件路径）
  final String? filePath;

  const WallpaperItem({
    required this.id,
    required this.name,
    required this.type,
    this.colors,
    this.begin,
    this.end,
    this.assetPath,
    this.filePath,
  });

  /// 是否为默认壁纸
  bool get isDefault => id == 'default';

  /// 是否为自定义壁纸
  bool get isCustom => type == WallpaperType.custom;

  /// 序列化为 JSON（用于存储自定义壁纸）
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'type': type.index, 'filePath': filePath};

  /// 从 JSON 反序列化
  factory WallpaperItem.fromJson(Map<String, dynamic> json) => WallpaperItem(
    id: json['id'] as String,
    name: json['name'] as String? ?? '自定义壁纸',
    type: WallpaperType.custom,
    filePath: json['filePath'] as String?,
  );
}

/// 预设壁纸列表
class WallpaperData {
  static const _prefKey = 'selected_wallpaper_id';

  // 默认壁纸（浅灰纯色，对应原版 #F5F5F5）
  static const defaultWallpaper = WallpaperItem(
    id: 'default',
    name: '默认',
    type: WallpaperType.solid,
    colors: [Color(0xFFF5F5F5)],
  );

  // 品牌渐变壁纸（橙色渐变，对应原版特色）
  static const brandGradient = WallpaperItem(
    id: 'brand_gradient',
    name: '日落橙',
    type: WallpaperType.gradient,
    colors: [Color(0xFFFFF3E0), Color(0xFFFFE0B2), Color(0xFFFFCC80)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // 暖色渐变
  static const warmGradient = WallpaperItem(
    id: 'warm_gradient',
    name: '暖阳',
    type: WallpaperType.gradient,
    colors: [Color(0xFFFFF8E1), Color(0xFFFFECB3)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // 清新渐变
  static const freshGradient = WallpaperItem(
    id: 'fresh_gradient',
    name: '清新',
    type: WallpaperType.gradient,
    colors: [Color(0xFFE8F5E9), Color(0xFFC8E6C9)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // 海洋渐变
  static const oceanGradient = WallpaperItem(
    id: 'ocean_gradient',
    name: '海洋',
    type: WallpaperType.gradient,
    colors: [Color(0xFFE3F2FD), Color(0xFFBBDEFB), Color(0xFF90CAF9)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // 紫色渐变
  static const purpleGradient = WallpaperItem(
    id: 'purple_gradient',
    name: '星空',
    type: WallpaperType.gradient,
    colors: [Color(0xFFEDE7F6), Color(0xFFD1C4E9), Color(0xFFB39DDB)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // 图片壁纸（使用 assets）
  static const beachWallpaper = WallpaperItem(
    id: 'beach',
    name: '海滩',
    type: WallpaperType.image,
    assetPath: 'assets/wallpapers/beach.jpg',
    colors: [Color(0xFF81D4FA), Color(0xFF4FC3F7)], // fallback
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // 以下 3 张图片壁纸源文件缺失（forest/city/night.jpg 不存在于 assets/wallpapers/），
  // 降级为纯色壁纸使用原有 fallback 色值，消除 assetPath 悬空引用的运行时风险。
  // 待"壁纸系统下线"重构任务统一清理。
  static const forestWallpaper = WallpaperItem(
    id: 'forest',
    name: '森林',
    type: WallpaperType.solid,
    colors: [Color(0xFF81C784)],
  );

  static const cityWallpaper = WallpaperItem(
    id: 'city',
    name: '城市',
    type: WallpaperType.solid,
    colors: [Color(0xFF90A4AE)],
  );

  static const nightWallpaper = WallpaperItem(
    id: 'night',
    name: '夜空',
    type: WallpaperType.solid,
    colors: [Color(0xFF263238)],
  );

  /// 全部可用壁纸
  static const List<WallpaperItem> allWallpapers = [
    defaultWallpaper,
    brandGradient,
    warmGradient,
    freshGradient,
    oceanGradient,
    purpleGradient,
    beachWallpaper,
    forestWallpaper,
    cityWallpaper,
    nightWallpaper,
  ];

  /// 渐变壁纸列表
  static List<WallpaperItem> get gradientWallpapers =>
      allWallpapers.where((w) => w.type == WallpaperType.gradient).toList();

  /// 图片壁纸列表
  static List<WallpaperItem> get imageWallpapers => allWallpapers.where((w) => w.type == WallpaperType.image).toList();

  /// 根据 ID 获取壁纸
  static WallpaperItem getById(String id) {
    return allWallpapers.firstWhere((w) => w.id == id, orElse: () => defaultWallpaper);
  }

  /// 保存用户选择
  static Future<void> saveSelected(String wallpaperId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, wallpaperId);
  }

  /// 读取用户选择
  static Future<WallpaperItem> loadSelected() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(_prefKey) ?? 'default';
    // 如果是自定义壁纸，从自定义列表中查找
    if (id.startsWith('custom_')) {
      final customs = await loadCustomWallpapers();
      return customs.firstWhere((w) => w.id == id, orElse: () => defaultWallpaper);
    }
    return getById(id);
  }

  // ===========================================================================
  // 自定义壁纸管理
  // ===========================================================================

  static const String _customPrefKey = 'custom_wallpapers';

  /// 加载自定义壁纸列表
  static Future<List<WallpaperItem>> loadCustomWallpapers() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_customPrefKey);
    if (jsonStr == null || jsonStr.isEmpty) return [];
    try {
      final list = List<Map<String, dynamic>>.from(const JsonDecoder().convert(jsonStr) as List);
      return list.map((e) => WallpaperItem.fromJson(e)).toList();
    } catch (_) {
      // B 级豁免：壁纸列表解析降级，壁纸缺失不影响主流程（REG-OBS-001）
      return [];
    }
  }

  /// 保存自定义壁纸列表
  static Future<void> _saveCustomWallpapers(List<WallpaperItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(items.map((e) => e.toJson()).toList());
    await prefs.setString(_customPrefKey, jsonStr);
  }

  /// 添加自定义壁纸
  static Future<void> addCustomWallpaper(WallpaperItem item) async {
    final items = await loadCustomWallpapers();
    items.add(item);
    await _saveCustomWallpapers(items);
  }

  /// 删除自定义壁纸
  static Future<void> removeCustomWallpaper(String id) async {
    final items = await loadCustomWallpapers();
    items.removeWhere((w) => w.id == id);
    await _saveCustomWallpapers(items);
  }
}
