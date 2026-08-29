// Monster Word — B 档设计语言（DesignLanguage）
//
// 设计分层：
// - A 档：颜色（skin_system.dart 的 ThemeVars，按主题 id 切换）。
// - B 档：视觉/形态令牌 —— 字体比例(font scale/族)、圆角(radius)、间距(spacing)、
//         阴影/抬升(shadow)，以及可选组件态(边框/玻璃/光感)。**本文件即 B 档。**
//
// 目标：把 6 套品牌风格(starbucks/airbnb/nike/clickhouse/apple/claude)统一到同一个
// 可切换的 B 档 schema；"B 档整体切换"= 更换当前 DesignLanguage，即整套半径/间距/
// 阴影/字体比例响应式变化，而无需改动各页对 token 的引用。
//
// 使用约定：
// - 向下兼容：既有静态常量 AppRadius/AppSpacing/MistralTypography/设计_tokens 保留，
//   仍指向 starbucks 值（默认）。
// - 迁移态：新增可运行时读取的动态 token `DesignScope.of(context)`（InheritedWidget），
//   各页据此读取当前 B 档值，实现整套切换。
// - A/B 正交：主题 id 决定颜色(ThemeVars) + 设计语言(DesignLanguage)，二者独立。
import 'package:flutter/material.dart';

/// 字体比例刻度（scale）。每个品牌定义自己的显示字体族与正文字体族。
class DesignTypography {
  /// 展示/标题字体族（可 null = 用系统/正文族）
  final String? displayFamily;

  /// 正文字体族（可 null = 系统默认）
  final String? bodyFamily;

  /// 展示级字号
  final double hero;
  final double h1;
  final double h2;
  final double h3;
  final double h4;

  /// 正文字号
  final double body;
  final double bodySm;
  final double caption;
  final double micro;

  /// 行高比例
  final double lineHeight;

  const DesignTypography({
    this.displayFamily,
    this.bodyFamily,
    this.hero = 64,
    this.h1 = 52,
    this.h2 = 36,
    this.h3 = 28,
    this.h4 = 22,
    this.body = 16,
    this.bodySm = 14,
    this.caption = 13,
    this.micro = 12,
    this.lineHeight = 1.5,
  });
}

/// 圆角刻度
class DesignRadius {
  final double xs;
  final double sm;
  final double md;
  final double lg;
  final double xl;
  final double xxl;

  /// 全圆角（pill/胶囊）
  final double pill;

  /// 卡片/控件/玻璃面板/底部弹层圆角
  final double card;
  final double control;
  final double glass;
  final double sheet;

  /// 通用控件圆角（历史别名 radiusNormal）
  final double radiusNormal;

  const DesignRadius({
    this.xs = 6,
    this.sm = 10,
    this.md = 14,
    this.lg = 20,
    this.xl = 24,
    this.xxl = 32,
    this.pill = 9999,
    this.card = 24,
    this.control = 16,
    this.glass = 20,
    this.sheet = 28,
    this.radiusNormal = 16,
  });
}

/// 间距刻度（4 基数）
class DesignSpacing {
  final double xxs;
  final double xs;
  final double sm;
  final double md;
  final double lg;
  final double xl;
  final double xxl;

  /// 大分隔（区块间）
  final double section;

  /// 页面通用左右留白
  final double page;

  /// 列表行高 / 顶栏高
  final double rowH;
  final double navH;

  const DesignSpacing({
    this.xxs = 4,
    this.xs = 8,
    this.sm = 12,
    this.md = 16,
    this.lg = 20,
    this.xl = 24,
    this.xxl = 32,
    this.section = 64,
    this.page = 16,
    this.rowH = 52,
    this.navH = 44,
  });
}

/// 阴影/抬升刻度：material elevation 等级 → 对应的模糊/偏移/不透明度形态。
class DesignShadow {
  /// elevation 等级列表（与输入顺序一致）
  final List<ShadowSpec> levels;

  const DesignShadow({this.levels = const []});

  /// 取某等级阴影（[elevation] 1..5），越界返回最顶级。
  ShadowSpec at(int elevation) {
    if (levels.isEmpty) return const ShadowSpec();
    final i = elevation.clamp(1, levels.length) - 1;
    return levels[i];
  }
}

/// 单个阴影形态。
class ShadowSpec {
  final double blur;
  final double offsetX;
  final double offsetY;
  final double opacity;
  const ShadowSpec({this.blur = 8, this.offsetX = 0, this.offsetY = 2, this.opacity = 0.12});

  BoxShadow toBoxShadow([Color? color]) => BoxShadow(
        color: (color ?? const Color(0xFF000000)).withValues(alpha: opacity),
        blurRadius: blur,
        offset: Offset(offsetX, offsetY),
      );
}

class DesignLanguage {
  final String id;
  final String name;

  final DesignTypography typography;
  final DesignRadius radius;
  final DesignSpacing spacing;
  final DesignShadow shadow;

  /// 便于组合的语义快捷访问（读 radius/spacing）
  DesignRadius get r => radius;
  DesignSpacing get s => spacing;

  const DesignLanguage({
    required this.id,
    required this.name,
    this.typography = const DesignTypography(),
    this.radius = const DesignRadius(),
    this.spacing = const DesignSpacing(),
    this.shadow = const DesignShadow(),
  });
}

/// 6 套品牌设计语言（统一 schema 下的差异化值）。
class DesignLanguages {
  static final Map<String, DesignLanguage> all = {
    'starbucks': DesignLanguage(
      id: 'starbucks',
      name: '星巴克｜奶油温润',
      typography: const DesignTypography(
        displayFamily: 'Charter',
        bodyFamily: 'Inter',
        hero: 64,
        h1: 52,
        h2: 36,
        h3: 28,
        h4: 22,
        body: 16,
        bodySm: 14,
        caption: 13,
        micro: 12,
        lineHeight: 1.55,
      ),
      radius: const DesignRadius(xs: 6, sm: 10, md: 14, lg: 20, xl: 24, xxl: 32),
      spacing: const DesignSpacing(xs: 8, sm: 12, md: 16, lg: 20, xl: 24, xxl: 32, section: 64),
      shadow: const DesignShadow(levels: [
        ShadowSpec(blur: 6, offsetY: 1, opacity: 0.08),
        ShadowSpec(blur: 10, offsetY: 2, opacity: 0.10),
        ShadowSpec(blur: 16, offsetY: 3, opacity: 0.12),
        ShadowSpec(blur: 24, offsetY: 5, opacity: 0.14),
        ShadowSpec(blur: 40, offsetY: 9, opacity: 0.16),
      ]),
    ),
    'airbnb': DesignLanguage(
      id: 'airbnb',
      name: '爱彼迎｜亲和友好',
      typography: const DesignTypography(
        bodyFamily: 'Inter',
        hero: 56,
        h1: 44,
        h2: 32,
        h3: 26,
        h4: 20,
        body: 16,
        bodySm: 14,
        caption: 13,
        micro: 12,
        lineHeight: 1.5,
      ),
      radius: const DesignRadius(xs: 6, sm: 8, md: 12, lg: 16, xl: 20, xxl: 24),
      spacing: const DesignSpacing(xs: 8, sm: 12, md: 16, lg: 20, xl: 24, xxl: 32, section: 60),
      shadow: const DesignShadow(levels: [
        ShadowSpec(blur: 4, offsetY: 1, opacity: 0.08),
        ShadowSpec(blur: 8, offsetY: 2, opacity: 0.10),
        ShadowSpec(blur: 12, offsetY: 3, opacity: 0.12),
        ShadowSpec(blur: 20, offsetY: 5, opacity: 0.14),
        ShadowSpec(blur: 32, offsetY: 8, opacity: 0.16),
      ]),
    ),
    'nike': DesignLanguage(
      id: 'nike',
      name: '耐克｜运动锐利',
      typography: const DesignTypography(
        displayFamily: 'Inter', // 粗黑控；显示级加粗权重由页面用 w800
        bodyFamily: 'Inter',
        hero: 72,
        h1: 56,
        h2: 40,
        h3: 30,
        h4: 24,
        body: 16,
        bodySm: 14,
        caption: 12,
        micro: 11,
        lineHeight: 1.4,
      ),
      radius: const DesignRadius(xs: 2, sm: 4, md: 6, lg: 8, xl: 12, xxl: 16),
      spacing: const DesignSpacing(xs: 6, sm: 10, md: 14, lg: 18, xl: 24, xxl: 32, section: 72),
      shadow: const DesignShadow(levels: [
        ShadowSpec(blur: 2, offsetY: 1, opacity: 0.10),
        ShadowSpec(blur: 4, offsetY: 2, opacity: 0.12),
        ShadowSpec(blur: 8, offsetY: 3, opacity: 0.14),
        ShadowSpec(blur: 14, offsetY: 5, opacity: 0.16),
        ShadowSpec(blur: 22, offsetY: 8, opacity: 0.18),
      ]),
    ),
    'clickhouse': DesignLanguage(
      id: 'clickhouse',
      name: 'ClickHouse｜数据清爽',
      typography: const DesignTypography(
        bodyFamily: 'Inter',
        hero: 60,
        h1: 48,
        h2: 34,
        h3: 26,
        h4: 20,
        body: 15,
        bodySm: 13,
        caption: 12,
        micro: 12,
        lineHeight: 1.5,
      ),
      radius: const DesignRadius(xs: 4, sm: 6, md: 8, lg: 10, xl: 12, xxl: 16),
      spacing: const DesignSpacing(xs: 8, sm: 12, md: 16, lg: 20, xl: 24, xxl: 32, section: 56),
      shadow: const DesignShadow(levels: [
        ShadowSpec(blur: 2, offsetY: 1, opacity: 0.06),
        ShadowSpec(blur: 4, offsetY: 2, opacity: 0.08),
        ShadowSpec(blur: 8, offsetY: 2, opacity: 0.10),
        ShadowSpec(blur: 12, offsetY: 4, opacity: 0.12),
        ShadowSpec(blur: 18, offsetY: 6, opacity: 0.14),
      ]),
    ),
    'apple': DesignLanguage(
      id: 'apple',
      name: '苹果｜简约高级',
      typography: const DesignTypography(
        bodyFamily: 'Inter',
        hero: 60,
        h1: 48,
        h2: 34,
        h3: 28,
        h4: 22,
        body: 17,
        bodySm: 15,
        caption: 13,
        micro: 12,
        lineHeight: 1.45,
      ),
      radius: const DesignRadius(xs: 8, sm: 12, md: 16, lg: 22, xl: 30, xxl: 40),
      spacing: const DesignSpacing(xs: 8, sm: 12, md: 16, lg: 20, xl: 24, xxl: 32, section: 60),
      shadow: const DesignShadow(levels: [
        ShadowSpec(blur: 4, offsetY: 1, opacity: 0.06),
        ShadowSpec(blur: 8, offsetY: 2, opacity: 0.08),
        ShadowSpec(blur: 14, offsetY: 3, opacity: 0.10),
        ShadowSpec(blur: 22, offsetY: 5, opacity: 0.12),
        ShadowSpec(blur: 36, offsetY: 8, opacity: 0.14),
      ]),
    ),
    'claude': DesignLanguage(
      id: 'claude',
      name: 'Claude｜温暖有机',
      typography: const DesignTypography(
        displayFamily: 'Serif', // 有机衬线展示
        bodyFamily: 'Inter',
        hero: 60,
        h1: 48,
        h2: 34,
        h3: 26,
        h4: 20,
        body: 16,
        bodySm: 14,
        caption: 13,
        micro: 12,
        lineHeight: 1.55,
      ),
      radius: const DesignRadius(xs: 6, sm: 10, md: 16, lg: 22, xl: 28, xxl: 36),
      spacing: const DesignSpacing(xs: 8, sm: 12, md: 16, lg: 20, xl: 24, xxl: 32, section: 64),
      shadow: const DesignShadow(levels: [
        ShadowSpec(blur: 6, offsetY: 1, opacity: 0.06),
        ShadowSpec(blur: 10, offsetY: 2, opacity: 0.08),
        ShadowSpec(blur: 16, offsetY: 4, opacity: 0.10),
        ShadowSpec(blur: 24, offsetY: 6, opacity: 0.10),
        ShadowSpec(blur: 40, offsetY: 10, opacity: 0.10),
      ]),
    ),
  };

  /// 按 id 取设计语言；未知 id 回退星巴克（默认）。
  static DesignLanguage byId(String? id) => all[id] ?? all['starbucks']!;
}
