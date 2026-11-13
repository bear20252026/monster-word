// Monster Word — 首页（"今日"版式）
// 层级：问候头部 → 今日进度主卡（学习/复习 CTA）→ 签到条 → 词书条 → 目标档位 → 引言脚注
import 'package:word_app/widgets/common/mw_feedback.dart';

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:word_app/app/router/route_names.dart';
import 'package:word_app/core/application/today_progress_store.dart';
import 'package:word_app/core/presentation/responsive.dart';
import 'package:word_app/features/book/application/book_catalog_reader.dart';
import 'package:word_app/features/checkin/application/checkin_status_reader.dart';
import 'package:word_app/features/checkin/application/streak_milestones.dart';
import 'package:word_app/features/learning/application/home_next_step.dart';
import 'package:word_app/features/learning/application/home_path.dart';
// P2-6：home 独立成域后，会话经 learning 的 application 端口消费（R4），
// 不再 import learning/presentation 的可变状态对象。
import 'package:word_app/features/learning/application/learning_session_reader.dart';
import 'package:word_app/features/learning/application/learning_session_starter.dart';

import 'home_path_map.dart';

// M2：每日任务（只 import 对方的 application 层，架构守卫 R4 允许）。
import 'package:word_app/features/missions/application/daily_mission_reward_service.dart';
import 'package:word_app/features/missions/application/daily_mission_store.dart';
// M3：等级角标（跨 feature 只 import 对方的 application 层，架构守卫 R4 允许）。
import 'package:word_app/features/progress/application/xp_store.dart';
import 'package:word_app/features/scare_coin/application/scare_coin_store.dart';
import 'package:word_app/theme/skin_system.dart';
import 'package:word_app/tokens/design_tokens.dart';
import 'package:word_app/tokens/motion_tokens.dart';
import 'package:word_app/tokens/star_gold.dart';
import 'package:word_app/widgets/confetti.dart';
import 'package:word_app/widgets/app_dock.dart';
import 'package:word_app/widgets/mw_card.dart';
import 'package:word_app/widgets/daily_goal_picker.dart';

import 'review_dialog.dart';

import 'package:word_app/widgets/scale_down_on_press.dart';
import 'package:word_app/widgets/testimonial_slider.dart' show TestimonialData;

part 'home/home_header.dart';
part 'home/home_hero.dart';
part 'home/home_path.dart';
part 'home/home_strips.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final resp = context.responsive;
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    // 下滑查词：在首页任意位置向下滑动打开查词页
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragEnd: (details) {
        final v = details.primaryVelocity ?? 0;
        if (v > 160) Navigator.pushNamed(context, RouteNames.search);
      },
      child: Container(
        color: skin.colors.pageBg,
        child: SafeArea(
          bottom: false,
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: isLandscape ? double.infinity : resp.contentMaxWidth),
              child: Padding(
                // 底部为悬浮 Dock 预留空隙（Dock 悬浮于内容之上）
                padding: EdgeInsets.only(bottom: FloatingDock.clearance(context) + 8),
                child: isLandscape ? _buildLandscape(context, skin, resp) : _buildPortrait(context, skin, resp),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---- 竖屏 ----

  Widget _buildPortrait(BuildContext context, SkinSystem skin, AppResponsive resp) {
    return Column(
      children: [
        _EntranceIn(child: _Header(skin: skin)),
        // 今日路线（灰度）：默认关闭；关闭时与旧版逐像素一致。
        if (kPathHome)
          _EntranceIn(
            delayMs: 60,
            child: Padding(
              padding: EdgeInsets.fromLTRB(resp.pageMargin, 0, resp.pageMargin, 12),
              child: const _HomePathSection(),
            ),
          ),
        const Spacer(flex: 3),
        // 今日进度主卡（唯一视觉锚点）
        _EntranceIn(
          delayMs: 80,
          child: Padding(
            padding: EdgeInsets.fromLTRB(resp.pageMargin, 0, resp.pageMargin, 12),
            child: const _TodayHeroCard(),
          ),
        ),
        // 签到条
        _EntranceIn(
          delayMs: 180,
          child: Padding(
            padding: EdgeInsets.fromLTRB(resp.pageMargin, 0, resp.pageMargin, 12),
            child: const _CheckInStrip(),
          ),
        ),
        // 每日任务条（M2）：一行摘要，点开看三条任务
        _EntranceIn(
          delayMs: 220,
          child: Padding(
            padding: EdgeInsets.fromLTRB(resp.pageMargin, 0, resp.pageMargin, 12),
            child: const _MissionStrip(),
          ),
        ),
        // 当前词书条
        _EntranceIn(
          delayMs: 260,
          child: Padding(
            padding: EdgeInsets.fromLTRB(resp.pageMargin, 0, resp.pageMargin, 12),
            child: const _BookStrip(),
          ),
        ),
        // 每日目标快捷档位
        _EntranceIn(
          delayMs: 340,
          child: Padding(
            padding: EdgeInsets.fromLTRB(resp.pageMargin, 0, resp.pageMargin, 0),
            child: const _GoalChips(),
          ),
        ),
        const Spacer(flex: 2),
        // 每日一句脚注
        _EntranceIn(delayMs: 420, child: const _QuoteFooter()),
      ],
    );
  }

  // ---- 横屏：左右分栏 ----

  Widget _buildLandscape(BuildContext context, SkinSystem skin, AppResponsive resp) {
    return Column(
      children: [
        _EntranceIn(child: _Header(skin: skin)),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Padding(padding: EdgeInsets.all(resp.pageMargin), child: const _TodayHeroCard()),
              ),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.all(resp.pageMargin),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _EntranceIn(delayMs: 180, child: const _CheckInStrip()),
                      const SizedBox(height: 12),
                      _EntranceIn(delayMs: 220, child: const _MissionStrip()),
                      const SizedBox(height: 12),
                      _EntranceIn(delayMs: 260, child: const _BookStrip()),
                      const SizedBox(height: 12),
                      _EntranceIn(delayMs: 340, child: const _GoalChips()),
                      const SizedBox(height: 16),
                      _EntranceIn(delayMs: 420, child: const _QuoteFooter()),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
