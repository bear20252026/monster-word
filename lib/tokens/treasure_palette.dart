// 聚宝日历专用色板（token 定义处）。
//
// 位置说明：色彩卫生守卫（M5）规定 Color(0x…) 字面量只允许出现在
// lib/tokens/** 定义处；聚宝日历为「暖纸色固定基调、不随明暗主题切换」的
// 外观专利设计页，故独立成板，消费处只引具名常量。
// 几何/视觉来源：deliverables/calendar-checkin-prototype.html 定稿参数。
import 'package:flutter/material.dart';

abstract final class TreasurePalette {
  // ── 暖纸基调（固定底，不参与主题切换）──
  static const paperTop = Color(0xFFF6F4EF);
  static const paper = Color(0xFFF2F0EB);
  static const paperBottom = Color(0xFFEDEBE9);
  static const card = Color(0xFFFFFDF8);
  static const line = Color(0x1A4A3C20); // rgba(74,60,32,.10)
  static const ink = Color(0xFF2B241A);
  static const dim = Color(0x8C4A3C20); // rgba(74,60,32,.55)
  static const faceStroke = Color(0x1A50420A); // rgba(80,66,40,.10)

  // ── 金色（仅奖励语义）──
  static const gold = Color(0xFFF6BD45);
  static const goldLight = Color(0xFFFFD97A);
  static const goldDeep = Color(0xFFD99A26);
  static const goldSoft = Color(0xFFFFE9B8);
  static const stampGold = Color(0xFF8A5A00);
  static const checkedNum = Color(0xFF6B4A00);
  static const gainText = Color(0xFFB5790F);

  // ── 品牌绿（仅 CTA / 今日描边）──
  static const green = Color(0xFF006241);
  static const greenLight = Color(0xFF0E8A60);
  static const greenDark = Color(0xFF004D34);

  // ── 点缀 ──
  static const coral = Color(0xFFFF7E69);
  static const cream = Color(0xFFFFF6E4);
  static const todayNum = Color(0xFF3A3126);
  static const futureNum = Color(0x4D4A3C20); // rgba(74,60,32,.30)
  static const futureFace = Color(0x0B000000); // rgba(0,0,0,.045)
  static const plainNum = Color(0xFF5A4F3A);
  static const dust = Color(0xFFC9B98F);
  static const pillShadow = Color(0x1F504228); // rgba(80,66,40,.12)
  static const ctaShadow = Color(0x52006241); // rgba(0,98,65,.32)
  static const ctaDisabledTop = Color(0xFFB9B3A8);
  static const ctaDisabledBottom = Color(0xFFA8A296);

  /// 粒子金币色（原型的 coinColors）。
  static const coinColors = [Color(0xFFF6BD45), Color(0xFFE8A13A), Color(0xFFFF9D8A), Color(0xFF00A574)];

  // ── 小怪兽储蓄罐（与 App 图标同源的青绿小怪兽）──
  static const pigSkinTop = Color(0xFF7FD4DC);
  static const pigSkinBottom = Color(0xFF4DB3C0);
  static const pigAccent = Color(0xFFF5923E); // 橙角 / 橙脚
  static const pigBellyBack = Color(0xFF2F8494); // 肚皮视窗底色
  static const pigDark = Color(0xFF20242B); // 黑豆眼 / 微笑
  static const pigBlush = Color(0xFF9ADFE6); // 浅色腮红
}
