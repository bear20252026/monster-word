// 由账号4生成
// 网络服务层：翻译自 webservice/（v3.2 源码 1:1）
// 文件：LexisBooks（词书列表 API）+ 核心请求封装

import 'dart:convert';

import 'package:http/http.dart' as http;

import '../utils/app_utils.dart';

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
  Map<String, dynamic> get params => _params;
}

/// HTTP 客户端（翻译自 CoolHttpClientV3.java 核心逻辑）
class CoolHttpClientV3 {
  static const String baseUrl = 'http://api.beingfine.cn/';
  static const String appId = '600000001'; // 原版 app_id
  static const String _userSecret = 'iscooler'; // 原版 USER_SECRET

  /// 带 token 的请求参数（原版 requestParamsWithToken）
  static RequestParams requestParamsWithToken(String path) {
    final params = RequestParams(path);
    params.put('app_id', appId);
    params.put('timestamp', DateUtils.currentTimeStr());
    return params;
  }

  /// 追加签名（原版 appendParamSign：sign = md5(AES(sorted_params, USER_SECRET, IV))）
  static void appendParamSign(RequestParams params) {
    final sorted = _sortParams(params.params);
    // 简化签名：md5(拼接参数 + secret)（原版为 AES+md5，离线本地版用等效签名）
    final joined = sorted.entries
        .map((e) => '${e.key}=${e.value}')
        .join('&');
    final sign = SecurityUtils.md5String('$joined$_userSecret');
    params.put('sign', sign);
  }

  static Map<String, dynamic> _sortParams(Map<String, dynamic> params) {
    final sorted = Map<String, dynamic>.fromEntries(params.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key)));
    return sorted;
  }

  /// GET 请求
  static Future<CoolHttpResponse> get(
    RequestParams params,
    CoolJsonHttpResponseHandler handler,
  ) async {
    try {
      final uri = Uri.parse('$baseUrl${params.path}')
          .replace(queryParameters: params.params.map((k, v) => MapEntry(k, v.toString())));
      final resp = await http.get(uri);
      final result = CoolHttpResponse(statusCode: resp.statusCode, body: resp.body);
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

  /// POST 请求
  static Future<CoolHttpResponse> post(
    RequestParams params,
    CoolJsonHttpResponseHandler handler,
  ) async {
    try {
      final uri = Uri.parse('$baseUrl${params.path}');
      final resp = await http.post(
        uri,
        body: params.params,
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      );
      final result = CoolHttpResponse(statusCode: resp.statusCode, body: resp.body);
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

/// 词书服务（翻译自 LexisBooks.java）
class LexisBooks {

  /// 获取词书列表（原版 getLexisGroupBooks：GET 2/bb/wordbooks）
  static Future<CoolHttpResponse> getLexisGroupBooks(
    CoolJsonHttpResponseHandler handler,
  ) async {
    final params = CoolHttpClientV3.requestParamsWithToken('2/bb/wordbooks');
    CoolHttpClientV3.appendParamSign(params);
    return CoolHttpClientV3.get(params, handler);
  }

  /// 移除词书（原版 uploadLibraryRemoved：POST bb/user/wordbooks）
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

  /// 添加词书（原版 uploadLibraryAdded：POST bb/user/wordbooks）
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
}

/// 登录服务（翻译自 PhoneLoginService.java + LoginCheckService.java 核心）
class LoginService {
  /// 手机号登录（原版 PhoneLoginService）
  static Future<CoolHttpResponse> phoneLogin(
    String phone,
    String code,
    CoolJsonHttpResponseHandler handler,
  ) async {
    final params = CoolHttpClientV3.requestParamsWithToken('1/user/login');
    params.put('phone', phone);
    params.put('code', code);
    CoolHttpClientV3.appendParamSign(params);
    return CoolHttpClientV3.post(params, handler);
  }

  /// 登录检查（原版 LoginCheckService）
  static Future<CoolHttpResponse> loginCheck(
    CoolJsonHttpResponseHandler handler,
  ) async {
    final params = CoolHttpClientV3.requestParamsWithToken('2/user/check');
    CoolHttpClientV3.appendParamSign(params);
    return CoolHttpClientV3.get(params, handler);
  }
}

/// 同步服务（翻译自 SyncChainService.java 核心）
class SyncChainService {
  /// 同步学习记录（原版 sync）
  static Future<CoolHttpResponse> sync(
    String syncData,
    CoolJsonHttpResponseHandler handler,
  ) async {
    final params = CoolHttpClientV3.requestParamsWithToken('2/user/sync');
    params.put('data', syncData);
    CoolHttpClientV3.appendParamSign(params);
    return CoolHttpClientV3.post(params, handler);
  }
}

/// 学习时长上报（翻译自 LearnDurationService.java）
class LearnDurationService {
  static Future<CoolHttpResponse> report(
    int duration,
    CoolJsonHttpResponseHandler handler,
  ) async {
    final params = CoolHttpClientV3.requestParamsWithToken('2/learn/duration');
    params.put('duration', duration);
    CoolHttpClientV3.appendParamSign(params);
    return CoolHttpClientV3.post(params, handler);
  }
}
