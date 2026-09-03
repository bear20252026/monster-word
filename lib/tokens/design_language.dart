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
// - 向下兼容：既有静态常量 AppRadius/AppSpacing/MwTypography/设计_tokens 保留，
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
/// 数值来源：design/品牌目录/DESIGN.md（npx getdesign 下载的官方设计系统文档），
/// 1:1 对齐其 rounded/spacing/typography/shadow 章节。
class DesignLanguages {
  static final Map<String, DesignLanguage> all = {
    // Starbucks：卡片 12px、按钮 50px 全胶囊、-0.01em 紧字距、行高 1.5、
    // 卡片阴影 0 .5px rgba(0,0,0,.14) + 0 1px 1px rgba(0,0,0,.24)。
    'starbucks': DesignLanguage(
      id: 'starbucks',
      name: '星巴克｜奶油温润',
      typography: const DesignTypography(
        bodyFamily: 'Inter', // SoDoSans 开源替身
        hero: 64,
        h1: 48,
        h2: 36,
        h3: 28,
        h4: 22,
        body: 16,
        bodySm: 14,
        caption: 13,
        micro: 12,
        lineHeight: 1.5,
      ),
      radius: const DesignRadius(
        xs: 4,
        sm: 8,
        md: 12,
        lg: 16,
        xl: 24,
        xxl: 32,
        card: 12,
        control: 50,
        glass: 12,
        sheet: 12,
        radiusNormal: 12,
      ),
      spacing: const DesignSpacing(xs: 8, sm: 12, md: 16, lg: 20, xl: 24, xxl: 32, section: 64),
      shadow: const DesignShadow(
        levels: [
          ShadowSpec(blur: 6, offsetY: 1, opacity: 0.10),
          ShadowSpec(blur: 8, offsetY: 1, opacity: 0.14),
          ShadowSpec(blur: 12, offsetY: 2, opacity: 0.16),
          ShadowSpec(blur: 18, offsetY: 4, opacity: 0.18),
          ShadowSpec(blur: 28, offsetY: 8, opacity: 0.22), // Frap 悬浮层级
        ],
      ),
    ),
    // Airbnb：rounded xs4/sm8/md14/lg20/xl32；按钮 8px 圆角、搜索球全胶囊；
    // 卡片 14px；spacing 2-64、section 64；阴影极轻。
    'airbnb': DesignLanguage(
      id: 'airbnb',
      name: '爱彼迎｜亲和友好',
      typography: const DesignTypography(
        bodyFamily: 'Inter', // Airbnb Cereal 开源替身
        hero: 32,
        h1: 28,
        h2: 22,
        h3: 20,
        h4: 16,
        body: 16,
        bodySm: 14,
        caption: 13,
        micro: 12,
        lineHeight: 1.43,
      ),
      radius: const DesignRadius(
        xs: 4,
        sm: 8,
        md: 14,
        lg: 20,
        xl: 32,
        xxl: 32,
        card: 14,
        control: 8,
        glass: 16,
        sheet: 32,
        radiusNormal: 8,
      ),
      spacing: const DesignSpacing(xxs: 2, xs: 4, sm: 8, md: 12, lg: 16, xl: 24, xxl: 32, section: 64),
      shadow: const DesignShadow(
        levels: [
          ShadowSpec(blur: 4, offsetY: 1, opacity: 0.06),
          ShadowSpec(blur: 8, offsetY: 2, opacity: 0.08),
          ShadowSpec(blur: 12, offsetY: 3, opacity: 0.10),
          ShadowSpec(blur: 20, offsetY: 5, opacity: 0.12),
          ShadowSpec(blur: 32, offsetY: 8, opacity: 0.14),
        ],
      ),
    ),
    // Nike：产品卡 0 圆角 0 阴影（照片即卡片）、按钮/搜索/筛选全胶囊（30px 级）；
    // 8px 基、section 48；Helvetica 系、正文行高 1.5。
    'nike': DesignLanguage(
      id: 'nike',
      name: '耐克｜运动锐利',
      typography: const DesignTypography(
        displayFamily: 'Inter', // Futura/Helvetica Now 替身；展示级大写由页面控制
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
        lineHeight: 1.5,
      ),
      radius: const DesignRadius(
        xs: 0,
        sm: 8,
        md: 18,
        lg: 24,
        xl: 30,
        xxl: 30,
        card: 0,
        control: 9999,
        glass: 24,
        sheet: 30,
        radiusNormal: 9999,
      ),
      spacing: const DesignSpacing(xs: 4, sm: 8, md: 12, lg: 18, xl: 24, xxl: 30, section: 48),
      shadow: const DesignShadow(
        levels: [
          ShadowSpec(blur: 2, offsetY: 1, opacity: 0.06),
          ShadowSpec(blur: 4, offsetY: 2, opacity: 0.08),
          ShadowSpec(blur: 8, offsetY: 3, opacity: 0.10),
          ShadowSpec(blur: 14, offsetY: 5, opacity: 0.12),
          ShadowSpec(blur: 22, offsetY: 8, opacity: 0.14),
        ],
      ),
    ),
    // ClickHouse：rounded xs4/sm6/md8/lg12；spacing 4-96、section 96；
    // Inter 700 展示级 -2.5px~-1px 负字距；暗底阴影极轻。
    'clickhouse': DesignLanguage(
      id: 'clickhouse',
      name: 'ClickHouse｜数据清爽',
      typography: const DesignTypography(
        bodyFamily: 'Inter',
        hero: 64,
        h1: 48,
        h2: 36,
        h3: 28,
        h4: 22,
        body: 16,
        bodySm: 14,
        caption: 13,
        micro: 12,
        lineHeight: 1.55,
      ),
      radius: const DesignRadius(
        xs: 4,
        sm: 6,
        md: 8,
        lg: 12,
        xl: 16,
        xxl: 16,
        card: 12,
        control: 8,
        glass: 12,
        sheet: 12,
        radiusNormal: 8,
      ),
      spacing: const DesignSpacing(xs: 8, sm: 12, md: 16, lg: 24, xl: 32, xxl: 48, section: 96),
      shadow: const DesignShadow(
        levels: [
          ShadowSpec(blur: 2, offsetY: 1, opacity: 0.08),
          ShadowSpec(blur: 4, offsetY: 2, opacity: 0.10),
          ShadowSpec(blur: 8, offsetY: 3, opacity: 0.12),
          ShadowSpec(blur: 12, offsetY: 4, opacity: 0.14),
          ShadowSpec(blur: 18, offsetY: 6, opacity: 0.16),
        ],
      ),
    ),
    // Apple：rounded xs5/sm8/md11/lg18；spacing md17、section 80；SF Pro 系
    // （Flutter 内用系统默认近似）；按钮全胶囊 11px 22px；唯一签名阴影
    // rgba(0,0,0,0.22) 3px 5px 30px 仅用于产品图。
    'apple': DesignLanguage(
      id: 'apple',
      name: '苹果｜简约高级',
      typography: const DesignTypography(
        bodyFamily: 'Inter', // SF Pro 替身（系统字体在 Apple 平台自动命中 SF）
        hero: 56,
        h1: 48,
        h2: 40,
        h3: 34,
        h4: 28,
        body: 17,
        bodySm: 15,
        caption: 13,
        micro: 12,
        lineHeight: 1.47,
      ),
      radius: const DesignRadius(
        xs: 5,
        sm: 8,
        md: 11,
        lg: 18,
        xl: 24,
        xxl: 32,
        card: 18,
        control: 9999,
        glass: 18,
        sheet: 20,
        radiusNormal: 12,
      ),
      spacing: const DesignSpacing(xs: 8, sm: 12, md: 17, lg: 24, xl: 32, xxl: 48, section: 80),
      shadow: const DesignShadow(
        levels: [
          ShadowSpec(blur: 4, offsetY: 1, opacity: 0.04),
          ShadowSpec(blur: 10, offsetY: 2, opacity: 0.06),
          ShadowSpec(blur: 20, offsetY: 3, opacity: 0.10),
          ShadowSpec(blur: 30, offsetY: 5, opacity: 0.22), // 签名产品图阴影
          ShadowSpec(blur: 44, offsetY: 9, opacity: 0.14),
        ],
      ),
    ),
    // Claude：rounded xs4/sm6/md8/lg12/xl16；spacing 4/8/12/16/24/32/48、
    // section 96；Copernicus 衬线 400 展示 + StyreneB/Inter 正文；阴影几乎不用
    // （仅 0 1px 3px rgba(20,20,19,0.08)），层次靠奶油画布/奶油卡/暗面色块。
    'claude': DesignLanguage(
      id: 'claude',
      name: 'Claude｜温暖有机',
      typography: const DesignTypography(
        displayFamily: 'Serif', // Copernicus/Tiempos 替身：衬线 400 + 负字距
        bodyFamily: 'Inter',
        hero: 64,
        h1: 48,
        h2: 36,
        h3: 28,
        h4: 22,
        body: 16,
        bodySm: 14,
        caption: 13,
        micro: 12,
        lineHeight: 1.55,
      ),
      radius: const DesignRadius(
        xs: 4,
        sm: 6,
        md: 8,
        lg: 12,
        xl: 16,
        xxl: 24,
        card: 12,
        control: 8,
        glass: 12,
        sheet: 12,
        radiusNormal: 8,
      ),
      spacing: const DesignSpacing(xs: 8, sm: 12, md: 16, lg: 24, xl: 32, xxl: 48, section: 96),
      shadow: const DesignShadow(
        levels: [
          ShadowSpec(blur: 3, offsetY: 1, opacity: 0.08),
          ShadowSpec(blur: 6, offsetY: 1, opacity: 0.08),
          ShadowSpec(blur: 10, offsetY: 2, opacity: 0.08),
          ShadowSpec(blur: 16, offsetY: 4, opacity: 0.08),
          ShadowSpec(blur: 24, offsetY: 6, opacity: 0.08),
        ],
      ),
    ),
  };

  /// 按 id 取设计语言；未知 id 回退星巴克（默认）。
  static DesignLanguage byId(String? id) => all[id] ?? all['starbucks']!;
}
