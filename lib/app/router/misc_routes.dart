import 'package:flutter/material.dart';

import 'package:word_app/features/book/presentation/memory_beast_gallery_page.dart';
import 'package:word_app/features/learning/presentation/dashboard_page.dart';
import 'package:word_app/features/learning/presentation/personal_stereo_page.dart';
import 'package:word_app/features/learning/presentation/play_order_page.dart';
import 'package:word_app/features/word_browse/presentation/foot_mark_page.dart';
import 'package:word_app/app/router/route_names.dart';

/// 个人中心杂项页面映射（P3-1 从 AccountRoutes 拆出）。
///
/// 学习仪表盘/个人立体声/播放顺序属 learning 域，记忆兽图鉴属 book 域，
/// 足迹属 word_browse 域——它们都是从个人中心入口进入的二级页面，
/// 不属账户/设置/钱包，单列一表避免再堆回杂物桶。
abstract final class MiscRoutes {
  static Widget? build(String? name, Object? args) {
    switch (name) {
      case RouteNames.dashboard:
        return const DashboardPage();
      case RouteNames.personalStereo:
        return const PersonalStereoPage();
      case RouteNames.playOrder:
        return const PlayOrderPage();
      case RouteNames.memoryBeastGallery:
        return const MemoryBeastGalleryPage();
      case RouteNames.footMark:
        return const FootMarkPage();
      default:
        return null;
    }
  }
}
