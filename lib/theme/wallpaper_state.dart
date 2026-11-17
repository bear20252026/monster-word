// 壁纸状态管理：加载/切换壁纸，通知 UI 更新
import 'package:flutter/foundation.dart';

import 'package:word_app/core/application/restore_cache_reset.dart';
import 'package:word_app/theme/wallpaper_data.dart';

class WallpaperState extends ChangeNotifier {
  WallpaperItem _current = WallpaperData.beachWallpaper;

  WallpaperItem get current => _current;

  WallpaperState() {
    _load();
    // 第四轮审计 M18（2026-11-17）：备份恢复后重读壁纸选择（SP 已回放）。
    RestoreCacheResetBus.register(reloadForRestore);
  }

  @override
  void dispose() {
    RestoreCacheResetBus.unregister(reloadForRestore);
    super.dispose();
  }

  Future<void> reloadForRestore() => _load();

  Future<void> _load() async {
    _current = await WallpaperData.loadSelected();
    notifyListeners();
  }

  Future<void> setWallpaper(WallpaperItem wallpaper) async {
    _current = wallpaper;
    await WallpaperData.saveSelected(wallpaper.id);
    notifyListeners();
  }
}
