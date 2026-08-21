// 由账号4生成
// 原版 UI 主题：颜色/尺寸/字体（从 v5.0 版 colors.xml + styles.xml + dimens.xml 提取）
import 'package:flutter/material.dart';

/// 原版颜色（从 styles.xml 提取）
class AppColors {
  // 学习按钮三色（原版）
  static const successGreen = Color(0xFF22A18B); // ui_prompt_success 认识
  static const highlightOrange = Color(0xFFFEBB10); // common_highlight2 模糊
  static const errorRed = Color(0xFFC64353); // ui_prompt_error 看答案

  // 文字色（原版）
  static const black87 = Color(0xDE000000); // black87Color
  static const black54 = Color(0x8A000000); // black54_color
  static const black12 = Color(0x1F000000); // black12_color
  static const white100 = Color(0xFFFFFFFF); // white100_color

  // 主题背景（原版主界面渐变绿）
  static const mainBgTop = Color(0xFF3EB489); // 顶部青绿
  static const mainBgBottom = Color(0xFF1F7A68); // 底部深绿

  // 卡片/面板色
  static const cardBg = Color(0xFFFFFFFF);
  static const dividerGrey = Color(0xFFEDEDED);
  static const textTertiary = Color(0xFF999999); // text_tertiary

  // 签到组件色（BBCheckIn）
  static const checkInBg = Color(0x33FFFFFF);
  static const checkInAccent = Color(0xFFFFF8E1);
}

/// 原版尺寸（从 dimens.xml 提取）
class AppDimens {
  static const learnBtnTextSize = 16.0; // learn_btn_textSize
  static const learnMainWord = 40.0; // learn_review_main_word
  static const learnMainWordNew = 36.0; // learn_review_main_word_new
  static const bottomBarBtnMargin = 8.0; // lr_bottom_bar_btn_margin
  static const selectItemHeight = 64.0; // select_item_height
  static const selectItemLrMargins = 16.0; // select_item_lr_margins
  static const selectItemBottomMargins = 8.0; // select_item_bottom_margins
  static const bottomBarHeight = 48.0; // 底部栏
  static const buttonCtaHeight = 48.0; // button_cta_height
  static const pageCommonMargin = 16.0; // page_common_margin
  static const radiusNormal = 8.0; // toolbar_learn_button_bg 圆角
}
