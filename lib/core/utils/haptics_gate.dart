// HapticsGate：全 App 触觉反馈唯一出口（蓝图 W3「触觉四档分配」）。
//
// 红线：业务代码禁止直接 import HapticFeedback（守卫测试
// test/architecture/haptics_gate_test.dart 白名单=本文件），与
// debug_print_guard 同构。error/warning 波形按蓝图弃用——与「不惩罚」
// 人设冲突（答错无触觉，缺席本身就是信号）。
//
// 平台语义：HapticFeedback 在 Windows 下为 no-op（Flutter 引擎不实现），
// 测试环境同样安全（无平台通道调用）；Android/iOS 正常生效。
import 'package:flutter/services.dart';

/// 触觉语义档位（与蓝图「一天旅程配乐单」映射一致）。
enum HapticCue {
  /// 选项点选/翻卡等输入确认。
  tap,

  /// 普通答对、普通按钮。
  light,

  /// 连对 ≥3 的答对、金币单次 +10。
  medium,

  /// 里程碑庆祝/怪兽进化/开箱。
  heavy,

  /// 今日目标达成（Flutter 无专用 success 触觉，用 medium 近似，注释留档）。
  success,
}

class HapticsGate {
  HapticsGate._();

  /// 播放一次触觉（全 App 唯一出口）。
  static void play(HapticCue cue) {
    switch (cue) {
      case HapticCue.tap:
        HapticFeedback.selectionClick();
      case HapticCue.light:
        HapticFeedback.lightImpact();
      case HapticCue.medium:
      case HapticCue.success:
        // success 无专用波形：mediumImpact + 注释语义（蓝图口径）。
        HapticFeedback.mediumImpact();
      case HapticCue.heavy:
        HapticFeedback.heavyImpact();
    }
  }
}
