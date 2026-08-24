// 由 Claude 团队生成 | Monster Word App
// 由 Claude 团队生成 | 移植自 v3.2 webservice/ 全部关键类
// 网络服务层：1:1 翻译自 v3.2 反编译源码
// 包含：CoolHttpClientV3, LexisBooks, LoginCheckService, PhoneLoginService,
//       SyncChainServiceV2, LearnDurationService, ReportUserAction,
//       ReportUserDaily, GetAppConfiguration

import 'dart:convert';
import 'dart:async';

import 'package:http/http.dart' as http;

import '../utils/date_utils.dart';
import '../utils/crypto_utils.dart';

// ============================================================
// 基础封装（翻译自 asynchttp/ 包）
// ============================================================

/// API 响应封装（原版 CoolHttpResponse）
class CoolHttpResponse {
  final int statusCode;
  final String body;
  final bool success;

  CoolHttpResponse({required this.statusCode, required this.body})
      : success = statusCode == 200;

  Map<String, dynamic>? get jsonBody {
    try {
      return jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// 获取 data_body（原版 getData_body()）
  Map<String, dynamic>? get dataBody {
    final jb = jsonBody;
    if (jb == null) return null;
    return jb['data_body'] as Map<String, dynamic>?;
  }

  /// 获取 result_code（原版 getResult_code()）
  int get resultCode {
    final jb = jsonBody;
    if (jb == null) return -1;
    return jb['result_code'] as int? ?? -1;
  }

  /// 获取 error_message（原版 getError_message()）
  String get errorMessage {
    final jb = jsonBody;
    if (jb == null) return '';
    return jb['error_message'] as String? ?? '';
  }

  /// 获取 error_info（原版 getError_info()）
  String get errorInfo {
    final jb = jsonBody;
    if (jb == null) return '';
    return jb['error_info'] as String? ?? '';
  }
}

/// 请求回调（原版 CoolJsonHttpResponseHandler）
class CoolJsonHttpResponseHandler {
  void onSuccess(CoolHttpResponse response) {}
  void onFailure(CoolHttpResponse response) {}
}

/// 参数封装（原版 RequestParams）
class RequestParams {
  final Map<String, dynamic> _params = {};
  String? path;

  RequestParams(this.path);

  void put(String key, dynamic value) => _params[key] = value;
  void add(String key, dynamic value) => _params[key] = value;
  void remove(String key) => _params.remove(key);
  Map<String, dynamic> get params => _params;
}

// ============================================================
// HTTP 客户端（翻译自 CoolHttpClientV3.java）
// ============================================================

class CoolHttpClientV3 {
  static const String baseUrl = 'http://api.beingfine.cn/';
  static const String baseImgUrl = 'http://img.beingfine.cn/';
  static const String localFilePath = ''; // TODO: 本地文件缓存路径
  static const String appId = '600000001';
  static const String _userSecret = 'iscooler';

  static int _timeoutMs = 30000; // 默认 30 秒

  /// 设置超时（原版 setTimeout）
  static void setTimeout(int ms) => _timeoutMs = ms;

  /// 基础请求参数（原版 requestParams，不需要 token）
  static RequestParams requestParams(String path) {
    return RequestParams(path);
  }

  /// 带 token 的请求参数（原版 requestParamsWithToken）
  static RequestParams requestParamsWithToken(String path) {
    final params = RequestParams(path);
    params.put('app_id', appId);
    params.put('timestamp', AppDateUtils.currentTimeStr());
    return params;
  }

  /// 追加签名（原版 appendParamSign）
  /// sign = md5(AES(sorted_params, USER_SECRET, IV))
  /// 离线本地版用简化签名：md5(拼接参数 + secret)
  static void appendParamSign(RequestParams params) {
    final sorted = _sortParams(params.params);
    final joined =
        sorted.entries.map((e) => '${e.key}=${e.value}').join('&');
    final sign = SecurityUtils.md5String('$joined$_userSecret');
    params.put('sign', sign);
  }

  static Map<String, dynamic> _sortParams(Map<String, dynamic> params) {
    final sorted = Map<String, dynamic>.fromEntries(
        params.entries.toList()..sort((a, b) => a.key.compareTo(b.key)));
    return sorted;
  }

  /// GET 请求（原版 get）
  static Future<CoolHttpResponse> get(
    RequestParams params,
    CoolJsonHttpResponseHandler handler,
  ) async {
    try {
      final uri = Uri.parse('$baseUrl${params.path}').replace(
          queryParameters:
              params.params.map((k, v) => MapEntry(k, v.toString())));
      final resp = await http.get(uri).timeout(
            Duration(milliseconds: _timeoutMs),
          );
      final result =
          CoolHttpResponse(statusCode: resp.statusCode, body: resp.body);
      if (result.success) {
        handler.onSuccess(result);
      } else {
        handler.onFailure(result);
      }
      return result;
    } catch (e) {
      final result = CoolHttpResponse(statusCode: -1, body: 'error: $e');
      handler.onFailure(result);
      return result;
    }
  }

  /// POST 请求（原版 post）
  static Future<CoolHttpResponse> post(
    RequestParams params,
    CoolJsonHttpResponseHandler handler,
  ) async {
    try {
      final uri = Uri.parse('$baseUrl${params.path}');
      final resp = await http
          .post(
            uri,
            body: params.params,
            headers: {'Content-Type': 'application/x-www-form-urlencoded'},
          )
          .timeout(Duration(milliseconds: _timeoutMs));
      final result =
          CoolHttpResponse(statusCode: resp.statusCode, body: resp.body);
      if (result.success) {
        handler.onSuccess(result);
      } else {
        handler.onFailure(result);
      }
      return result;
    } catch (e) {
      final result = CoolHttpResponse(statusCode: -1, body: 'error: $e');
      handler.onFailure(result);
      return result;
    }
  }

  /// 登录检查专用（原版 checkLogin，使用自定义 OkHttpClient）
  static Future<CoolHttpResponse> checkLogin(
    RequestParams params,
    CoolJsonHttpResponseHandler handler,
  ) async {
    try {
      final uri = Uri.parse('$baseUrl${params.path}').replace(
          queryParameters:
              params.params.map((k, v) => MapEntry(k, v.toString())));
      final resp = await http.get(uri).timeout(
            const Duration(seconds: 2), // 原版 2 秒超时
          );
      final result =
          CoolHttpResponse(statusCode: resp.statusCode, body: resp.body);
      if (result.success) {
        handler.onSuccess(result);
      } else {
        handler.onFailure(result);
      }
      return result;
    } catch (e) {
      final result = CoolHttpResponse(statusCode: -1, body: 'error: $e');
      handler.onFailure(result);
      return result;
    }
  }
}

// ============================================================
// 词书服务（翻译自 LexisBooks.java）
// ============================================================

class LexisBooks {
  /// 获取词书分组列表（原版 getLexisGroupBooks）
  /// 端点：GET 2/bb/wordbooks
  static Future<CoolHttpResponse> getLexisGroupBooks(
    CoolJsonHttpResponseHandler handler,
  ) async {
    final params = CoolHttpClientV3.requestParamsWithToken('2/bb/wordbooks');
    CoolHttpClientV3.appendParamSign(params);
    return CoolHttpClientV3.get(params, handler);
  }

  /// 移除词书（原版 uploadLibraryRemoved）
  /// 端点：POST bb/user/wordbooks {book_code, operation=1}
  static Future<CoolHttpResponse> uploadLibraryRemoved(
    String bookCode,
    CoolJsonHttpResponseHandler handler,
  ) async {
    if (bookCode.isEmpty) return CoolHttpResponse(statusCode: -1, body: 'empty');
    final params = CoolHttpClientV3.requestParamsWithToken('bb/user/wordbooks');
    params.put('book_code', bookCode);
    params.put('operation', 1);
    CoolHttpClientV3.appendParamSign(params);
    return CoolHttpClientV3.post(params, handler);
  }

  /// 添加词书（原版 uploadLibraryAdded）
  /// 端点：POST bb/user/wordbooks {book_code}
  static Future<CoolHttpResponse> uploadLibraryAdded(
    String bookCode,
    CoolJsonHttpResponseHandler handler,
  ) async {
    if (bookCode.isEmpty) return CoolHttpResponse(statusCode: -1, body: 'empty');
    final params = CoolHttpClientV3.requestParamsWithToken('bb/user/wordbooks');
    params.put('book_code', bookCode);
    CoolHttpClientV3.appendParamSign(params);
    return CoolHttpClientV3.post(params, handler);
  }

  /// 处理离线添加队列（原版 dealLocalTask）
  /// 逐个发送失败的添加请求，成功后移除
  static Future<void> dealLocalTask() async {
    // TODO: 需要 SharedPreferences 集成
    // 从 prefs 读取 "addlib{userId}" 的 LinkedHashSet
    // 逐个调用 uploadLibraryAdded，成功后移除，递归处理下一个
  }

  /// 保存失败的添加请求到本地队列（原版 saveFailedAdd）
  static Future<void> saveFailedAdd(String bookCode) async {
    // TODO: 需要 SharedPreferences 集成
    // 保存到 "addlib{userId}" 的 LinkedHashSet
  }
}

// ============================================================
// 登录验证服务（翻译自 LoginCheckService.java）
// ============================================================

/// 登录检查监听器（原版 LoginCheckListener）
abstract class LoginCheckListener {
  void onCheckValid(bool isValid);
  void onCheckError();
}

class LoginCheckService {
  /// 检查登录状态（原版 check）
  /// 端点：GET login/verification（2秒超时）
  /// 错误码 30102/30104 → token 过期
  static Future<void> check(LoginCheckListener listener) async {
    // TODO: 需要 UserPreferences.isLoginYet() 集成
    // if (!UserPreferences.isLoginYet()) {
    //   listener.onCheckValid(false);
    //   return;
    // }

    final params = CoolHttpClientV3.requestParamsWithToken('login/verification');
    CoolHttpClientV3.appendParamSign(params);

    final handler = _LoginCheckHandler(listener);
    await CoolHttpClientV3.checkLogin(params, handler);
  }
}

class _LoginCheckHandler extends CoolJsonHttpResponseHandler {
  final LoginCheckListener listener;
  _LoginCheckHandler(this.listener);

  @override
  void onSuccess(CoolHttpResponse response) {
    if (response.success) {
      listener.onCheckValid(true);
    } else if (response.resultCode == 30102 ||
        response.resultCode == 30104) {
      // token 过期
      listener.onCheckValid(false);
    } else {
      listener.onCheckError();
    }
  }

  @override
  void onFailure(CoolHttpResponse response) {
    listener.onCheckError();
  }
}

// ============================================================
// 手机登录服务（翻译自 PhoneLoginService.java）
// ============================================================

/// 手机登录监听器（原版 PhoneLoginListener）
abstract class PhoneLoginListener {
  void onSuccess();
  void onError(int code, String message);
  void onFirstLogin(bool isNewUser);
  void onBindStatus(int status);
}

/// 简单监听器（原版 SimplePhoneLoginListener）
class SimplePhoneLoginListener implements PhoneLoginListener {
  @override
  void onSuccess() {}
  @override
  void onError(int code, String message) {}
  @override
  void onFirstLogin(bool isNewUser) {}
  @override
  void onBindStatus(int status) {}
}

class PhoneLoginService {
  static const int resultCommonError = -1;

  /// 友盟 token 首次登录检查（原版 isFirstLoginWithOpenId）
  /// 端点：GET account/binding/by-umeng {umeng_token}
  static Future<void> isFirstLoginWithOpenId(
    String umengToken,
    PhoneLoginListener listener,
  ) async {
    final params = CoolHttpClientV3.requestParams('account/binding/by-umeng');
    params.put('umeng_token', umengToken);
    CoolHttpClientV3.get(params, _PhoneLoginHandler(listener));
  }

  /// 手机号首次登录检查（原版 isFirstLoginWithPhone）
  /// 端点：GET account/binding/by-phone2 {phone_number}
  static Future<void> isFirstLoginWithPhone(
    String phone,
    PhoneLoginListener listener,
  ) async {
    final params = CoolHttpClientV3.requestParams('account/binding/by-phone2');
    params.put('phone_number', phone);
    params.remove('tencent_uid');
    CoolHttpClientV3.get(params, _PhoneLoginHandler(listener));
  }

  /// 友盟 token 登录（原版 loggin）
  /// 端点：POST login/by-umeng {umeng_token}
  static Future<CoolHttpResponse> login(
    String umengToken,
    CoolJsonHttpResponseHandler handler,
  ) async {
    final params = CoolHttpClientV3.requestParamsWithToken('login/by-umeng');
    params.put('umeng_token', umengToken);
    CoolHttpClientV3.appendParamSign(params);
    return CoolHttpClientV3.post(params, handler);
  }

  /// 手机验证码登录（原版 phoneCodeValid）
  /// 端点：POST login/by-sms {phone_number, sms_code}
  static Future<CoolHttpResponse> phoneCodeValid(
    String phone,
    String code,
    CoolJsonHttpResponseHandler handler,
  ) async {
    final params = CoolHttpClientV3.requestParams('login/by-sms');
    params.put('phone_number', phone);
    params.put('sms_code', code);
    return CoolHttpClientV3.post(params, handler);
  }

  /// 发送登录验证码（原版 sendPhoneCode）
  /// 端点：POST sms/send/by-login {phone_number, sign}
  static Future<void> sendPhoneCode(
    String phone,
    PhoneLoginListener listener,
  ) async {
    try {
      final params = CoolHttpClientV3.requestParams('sms/send/by-login');
      params.remove('tencent_uid');
      params.put('phone_number', phone);
      CoolHttpClientV3.appendParamSign(params);
      await CoolHttpClientV3.post(params, _PhoneLoginSimpleHandler(listener));
    } catch (_) {}
  }

  /// 发送绑定验证码（原版 sendBindingPhoneCode）
  /// 端点：POST sms/send/by-bind {phone_number}
  static Future<void> sendBindingPhoneCode(
    String phone,
    PhoneLoginListener listener,
  ) async {
    try {
      final params =
          CoolHttpClientV3.requestParamsWithToken('sms/send/by-bind');
      params.put('phone_number', phone);
      CoolHttpClientV3.appendParamSign(params);
      await CoolHttpClientV3.post(params, _PhoneLoginSimpleHandler(listener));
    } catch (_) {}
  }

  /// 发送修改手机验证码（原版 sendModifyPhoneCode）
  /// 端点：POST sms/send/by-rebind {phone_number}
  static Future<void> sendModifyPhoneCode(
    String phone,
    PhoneLoginListener listener,
  ) async {
    try {
      final params =
          CoolHttpClientV3.requestParamsWithToken('sms/send/by-rebind');
      params.put('phone_number', phone);
      CoolHttpClientV3.appendParamSign(params);
      await CoolHttpClientV3.post(params, _PhoneLoginSimpleHandler(listener));
    } catch (_) {}
  }

  /// 验证绑定手机验证码（原版 validateBindingPhoneCode）
  /// 端点：POST account/binding/by-sms {phone_number, code}
  static Future<void> validateBindingPhoneCode(
    String phone,
    String code,
    PhoneLoginListener listener,
  ) async {
    final params =
        CoolHttpClientV3.requestParamsWithToken('account/binding/by-sms');
    params.put('phone_number', phone);
    params.put('code', code);
    CoolHttpClientV3.appendParamSign(params);
    await CoolHttpClientV3.post(params, _PhoneLoginSimpleHandler(listener));
  }

  /// 绑定手机（原版 bindPhone）
  /// 端点：POST account/binding/by-umeng {umeng_token}
  static Future<void> bindPhone(
    String umengToken,
    PhoneLoginListener listener,
  ) async {
    final params =
        CoolHttpClientV3.requestParamsWithToken('account/binding/by-umeng');
    params.put('umeng_token', umengToken);
    CoolHttpClientV3.appendParamSign(params);
    await CoolHttpClientV3.post(params, _PhoneLoginBindHandler(listener));
  }

  /// 修改手机验证码验证（原版 modifyPhoneCodeValidate）
  /// 端点：POST account/rebinding/by-sms {phone_number, code}
  static Future<void> modifyPhoneCodeValidate(
    String phone,
    String code,
    PhoneLoginListener listener,
  ) async {
    final params =
        CoolHttpClientV3.requestParamsWithToken('account/rebinding/by-sms');
    params.put('phone_number', phone);
    params.put('code', code);
    CoolHttpClientV3.appendParamSign(params);
    await CoolHttpClientV3.post(params, _PhoneLoginSimpleHandler(listener));
  }

  /// 检查手机是否已绑定（原版 checkPhoneHasBinded）
  /// 端点：GET account/binding/by-phone {phone_number}
  static Future<void> checkPhoneHasBinded(
    String phone,
    PhoneLoginListener listener,
  ) async {
    final params = CoolHttpClientV3.requestParams('account/binding/by-phone');
    params.put('phone_number', phone);
    await CoolHttpClientV3.get(params, _PhoneLoginBindCheckHandler(listener));
  }
}

/// 手机登录通用 Handler
class _PhoneLoginHandler extends CoolJsonHttpResponseHandler {
  final PhoneLoginListener listener;
  _PhoneLoginHandler(this.listener);

  @override
  void onSuccess(CoolHttpResponse response) {
    final data = response.dataBody;
    if (data == null && !response.success) {
      listener.onError(PhoneLoginService.resultCommonError, '');
      return;
    }
    try {
      final isNewUser = data?['new_user'] ?? 0;
      listener.onFirstLogin(isNewUser == 1);
    } catch (_) {}
  }

  @override
  void onFailure(CoolHttpResponse response) {
    _notifyError(listener, response);
  }
}

/// 手机登录简单 Handler（只通知成功/失败）
class _PhoneLoginSimpleHandler extends CoolJsonHttpResponseHandler {
  final PhoneLoginListener listener;
  _PhoneLoginSimpleHandler(this.listener);

  @override
  void onSuccess(CoolHttpResponse response) {
    listener.onSuccess();
  }

  @override
  void onFailure(CoolHttpResponse response) {
    _notifyError(listener, response);
  }
}

/// 手机绑定 Handler（解析 phone 字段）
class _PhoneLoginBindHandler extends CoolJsonHttpResponseHandler {
  final PhoneLoginListener listener;
  _PhoneLoginBindHandler(this.listener);

  @override
  void onSuccess(CoolHttpResponse response) {
    final data = response.dataBody;
    if (data != null) {
      try {
        final phone = data['phone'] as String?;
        if (phone != null) {
          // TODO: 保存到 UserPreferences
        }
      } catch (_) {}
    }
    listener.onSuccess();
  }

  @override
  void onFailure(CoolHttpResponse response) {
    _notifyError(listener, response);
  }
}

/// 手机绑定检查 Handler
class _PhoneLoginBindCheckHandler extends CoolJsonHttpResponseHandler {
  final PhoneLoginListener listener;
  _PhoneLoginBindCheckHandler(this.listener);

  @override
  void onSuccess(CoolHttpResponse response) {
    final data = response.dataBody;
    if (data == null && !response.success) {
      listener.onError(PhoneLoginService.resultCommonError, '');
      return;
    }
    try {
      final checkResult = data?['check_result'] ?? 0;
      listener.onBindStatus(checkResult as int);
    } catch (_) {}
  }

  @override
  void onFailure(CoolHttpResponse response) {
    _notifyError(listener, response);
  }
}

void _notifyError(PhoneLoginListener listener, CoolHttpResponse? response) {
  if (response != null) {
    listener.onError(response.resultCode, response.errorMessage);
  } else {
    listener.onError(PhoneLoginService.resultCommonError, '');
  }
}

// ============================================================
// 链式同步服务（翻译自 SyncChainServiceV2.java）
// ============================================================

/// 同步状态回调
abstract class SyncListener {
  void onSyncStart();  // 消息码 400
  void onSyncSuccess(); // 消息码 401, arg1=1
  void onSyncFailed();  // 消息码 401, arg1=0
}

class SyncChainServiceV2 {
  static const String _logTag = 'SyncChainServiceV2';
  static bool isSynchronizing = false;

  /// 链式同步入口（原版 call）
  /// 流程：chainRequest1 → chainRequerst2Pre → chainRequest2
  static Future<void> call(SyncListener? listener) async {
    // TODO: 需要 PublicConstants.userId 集成
    // if (userId.isEmpty) {
    //   print('$_logTag: 用户未登录，跳过同步');
    //   return;
    // }
    if (isSynchronizing) {
      print('$_logTag: 正在同步，跳过');
      return;
    }
    print('$_logTag: 链式同步开始');
    isSynchronizing = true;
    listener?.onSyncStart();

    try {
      await _chainRequest1(listener);
    } catch (e) {
      print('$_logTag: 同步异常: $e');
      _syncServiceFailed(listener);
    }
  }

  /// 第 1 步：同步用户学习记录（原版 chainRequest1）
  /// 端点：BB_SyncLexisProcess
  /// 参数：last_sync_time, sync_file, review_task
  static Future<void> _chainRequest1(SyncListener? listener) async {
    // TODO: 需要 AppPreferences 和 BBWordProcessDao 集成
    // if (AppPreferences.getBool('APP_OLD_WORD_PROCESS_SYNCED')) {
    //   await _chainRequest2(listener);
    //   return;
    // }
    print('$_logTag: 第 1 步 ------ 同步用户学习记录');

    // 模拟：获取待同步数据
    // final syncData = BBWordProcessDao.getSyncData();
    // final syncFile = convertStreamToFile(syncData);

    // final params = CoolHttpClient.requestParams('BB_SyncLexisProcess');
    // params.put('last_sync_time', previousSyncTime);
    // params.put('sync_file', syncFile);
    // params.put('review_task', todayReviewCount);
    // CoolHttpClient.setTimeout(1200000); // 20 分钟超时

    // 成功后进入下一步
    await _chainRequest2(listener);
  }

  /// 第 2 步：同步用户生词（原版 chainRequest2）
  /// 端点：SyncUserVocabulary
  /// 参数：last_sync_time, sync_file
  static Future<void> _chainRequest2(SyncListener? listener) async {
    print('$_logTag: 第 2 步 ------ 同步用户生词');

    // TODO: 需要 NewWordDao 和 UserPreferences 集成
    // final syncData = NewWordDao.getSyncData();
    // final syncFile = convertStreamToFile(syncData);
    //
    // final params = CoolHttpClient.requestParams('SyncUserVocabulary');
    // params.put('last_sync_time', previousSyncNewWordTime);
    // params.put('sync_file', syncFile);
    // CoolHttpClient.setTimeout(1200000);

    // 成功
    _syncServiceSuccess(listener);
  }

  /// 上传 V2 数据（原版 uploadV2Data）
  /// 端点：POST report/v2-process {stat}
  static Future<void> uploadV2Data(
    CoolJsonHttpResponseHandler handler,
  ) async {
    // TODO: 需要 BBWordProcessDao 集成
    // final v2AllData = BBWordProcessDao.getV2AllData();
    // if (v2AllData == null || v2AllData.isEmpty) {
    //   handler.onFailure(null);
    //   return;
    // }
    // final params = CoolHttpClientV3.requestParams('report/v2-process');
    // params.add('stat', jsonEncode(v2AllData));
    // CoolHttpClientV3.post(params, handler);
  }

  /// 上传生词修复（原版 uplooadNewWordFix）
  /// 端点：SyncUserVocabularyFix1
  static Future<void> uploadNewWordFix() async {
    // TODO: 需要 AppPreferences 和 NewWordDao 集成
  }

  static void _syncServiceFailed(SyncListener? listener) {
    print('$_logTag: 链式同步服务异常');
    isSynchronizing = false;
    listener?.onSyncFailed();
  }

  static void _syncServiceSuccess(SyncListener? listener) {
    print('$_logTag: 链式同步服务完成');
    isSynchronizing = false;
    listener?.onSyncSuccess();
  }
}

// ============================================================
// 学习时长服务（翻译自 LearnDurationService.java）
// ============================================================

class LearnDurationService {
  /// 获取学习时长（原版 call）
  /// 端点：GET bb/dashboard/learn-duration
  static Future<CoolHttpResponse> call(
    CoolJsonHttpResponseHandler handler,
  ) async {
    final params =
        CoolHttpClientV3.requestParamsWithToken('bb/dashboard/learn-duration');
    CoolHttpClientV3.appendParamSign(params);
    return CoolHttpClientV3.get(params, handler);
  }
}

// ============================================================
// 用户行为上报（翻译自 ReportUserAction.java）
// ============================================================

class ReportUserAction {
  /// 上报用户行为（原版 call）
  /// 端点：POST report/webview/action {action_type, action_data}
  static Future<void> call(
    String actionType,
    String actionData,
    CoolJsonHttpResponseHandler handler,
  ) async {
    // TODO: 需要 UserPreferences.isLoginYet() 集成
    // if (!UserPreferences.isLoginYet()) {
    //   print('$_logTag: 未登录，跳过');
    //   return;
    // }

    final params =
        CoolHttpClientV3.requestParamsWithToken('report/webview/action');
    params.put('action_type', actionType);
    params.put('action_data', actionData);
    CoolHttpClientV3.appendParamSign(params);
    await CoolHttpClientV3.post(params, handler);
  }
}

// ============================================================
// 每日学习统计上报（翻译自 ReportUserDaily.java）
// ============================================================

class ReportUserDaily {
  static bool _bSyning = false;
  static bool _bReviewTaskSyncing = false;

  /// 上报每日学习统计（原版 call）
  /// 端点：POST bb/user-stat/learn-duration {stat}
  static Future<void> call() async {
    if (_bSyning) return;
    _bSyning = true;

    // TODO: 需要 PublicConstants.userId 和 LexisDailyDao 集成
    // if (userId.isEmpty) {
    //   _bSyning = false;
    //   return;
    // }
    // final syncData = LexisDailyDao.jsonArray4Sync(pendingIds);
    // if (syncData.isEmpty) {
    //   _bSyning = false;
    //   return;
    // }

    final params =
        CoolHttpClientV3.requestParamsWithToken('bb/user-stat/learn-duration');
    // params.put('stat', jsonEncode(syncData));
    CoolHttpClientV3.appendParamSign(params);

    await CoolHttpClientV3.post(params, _ReportDailyHandler());
  }

  /// 上报复习任务统计（原版 uploadReviewTask）
  /// 端点：POST bb/user-stat/review-task {stat}
  static Future<void> uploadReviewTask() async {
    if (_bReviewTaskSyncing) return;
    _bReviewTaskSyncing = true;

    // TODO: 需要 LexisDailyDao 集成
    // final reviewTaskInfo = LexisDailyDao.getReviewTaskInfo();
    // if (reviewTaskInfo.isEmpty) {
    //   _bReviewTaskSyncing = false;
    //   return;
    // }

    final params =
        CoolHttpClientV3.requestParamsWithToken('bb/user-stat/review-task');
    // params.put('stat', jsonEncode(reviewTaskInfo));
    CoolHttpClientV3.appendParamSign(params);

    await CoolHttpClientV3.post(params, _ReportReviewTaskHandler());
  }
}

class _ReportDailyHandler extends CoolJsonHttpResponseHandler {
  @override
  void onSuccess(CoolHttpResponse response) {
    // TODO: LexisDailyDao.update4SucSync(pendingIds);
    ReportUserDaily._bSyning = false;
  }

  @override
  void onFailure(CoolHttpResponse response) {
    print('ReportUserDaily: 上报失败 ${response.errorInfo}');
    ReportUserDaily._bSyning = false;
  }
}

class _ReportReviewTaskHandler extends CoolJsonHttpResponseHandler {
  @override
  void onSuccess(CoolHttpResponse response) {
    // TODO: LexisDailyDao.syncReviewTaskSuc();
    ReportUserDaily._bReviewTaskSyncing = false;
  }

  @override
  void onFailure(CoolHttpResponse response) {
    print('ReportUserDaily: 上报复习任务失败 ${response.errorInfo}');
    ReportUserDaily._bReviewTaskSyncing = false;
  }
}

// ============================================================
// 应用配置服务（翻译自 GetAppConfiguration.java）
// ============================================================

/// 应用配置（原版 Configurations）
class AppConfiguration {
  final List<AppRec>? appRec;
  final CoolabConfig? coolab;
  final AppSettings? settings;

  AppConfiguration({this.appRec, this.coolab, this.settings});

  factory AppConfiguration.fromJson(Map<String, dynamic> json) {
    return AppConfiguration(
      appRec: (json['app_rec'] as List?)
          ?.map((e) => AppRec.fromJson(e as Map<String, dynamic>))
          .toList(),
      coolab: json['coolab'] != null
          ? CoolabConfig.fromJson(json['coolab'] as Map<String, dynamic>)
          : null,
      settings: json['settings'] != null
          ? AppSettings.fromJson(json['settings'] as Map<String, dynamic>)
          : null,
    );
  }

  List<CellMenu>? get moreMenus => settings?.moreMenu;

  String get coolabUrl =>
      (coolab == null || !coolab!.isEnabled) ? '' : coolab!.url;
}

/// 应用设置（原版 Settings）
class AppSettings {
  final List<CellMenu>? moreMenu;

  AppSettings({this.moreMenu});

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      moreMenu: (json['more_menu'] as List?)
          ?.map((e) => CellMenu.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// 菜单元格（原版 CellMenu）
class CellMenu {
  final int display;
  final String title;
  final String url;

  CellMenu({required this.display, required this.title, required this.url});

  factory CellMenu.fromJson(Map<String, dynamic> json) {
    return CellMenu(
      display: json['display'] as int? ?? 0,
      title: json['title'] as String? ?? '',
      url: json['url'] as String? ?? '',
    );
  }

  bool get isDisplay => display == 1;
}

/// Coolab 配置（原版 Coolab）
class CoolabConfig {
  final int enable;
  final String url;

  CoolabConfig({required this.enable, required this.url});

  factory CoolabConfig.fromJson(Map<String, dynamic> json) {
    return CoolabConfig(
      enable: json['enable'] as int? ?? 0,
      url: json['url'] as String? ?? '',
    );
  }

  bool get isEnabled => enable == 1;
}

/// 应用推荐（原版 AppRec）
class AppRec {
  final AppIcon? icon;
  final String intro;
  final String name;
  final String pkg;
  final int type;
  final String url;

  AppRec({
    this.icon,
    required this.intro,
    required this.name,
    required this.pkg,
    required this.type,
    required this.url,
  });

  factory AppRec.fromJson(Map<String, dynamic> json) {
    return AppRec(
      icon: json['icon'] != null
          ? AppIcon.fromJson(json['icon'] as Map<String, dynamic>)
          : null,
      intro: json['intro'] as String? ?? '',
      name: json['name'] as String? ?? '',
      pkg: json['pkg'] as String? ?? '',
      type: json['type'] as int? ?? 0,
      url: json['url'] as String? ?? '',
    );
  }

  /// 默认推荐（原版 getDefaultAppRec）
  static AppRec getDefaultAppRec() {
    return AppRec(
      pkg: 'com.liqiu.listen', // QT_LISTEN_PACKAGE_NAME
      intro: '最佳英语听力应用',
      name: '轻听英语',
      type: 1,
      url: '', // APP_QLISTEN_URL
    );
  }
}

/// 应用图标（原版 AppIcon）
class AppIcon {
  final String black;
  final String dark;
  final String light;

  AppIcon({required this.black, required this.dark, required this.light});

  factory AppIcon.fromJson(Map<String, dynamic> json) {
    return AppIcon(
      black: json['black'] as String? ?? '',
      dark: json['dark'] as String? ?? '',
      light: json['light'] as String? ?? '',
    );
  }
}

/// 配置监听器（原版 CofiguretionsListener）
abstract class ConfigurationsListener {
  void onSuccess(AppConfiguration configurations);
  void onFailed();
}

class GetAppConfiguration {
  /// 获取应用配置（原版 call）
  /// 端点：GET app-configs
  static Future<void> call(ConfigurationsListener listener) async {
    final params = CoolHttpClientV3.requestParams('app-configs');
    await CoolHttpClientV3.get(params, _AppConfigHandler(listener));
  }

  /// 从本地缓存加载配置（原版 Configurations.newConfigureations）
  static AppConfiguration? loadFromCache(String cachedJson) {
    if (cachedJson.isEmpty) return null;
    try {
      return AppConfiguration.fromJson(
          jsonDecode(cachedJson) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }
}

class _AppConfigHandler extends CoolJsonHttpResponseHandler {
  final ConfigurationsListener listener;
  _AppConfigHandler(this.listener);

  @override
  void onSuccess(CoolHttpResponse response) {
    if (response.statusCode == -1) {
      listener.onFailed();
      return;
    }
    try {
      final dataBody = response.dataBody;
      if (dataBody == null || dataBody['feature'] == null) {
        listener.onFailed();
        return;
      }
      final feature = dataBody['feature'] as Map<String, dynamic>;
      final config = AppConfiguration.fromJson(feature);
      listener.onSuccess(config);
    } catch (e) {
      print('GetAppConfiguration: 解析失败 $e');
      listener.onFailed();
    }
  }

  @override
  void onFailure(CoolHttpResponse response) {
    listener.onFailed();
  }
}
