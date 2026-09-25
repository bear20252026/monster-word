// 怪兽小屋（个人中心）专用色板（token 定义处）。
//
// 位置说明：色彩卫生守卫（M5）规定 Color(0x…) 字面量只允许出现在
// lib/tokens/** 定义处；小屋与聚宝日历共享暖纸/怪兽青绿/奖励金
//（见 treasure_palette.dart），本文件只补「木作 + 天色」家族色。
import 'package:flutter/material.dart';

abstract final class RoomPalette {
  // ── 木作家具 ──
  static const wood = Color(0xFFD9C9A8);
  static const woodDeep = Color(0xFFC4B088);
  static const woodDark = Color(0xFF8A6F4D);
  static const woodFrame = Color(0xFFB98D5F);
  static const woodSill = Color(0xFFA67C50);
  static const woodBase = Color(0xFF7A6244);

  // ── 窗外天色（日 / 暮 / 夜，外观&沉浸场景三态）──
  static const skyDay = Color(0xFFBFE3EA);
  static const skyDusk = Color(0xFFF2B28A);
  static const skyNight = Color(0xFF2C3A5E);
  static const cloud = Color(0xFFFFFFFF);
  static const sunDay = Color(0xFFFFD97A);
  static const sunDusk = Color(0xFFFF9D8A);
  static const moon = Color(0xFFFFF6E4);
  static const star = Color(0xFFFFE9B8);

  // ── 台灯光 ──
  static const lampGlow = Color(0xFFFFE9B8);

  // ── 家具细节 ──
  static const rugBase = Color(0xFFE5D8BC); // 地毯底 / 装备架高光
  static const groove = Color(0xFF4A3C20); // 黑胶纹
  static const toolboxLid = Color(0xFFE07F2E); // 工具箱腰线
  static const bookBlush = Color(0xFFF2B28A); // 书脊粉（与暮空同源）
}
