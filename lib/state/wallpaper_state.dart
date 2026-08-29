// 壁纸状态管理：加载/切换壁纸，通知 UI 更新
import 'package:flutter/foundation.dart';

import 'package:word_app/core/infrastructure/wallpaper_data.dart';

class WallpaperState extends ChangeNotifier {
  WallpaperItem _current = WallpaperData.beachWallpaper;

  WallpaperItem get current => _current;

  WallpaperState() {
    _load();
  }

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
