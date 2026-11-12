// Monster Word — 特效装饰调色板（M5 收口，v2.7.43）
//
// 这是全库唯一允许承载"特效/装饰类"Color(0x…) 字面量的非定义处白名单文件
// （见 test/architecture/color_hygiene_test.dart）。规则：
// - 语义色 → ThemeVars（skin）/ FuncColors / MwColors，禁入本文件；
// - 品牌色 → 引用 StarbucksCreamColors 既有常量，不在本文件复写字面量；
// - 新特效只能把色值加到这里并具名，禁止组件内裸写字面量。
import 'package:flutter/material.dart';

import 'package:word_app/tokens/starbucks_tokens.dart';

/// 彩纸/庆祝粒子色（confetti.dart 专用，庆祝场景固定高饱和，不随主题）
class PartyColors {
  static const Color red = Color(0xFFFF6B6B);
  static const Color yellow = Color(0xFFFFD93D);
  static const Color green = Color(0xFF6BCB77);
  static const Color blue = Color(0xFF4D96FF);
  static const Color purple = Color(0xFFC77DFF);
  static const Color orange = Color(0xFFFF922B);

  /// 彩纸发射默认调色板（confetti 两处发射共用一份列表）
  static const List<Color> confetti = [red, yellow, green, blue, purple, orange];
}

/// GameBoy 复古配色（home_screen 像素风彩蛋装饰）
/// 吉祥物形象色（monster_icon.dart 角色绘制专用）
class MonsterPalette {
  /// 浅青色肚皮
  static const Color belly = Color(0xFFB8E6E0);

  /// 眼睛/轮廓深色
  static const Color eye = Color(0xFF2D2D2D);

  /// 腮红粉
  static const Color blush = Color(0xFFFF9999);

  /// 张开的嘴内腔（吞金币庆祝：mouthOpen>0 时绘制）
  static const Color mouthInner = Color(0xFF6B3A2A);

  /// 张开的嘴内小舌头
  static const Color tongue = Color(0xFFFF8A80);

  /// 进化金（7天尖角金角／30天飞翼描边／100天光环，吉祥物进化专用）
  static const Color evoGold = Color(0xFFD9A62E);
}

/// 记忆兽图鉴配色（蓝图 T3 demo：难度定配色稀有度，固定装饰色不随主题）。
/// 稀有不是抽奖，是啃下了难词——三档只是颜色不同，无数值高低。
class MemoryBeastPalette {
  /// 常见（短词）：苔绿
  static const Color common = Color(0xFF7FB069);

  /// 少见（中长词）：雾蓝
  static const Color uncommon = Color(0xFF6D9DC5);

  /// 稀有（长词）：星紫
  static const Color rare = Color(0xFFB08BC9);
}

/// 品牌渐变组合（多处双写已收口为共享常量）
class GradientEffects {
  /// 启动屏品牌渐变（splash_page：绿→金→彩纸蓝）
  static const List<Color> splash = [
    StarbucksCreamColors.greenHouse,
    StarbucksCreamColors.greenSignature,
    StarbucksCreamColors.vipGoldBg,
    PartyColors.blue,
  ];

  /// 庆祝渐变（learn_page / immersive_swipe_page 双写收口：绿→金→彩纸黄绿）
  static const List<Color> celebration = [
    StarbucksCreamColors.greenHouse,
    StarbucksCreamColors.greenSignature,
    StarbucksCreamColors.vipGoldBg,
    PartyColors.yellow,
    PartyColors.green,
  ];

  /// 液态 Logo 渐变（liquid_logo.dart：绿四层）
  static const List<Color> liquidLogo = [
    StarbucksCreamColors.greenHouse,
    StarbucksCreamColors.greenSignature,
    StarbucksCreamColors.greenBanner,
    StarbucksCreamColors.vipGoldBg,
  ];
}
