import 'package:flutter/material.dart';

import 'package:word_app/features/settings/presentation/design_language_select_page.dart';
import 'package:word_app/features/settings/presentation/more_settings_page.dart';
import 'package:word_app/features/settings/presentation/net_diagnosis_page.dart';
import 'package:word_app/features/settings/presentation/settings_page.dart';
import 'package:word_app/features/settings/presentation/ui_theme_select_page.dart';
import 'package:word_app/app/router/route_names.dart';

/// 设置功能域的页面映射（P3-1 从 AccountRoutes 拆出）。
abstract final class SettingsRoutes {
  static Widget? build(String? name, Object? args) {
    switch (name) {
      case RouteNames.settings:
        return const SettingsPage();
      case RouteNames.netDiagnosis:
        return const NetDiagnosisPage();
      case RouteNames.themeSelect:
        return const UIThemeSelectPage();
      case RouteNames.designLanguage:
        return const DesignLanguageSelectPage();
      case RouteNames.moreSettings:
        return const MoreSettingsPage();
      default:
        return null;
    }
  }
}
