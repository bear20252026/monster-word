// 壁纸数据模型与持久化
// 对应原版 App 的背景系统：纯色/渐变/照片壁纸
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 壁纸类型
enum WallpaperType {
  solid,    // 纯色背景
  gradient, // 渐变背景
  image,    // 图片壁纸
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

  // 图片壁纸
  final String? assetPath;

  const WallpaperItem({
    required this.id,
    required this.name,
    required this.type,
    this.colors,
    this.begin,
    this.end,
    this.assetPath,
  });

  /// 是否为默认壁纸
  bool get isDefault => id == 'default';
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
  static List<WallpaperItem> get imageWallpapers =>
      allWallpapers.where((w) => w.type == WallpaperType.image).toList();

  /// 根据 ID 获取壁纸
  static WallpaperItem getById(String id) {
    return allWallpapers.firstWhere(
      (w) => w.id == id,
      orElse: () => defaultWallpaper,
    );
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
    return getById(id);
  }
}
