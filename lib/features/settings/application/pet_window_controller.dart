// 第四轮审计 M5（2026-11-17）：桌面宠物开关编排下沉 application。
//
// 原 more_settings_page 内联约 120 行竞态敏感逻辑（C3 in-flight 闸 / R20
// 返回值复核 / T20 首查 busy 闸 + 失败路径复核 / C6 可见性事件订阅），
// 与页面 UI 混在一起难以单测。现抽为独立控制器：页面只消费 visible 通知
// 与 toggle 命令，竞态口径逐条保留（注释随迁）。
//
// 可测性：PetWindowService 与 CheckinStatusReader 均经构造注入，
// 平台通道/跨域端口在测试里可替换为可控假件。
import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:word_app/core/infrastructure/pet_window_service.dart';
import 'package:word_app/core/utils/debug_log.dart';
import 'package:word_app/core/utils/monster_speech.dart';
import 'package:word_app/core/utils/swallowed_error_report.dart';
import 'package:word_app/features/checkin/application/checkin_status_reader.dart';

/// 桌面宠物窗口开关控制器（状态在原生，本类只做对齐与竞态防护）。
class PetWindowController extends ChangeNotifier {
  PetWindowController({PetWindowService? service, this.checkinReader}) : _service = service ?? const PetWindowService();

  final PetWindowService _service;

  /// 签到天数读取端口（开窗时带给第二 engine；null = 不带，宠物用默认态）。
  final CheckinStatusReader? checkinReader;

  bool _visible = false;
  bool get visible => _visible;

  bool get isSupported => _service.isSupported;

  /// 审计 C3（2026-11-15）：Switch.onChanged 与整行 onTap 都触发 toggle，
  /// getCheckinDates 的 await 拉长竞态窗；快速双击会开+关最终态与意图相反。
  /// in-flight 闸拒重入。
  bool _toggleBusy = false;
  bool get toggleBusy => _toggleBusy;

  StreamSubscription<bool>? _visibilitySub;
  bool _disposed = false;

  /// 页面 initState 调用：订阅原生可见性事件 + 首查对齐。
  void attach() {
    if (!_service.isSupported) return;
    _service.listenVisibilityEvents();
    _visibilitySub = _service.visibilityChanges.listen((visible) {
      // 审计 R20（2026-11-16）：toggle 在途时忽略事件——右键关窗事件先到置
      // false，随后 toggle 返回 true 覆盖会谎报开启。在途期间以 toggle 完成
      // 后的 isVisible 复核为准（事件可能早于原生窗口真正销毁/创建）。
      if (!_disposed && !_toggleBusy) _setVisible(visible);
    });
    unawaited(
      _service
          .isVisible()
          .then((visible) {
            // 第三轮 T20：首查慢回时用户可能已在途 toggle——与事件监听同口径
            // 加 busy 闸，防旧查询结果覆盖在途开关状态。
            if (!_disposed && !_toggleBusy) _setVisible(visible);
          })
          .catchError((Object e) => debugLog('查询桌面宠物状态失败: $e')),
    );
  }

  void _setVisible(bool value) {
    if (_visible == value) return;
    _visible = value;
    notifyListeners();
  }

  /// 开关的真实状态在原生（窗口存在与否），所以以**返回值**为准更新 UI，
  /// 不用传进去的 [on] —— 否则原生开失败时界面会说谎。
  ///
  /// 返回本次操作后 UI 应呈现的可见性（供页面决定是否提示失败）；
  /// 在途重入被拒时返回当前显示态。
  Future<bool> toggle(bool on) async {
    if (_toggleBusy) return _visible;
    _toggleBusy = true;
    try {
      // 宠物窗口是第二个 engine，读不到主应用状态 ⇒ 签到天数只能开窗时带过去。
      int? days;
      final reader = checkinReader;
      if (on && reader != null) {
        try {
          days = (await reader.getCheckinDates()).length;
        } catch (e, s) {
          reportSwallowedError('桌面宠物读取签到天数失败', e, s);
        }
      }
      final visible = await _service.toggle(
        days: days,
        personality: MonsterSpeech.currentPersonality.name,
      ); // P2-3 性格随开窗带过去
      if (_disposed) return visible;
      // 审计 R20（2026-11-16）：toggle 返回值可能滞后于在途右键关窗——落状态前
      // 复核原生真实可见性（查询失败回退 toggle 返回值），杜绝短暂谎报开启。
      var actual = visible;
      try {
        actual = await _service.isVisible();
      } catch (_) {
        // 吞错豁免: 复核失败回退 toggle 返回值，不阻断开关流程。
      }
      if (_disposed) return actual;
      _setVisible(actual);
      return actual;
    } catch (e, s) {
      reportSwallowedError('桌面宠物窗口开关失败', e, s);
      if (_disposed) return _visible;
      // 第三轮 T20：失败路径同样复核原生真实可见性——busy 期间被忽略的
      // 右键关窗事件不会重放，不复核则开关态与原生脱节直至下一事件。
      try {
        final actual = await _service.isVisible();
        if (!_disposed) _setVisible(actual);
      } catch (_) {
        // 吞错豁免: 复核失败保持当前显示态，下一可见性事件会再对齐。
      }
      return _visible;
    } finally {
      _toggleBusy = false;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _visibilitySub?.cancel();
    super.dispose();
  }
}
