// Monster Word App
//
// Spug Push 短信验证码实现（data 层）。
// App 直连 https://push.spug.cc/sms/<TEMPLATE_CODE>，本地生成并缓存验证码，
// 输入时本地比对（5 分钟有效期）。
//
// ⚠️ P0-01（外部审计 MW-09/10/11/19/20/21）：模板码为调用凭证，随包分发存在
// 被盗刷风险（Spug 官方文档建议由服务端发起）。根治手段是**服务端代理**：
// 由服务端持有凭证、生成并校验验证码，客户端完全不接触模板码。
//
// 服务端代理属**运维/服务端工程**（需在 Spug 控制台轮换凭证 + 部署代理服务），
// 本仓库无法独立完成。仓库侧已做的收口：
//   1. 验证码一次性消费（10-08 批次）——同一码在 TTL 内不可重复通过；
//   2. 凭证可注入（本轮）——模板码支持 `--dart-define=SPUG_TEMPLATE_CODE=...`
//      覆盖，轮换后无需改代码即可出包；
//   3. 持久化发送节流（本轮）——单设备同号 60s 冷却 + 每日上限，把盗刷规模
//      压到可观测范围，为凭证轮换争取时间窗。
//
// 服务端代理就绪后，只需新增一个 SmsCodeService 实现并在装配处切换，
// 页面与调用方无需改动（端口见 application/sms_code_service.dart）。

import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:word_app/features/account/application/sms_code_service.dart';
import 'package:word_app/core/utils/swallowed_error_report.dart';

/// 短信发送节流（持久化，跨重启生效）。
///
/// 定位说明：客户端限流**不是安全边界**（重装应用即可清零），它的作用是
/// 把「单设备被盗刷的规模」压到可观测、可控的范围，为凭证轮换争取时间。
/// 节流设施自身故障时一律**放行**——不能让风控设施把正常用户挡在门外。
class SmsSendThrottle {
  SmsSendThrottle({this.cooldown = const Duration(seconds: 60), this.dailyLimit = 10, this.enabled = true});

  /// 完全禁用的节流（单元测试与特殊环境用）。
  const SmsSendThrottle.disabled() : cooldown = Duration.zero, dailyLimit = 0, enabled = false;

  /// 同一手机号的发送冷却。
  final Duration cooldown;

  /// 每设备每日发送上限（0 表示不限制）。
  final int dailyLimit;

  final bool enabled;

  static const String _lastKeyPrefix = 'sms_send_last_v1:';
  static const String _dailyKey = 'sms_send_daily_v1';

  /// 检查是否允许发送。允许返回 null，否则返回用户可读的拒绝原因。
  Future<String?> check(String phone, DateTime now) async {
    if (!enabled) return null;
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastMs = prefs.getInt('$_lastKeyPrefix$phone');
      if (lastMs != null) {
        final elapsed = now.difference(DateTime.fromMillisecondsSinceEpoch(lastMs));
        if (elapsed < cooldown) {
          final remain = cooldown.inSeconds - elapsed.inSeconds;
          return '发送过于频繁，请 ${remain > 0 ? remain : 1} 秒后重试';
        }
      }
      if (dailyLimit > 0) {
        final daily = prefs.getString(_dailyKey);
        if (daily != null && daily.isNotEmpty) {
          final decoded = jsonDecode(daily);
          if (decoded is Map<String, dynamic> && decoded['date'] == _dayKey(now)) {
            final count = (decoded['count'] as num?)?.toInt() ?? 0;
            if (count >= dailyLimit) return '今日验证码发送次数已达上限，请明日再试';
          }
        }
      }
      return null;
    } catch (e, s) {
      reportSwallowedError('短信发送节流检查失败（放行）', e, s);
      return null;
    }
  }

  /// 发送成功后计数。
  Future<void> record(String phone, DateTime now) async {
    if (!enabled) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('$_lastKeyPrefix$phone', now.millisecondsSinceEpoch);
      final today = _dayKey(now);
      var count = 0;
      final daily = prefs.getString(_dailyKey);
      if (daily != null && daily.isNotEmpty) {
        final decoded = jsonDecode(daily);
        if (decoded is Map<String, dynamic> && decoded['date'] == today) {
          count = (decoded['count'] as num?)?.toInt() ?? 0;
        }
      }
      await prefs.setString(_dailyKey, jsonEncode({'date': today, 'count': count + 1}));
    } catch (e, s) {
      reportSwallowedError('短信发送节流计数写入失败', e, s);
    }
  }

  static String _dayKey(DateTime now) =>
      '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
}

class SpugSmsCodeService implements SmsCodeService {
  SpugSmsCodeService({http.Client? client, DateTime Function()? now, SmsSendThrottle? throttle})
    : _client = client ?? http.Client(),
      _now = now ?? DateTime.now,
      _throttle = throttle ?? SmsSendThrottle();

  /// 模板码支持构建期注入：轮换凭证后无需改动源码即可出包。
  /// 默认值对应当前线上凭证（用户已书面接受「随包分发」的既有风险，
  /// 待服务端代理上线后本常量整体移除）。
  ///
  /// R2-01（2026-10-13 外部审计再次列为唯一未闭环 P0）：审计同时指出
  /// 「客户端节流不是安全边界」，与本注释第 3 条自述一致——节流只压缩
  /// 盗刷规模、不阻止提取模板码直接调用供应商。**本常量一旦移除而 secrets
  /// 未配置，登录会整体不可用**，故本轮不单方面改为 fail-closed；正确的
  /// 收口顺序是：① 服务端代理上线 → ② Spug 控制台轮换模板码 → ③ 本常量
  /// 删除并切到代理实现（端口见 application/sms_code_service.dart）。
  static const String _templateCode = String.fromEnvironment(
    'SPUG_TEMPLATE_CODE',
    defaultValue: 'yx5N5ygyQeuGKe9nwDB4tA',
  );
  static const String _endpoint = 'https://push.spug.cc/sms/$_templateCode';
  static const _codeLength = 6;
  static const _ttl = Duration(minutes: 5);

  final http.Client _client;
  final DateTime Function() _now;
  final SmsSendThrottle _throttle;

  String? _pendingPhone;
  String? _pendingCode;
  DateTime? _sentAt;

  @override
  Future<SmsSendResult> sendCode(String phone) async {
    // P0-01 仓库侧收口：持久化节流（跨重启生效）。客户端限流不是安全边界，
    // 但能显著压低单设备盗刷规模。
    final throttleError = await _throttle.check(phone, _now());
    if (throttleError != null) {
      return (ok: false, message: throttleError);
    }

    final code = _generateCode();
    try {
      final response = await _client
          .post(
            Uri.parse(_endpoint),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({'to': phone, 'code': code}),
          )
          .timeout(const Duration(seconds: 15));
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (body['code'] == 200) {
        _pendingPhone = phone;
        _pendingCode = code;
        _sentAt = _now();
        await _throttle.record(phone, _now());
        return (ok: true, message: '验证码已发送，请查收短信');
      }
      return (ok: false, message: body['msg']?.toString() ?? '发送失败，请稍后再试');
    } catch (e, s) {
      // 审计 I50：此前 e 被丢弃，网络故障与响应解析异常不可区分、排障全靠猜
      final kind = e is FormatException ? '响应解析失败' : '网络异常';
      reportSwallowedError('短信验证码发送失败（$kind）', e, s);
      return (ok: false, message: '网络异常，请检查网络后重试');
    }
  }

  @override
  String? verifyCode(String phone, String code) {
    if (_pendingCode == null || _sentAt == null) return '请先获取验证码';
    if (_pendingPhone != phone) return '手机号与验证码不匹配';
    if (_now().difference(_sentAt!) > _ttl) return '验证码已过期，请重新获取';
    if (_pendingCode != code) return '验证码错误';
    // 一次性消费：校验通过后立即作废，同一码 TTL 内不可重复通过。
    _pendingCode = null;
    _sentAt = null;
    return null;
  }

  String _generateCode() {
    final random = Random.secure();
    return List.generate(_codeLength, (_) => random.nextInt(10)).join();
  }
}
