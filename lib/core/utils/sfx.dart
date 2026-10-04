// Sfx：全 App 音效唯一出口（蓝图 W3「声音设计」v2.11.8 落地）。
//
// 三类短音（ui/quiz/celebrate/monster，assets/sfx/ 下按目录即分类），
// audioplayers 复用实例池防「每次 new 的可感延迟」；release 静音键三态
// （全开 → 仅视觉 → 全静音）持久化；夜间 22 点后全局 -6dB（默认关怀）。
// 红线：静音后所有庆祝保留完整视觉——juice 不依赖声音。
// 守卫：debug 每次播放打 debugLog（[SFX] 通道:音效）；同一音效 50ms 内
// 重复触发仅 debugLog 记录不中断（连击交互天然命中该窗口，不视为错误）。
import 'dart:async';

import 'package:audioplayers/audioplayers.dart';

import 'package:word_app/core/utils/debug_log.dart';
import 'package:word_app/core/utils/monster_rhythm.dart';

/// 音效通道（目录即分类，防混用）。
enum SfxChannel { ui, quiz, celebrate, monster }

/// 静音模式三态。
enum SfxMode {
  /// 全开（声音+视觉）。
  all,

  /// 仅视觉（声音 0，保留全部视觉庆祝）。
  visualOnly,

  /// 全静音（连视觉也只保留非庆祝性反馈）。
  silent,
}

/// 音效清单（路径即元数据：`assets/sfx/<channel>/<name>.wav`）。
enum Sfx {
  tap('ui/tap.wav'),
  toggle('ui/toggle.wav'),
  correctC5('quiz/correct_c5.wav'),
  correctD5('quiz/correct_d5.wav'),
  correctE5('quiz/correct_e5.wav'),
  correctG5('quiz/correct_g5.wav'),
  wrongSoft('quiz/wrong_soft.wav'),
  coinTick('quiz/coin_tick.wav'),
  comboBreak('quiz/combo_break.wav'),
  milestone('celebrate/milestone.wav'),
  evolve('celebrate/evolve.wav'),
  eggKnock('monster/egg_knock.wav'),
  hatchFlash('monster/hatch_flash.wav'),
  burp('monster/burp.wav'),
  purr('monster/purr.wav');

  const Sfx(this.assetPath);

  final String assetPath;

  String get _fullPath => 'assets/sfx/$assetPath';

  SfxChannel get channel {
    final dir = assetPath.split('/').first;
    return SfxChannel.values.firstWhere((c) => c.name == dir);
  }
}

/// 音效播放门面（全 App 唯一出口）。
class SfxPlayer {
  SfxPlayer._();

  /// 每通道一个复用实例（防每次 new 的延迟）；quiz 通道独占防串音。
  static final Map<SfxChannel, AudioPlayer> _players = {for (final c in SfxChannel.values) c: AudioPlayer()};

  /// 静音模式（SfxSettings 持久化后注入；默认全开）。
  static SfxMode mode = SfxMode.all;

  /// 上一帧播放时间戳（50ms 防抖，debug 断言用）。
  static final Map<Sfx, DateTime> _lastPlay = {};

  /// 是否夜间（22:00-次日 6:00）——全局 -6dB。
  /// 与 MonsterRhythm 夜息窗口对齐（同一节律，勿改出一套时间口径）。
  static bool get _isNight => MonsterRhythm.isSleepTime();

  /// 音量：通道基准 × 夜间衰减（纯函数表测锚点）。
  /// [mode] 非 all 一律 0（播放侧已短路，这里保证语义自洽）。
  static double volumeFor(SfxChannel channel, {required SfxMode mode, required bool isNight}) {
    if (mode != SfxMode.all) return 0;
    // celebrate 全量；quiz/ui 打折；monster 次之；夜间统一 -6dB（约 ×0.5）。
    const base = {SfxChannel.celebrate: 1.0, SfxChannel.quiz: 0.85, SfxChannel.ui: 0.6, SfxChannel.monster: 0.8};
    final v = base[channel] ?? 0.8;
    return isNight ? v * 0.5 : v;
  }

  static double _volumeFor(SfxChannel channel) => volumeFor(channel, mode: mode, isNight: _isNight);

  /// 播放一次音效（静音/仅视觉模式下为 no-op，视觉庆祝照常）。
  static Future<void> play(Sfx sfx) async {
    // 仅视觉档此前只把音量归零仍解码播放——白白占用音频焦点，直接短路。
    if (mode != SfxMode.all) return;
    _assertNoSpam(sfx);
    final player = _players[sfx.channel]!;
    try {
      await player.stop();
      await player.setVolume(_volumeFor(sfx.channel));
      // AssetSource 路径不带 assets/ 前缀（audioplayers 惯例）。
      final rel = sfx._fullPath.replaceFirst('assets/', '');
      await player.play(AssetSource(rel));
      debugLog('[SFX] ${sfx.channel.name}:${sfx.assetPath}');
    } catch (e) {
      // 音效失败绝不影响主流程（静默 + debug 可见；无 A 级数据路径）。
      debugLog('[SFX] play failed: $e');
    }
  }

  /// 同步便捷入口（fire-and-forget；答题热路径用这个）。
  static void fire(Sfx sfx) {
    unawaited(play(sfx));
  }

  static void _assertNoSpam(Sfx sfx) {
    final now = DateTime.now();
    final last = _lastPlay[sfx];
    _lastPlay[sfx] = now;
    if (last != null && now.difference(last).inMilliseconds < 50) {
      // 只记录不断言：破壳敲蛋（连敲三下）等合法快速交互天然命中 50ms
      // 窗口，断言会崩 debug 构建与 widget 测试（2026-10-04 CI 实证假红源）。
      debugLog('[SFX] 50ms 内重复触发：${sfx.assetPath}');
    }
  }

  /// 释放全部实例（测试/退出）。释放后播放器重建——清空映射会让后续
  /// `play()` 的 `_players[sfx.channel]!` 空断言崩溃，池必须始终可用。
  static Future<void> disposeAll() async {
    for (final c in SfxChannel.values) {
      final old = _players.remove(c);
      await old?.dispose();
      _players[c] = AudioPlayer();
    }
  }
}
