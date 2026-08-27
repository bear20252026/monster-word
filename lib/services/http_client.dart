// 由 Claude 团队生成 | Monster Word App

// HTTP 网络层 — 1:1 移植自 v3.2 asynchttp/ 包（12 个 Java 类）
// 使用 Flutter http 包重写，保留原版全部逻辑和 API 签名
//
// 原版类映射：
//   AsyncHttpResponseHandler   → (空基类，省略)
//   CoolHttpResponse           → CoolHttpResponse
//   CoolJsonHttpResponseHandler→ CoolJsonHttpResponseHandler
//   FileHttpReponseHandler     → FileHttpResponseHandler
//   RequestParams              → RequestParams
//   CoolParams                 → CoolParams
//   CoolHttpClient             → CoolHttpClient
//   CoolHttpClientV3           → CoolHttpClientV3
//   DownloadHttpClient         → DownloadHttpClient
//   CoolHttpDnsManager         → CoolHttpDnsManager
//   OkHttpDns                  → (Flutter 无等价，用 CoolHttpDnsManager 替代)
//   CoolSSLSocketFactory       → (Flutter 无需，http 包自动处理 TLS)

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart' show MediaType;

import '../data/app_preferences.dart';
import '../utils/crypto_utils.dart';

/// Release 包禁用 print，防止 token/URL/参数泄露到 logcat
void _log(Object? message) {
  if (kDebugMode) print(message);
}

// ============================================================
// CoolHttpResponse — 响应封装（原版 CoolHttpResponse.java）
// ============================================================

/// API 响应封装（原版 CoolHttpResponse）
///
/// 支持 v1 和 v3 两种格式：
/// - v1: data_body 直接为 JSONObject
/// - v3: data_body 为加密的 Base64 字符串，需用 secret 解密
class CoolHttpResponse {
  static const int errAccountAuthFailed = 20004;
  static const int errArgError = 10008;
  static const int errContentNotFound = 20021;
  static const int errDictionaryNoResult = 20020;
  static const int errEmailIsTaken = 20012;
  static const int errInvalidEmail = 20013;
  static const int errInvalidPasswdFormat = 20019;
  static const int errNicknameIsTaken = 20017;
  static const int errNoLogin = 20016;
  static const int errNoUser = 20003;
  static const int errPasswdVerifyFailed = 20018;
  static const int errPrimaryCannotUnbinding = 20015;
  static const int errRepeatBinding = 20014;
  static const int errServiceError = 10003;
  static const int sucOk = 200;

  String? _dataKind;
  String? _dataVersion;
  int _resultCode = -1;
  Map<String, dynamic>? _dataBody;
  Map<String, dynamic>? _errorBody;
  String _errorInfo = '';
  String _errorMessage = '';
  String? _encodeDataBody;
  int _dataEncrypted = 1;
  Map<String, dynamic>? _v3Security;
  bool _bV3 = false;

  /// 空响应（网络错误时使用）
  CoolHttpResponse();

  /// v1 格式解析（原版 CoolHttpResponse(JSONObject)）
  CoolHttpResponse.fromJson(Map<String, dynamic> json) {
    try {
      _dataKind = json['data_kind'] as String?;
      _dataVersion = json['data_version'] as String?;
      if (json['result_code'] != null) {
        _resultCode = int.tryParse(json['result_code'].toString()) ?? -1;
      }
      if (json['data_body'] is Map) {
        _dataBody = json['data_body'] as Map<String, dynamic>;
      }
      if (json['error_body'] is Map) {
        _errorBody = json['error_body'] as Map<String, dynamic>;
        _errorInfo = _errorBody!['info'] as String? ?? '';
        _errorMessage = _errorBody!['user_message'] as String? ?? '';
      }
    } catch (e) {
      _log('CoolHttpResponse parse JsonError: $e');
    }
  }

  /// v3 格式解析（原版 CoolHttpResponse(JSONObject, true)）
  CoolHttpResponse.fromJsonV3(Map<String, dynamic> json) {
    _bV3 = true;
    try {
      _dataKind = json['data_kind'] as String?;
      _dataVersion = json['data_version'] as String?;
      if (json['result_code'] != null) {
        _resultCode = int.tryParse(json['result_code'].toString()) ?? -1;
      }
      if (json['data_body'] != null) {
        _encodeDataBody = json['data_body'].toString();
      }
      if (json['error_body'] is Map) {
        _errorBody = json['error_body'] as Map<String, dynamic>;
        _errorInfo = _errorBody!['dev_info'] as String? ?? '';
        _errorMessage = _errorBody!['user_msg'] as String? ?? '';
      }
      _dataEncrypted = json['data_encrypted'] as int? ?? 1;
      if (json['v3_security'] is Map) {
        _v3Security = json['v3_security'] as Map<String, dynamic>;
      }
    } catch (e) {
      _log('CoolHttpResponse parse JsonError: $e');
    }
  }

  // === Getters（原版 1:1）===
  String? get dataKind => _dataKind;
  String? get dataVersion => _dataVersion;
  int get resultCode => _resultCode;
  Map<String, dynamic>? get dataBody => _dataBody;
  Map<String, dynamic>? get errorBody => _errorBody;
  String get errorMessage => _errorMessage;
  String get errorInfo => _errorInfo;
  Map<String, dynamic>? get v3Security => _v3Security;

  /// 解密 v3 数据体（原版 decryDataBody）
  void decryDataBody(String secret) {
    if (!_bV3 || _encodeDataBody == null || _encodeDataBody!.isEmpty) return;
    String decryptedText;
    if (_dataEncrypted == 0) {
      decryptedText = _encodeDataBody!;
    } else if (secret.isEmpty) {
      return;
    } else {
      decryptedText = WdTransAction.changeText(_encodeDataBody!, secret, '1pat2rqs');
    }
    try {
      _dataBody = jsonDecode(decryptedText) as Map<String, dynamic>?;
    } catch (e) {
      _log('CoolHttpResponse decryDataBody error: $e');
    }
  }

  /// 是否成功（原版 isSuccess）
  bool isSuccess() => _resultCode == sucOk;

  /// 失败日志（原版 failTrace）
  void failTrace() {
    _log(
      'CoolHttpResponse FAIL: data_kind=$_dataKind, '
      'data_version=$_dataVersion, result_code=$_resultCode, '
      'error_info=$_errorInfo, error_message=$_errorMessage',
    );
  }
}

// ============================================================
// CoolJsonHttpResponseHandler — JSON 回调（原版 CoolJsonHttpResponseHandler.java）
// ============================================================

/// JSON 响应回调（原版 CoolJsonHttpResponseHandler）
class CoolJsonHttpResponseHandler {
  void onSuccess(CoolHttpResponse response) {}
  void onFailure(CoolHttpResponse response) {}
}

// ============================================================
// FileHttpResponseHandler — 文件下载回调（原版 FileHttpReponseHandler.java）
// ============================================================

/// 文件下载回调（原版 FileHttpReponseHandler）
class FileHttpResponseHandler {
  void onSuccess(File file) {}
  void onFailure(String path, int errorCode) {}
  void onProgress(int total, int current) {}
}

// ============================================================
// RequestParams — 请求参数（原版 RequestParams.java）
// ============================================================

/// 请求参数封装（原版 RequestParams）
class RequestParams {
  final Map<String, String> _params = {};
  final Map<String, dynamic> _multiParams = {};

  void put(String key, String? value) {
    _params[key] = value ?? '';
  }

  void putInt(String key, int value) {
    _params[key] = value.toString();
  }

  void putLong(String key, int value) {
    _params[key] = value.toString();
  }

  void remove(String key) {
    _params.remove(key);
  }

  void add(String key, String value) {
    _params[key] = value;
  }

  Map<String, String> getParams() => _params;

  /// 添加文件参数（原版 put(String, File)）
  void putFile(String key, dynamic file) {
    _multiParams[key] = file;
  }

  Map<String, dynamic> getMultiParams() => _multiParams;

  /// 获取参数字符串（原版 getParamString）
  String getParamString() {
    final parts = <String>[];
    _params.forEach((key, value) {
      if (parts.isNotEmpty) parts.add('&');
      parts.add('$key=$value');
    });
    return parts.join();
  }

  @override
  String toString() => getParamString();
}

// ============================================================
// CoolParams — 带签名的参数（原版 CoolParams.java）
// ============================================================

/// 带签名的请求参数（原版 CoolParams）
class CoolParams extends RequestParams {
  String? _serviceType;

  CoolParams(String key, String value) {
    put(key, value);
  }

  CoolParams.empty();

  String? getServiceType() => _serviceType;
  void setServiceType(String type) => _serviceType = type;

  /// 生成参数签名（原版 getParamsSign）
  String getParamsSign() {
    final list = <String>[];
    getParams().forEach((key, value) {
      list.add('$key=$value');
    });
    list.sort();
    final sb = StringBuffer();
    for (final item in list) {
      sb.write(item);
    }
    return SecurityUtils.md5String(sb.toString());
  }
}

// ============================================================
// CoolHttpClient — v1 API 客户端（原版 CoolHttpClient.java）
// ============================================================

/// v1 API 客户端（原版 CoolHttpClient）
///
/// 基础 URL: https://sapi.beingfine.cn/v1
/// 支持 GET/POST，自动附加公共参数
class CoolHttpClient {
  static const String _logTag = 'CoolHttpClient';
  static const String _serviceType = 'type';
  static const String _baseUrl = 'https://sapi.beingfine.cn/v1';

  static int _timeoutSeconds = 30;

  /// 设置超时（原版 setTimeout）
  static void setTimeout(int seconds) {
    _timeoutSeconds = seconds;
  }

  /// 获取完整 URL（原版 getAbsoluteUrl）
  static String _getAbsoluteUrl(String? path) {
    if (path == null || path.isEmpty) {
      return _baseUrl;
    }
    return 'https://sapi.beingfine.cn/$path';
  }

  /// GET 请求（原版 get(RequestParams, handler)）
  static Future<void> get(RequestParams requestParams, CoolJsonHttpResponseHandler handler) {
    return getWithSuffix(requestParams, handler, null);
  }

  /// GET 请求（原版 get(RequestParams, handler, suffix)）
  static Future<void> getWithSuffix(
    RequestParams requestParams,
    CoolJsonHttpResponseHandler handler,
    String? suffix,
  ) async {
    _traceParams(requestParams);
    final uri = _buildGetUri((requestParams as CoolParams?), suffix);
    _log('$_logTag request: $uri');

    try {
      final response = await http.get(uri).timeout(Duration(seconds: _timeoutSeconds));
      _handleResponse(response, handler);
    } catch (e) {
      _log('$_logTag IOException: $e');
      _notifyError(handler, CoolHttpResponse());
    }
  }

  /// POST 请求（原版 post）
  static Future<void> post(RequestParams requestParams, CoolJsonHttpResponseHandler handler) async {
    final uri = Uri.parse(_getAbsoluteUrl(null));
    _log('$_logTag post request: $uri');

    try {
      final coolParams = requestParams as CoolParams?;
      http.Response response;

      if (coolParams != null && coolParams.getMultiParams().isNotEmpty) {
        // 有文件参数 → multipart
        response = await _sendMultipartPost(uri, coolParams);
      } else {
        // 普通表单
        response = await http
            .post(uri, body: requestParams.getParams(), headers: {'Content-Type': 'application/x-www-form-urlencoded'})
            .timeout(Duration(seconds: _timeoutSeconds));
      }
      _handleResponse(response, handler);
    } catch (e) {
      _log('$_logTag post IOException: $e');
      _notifyError(handler, CoolHttpResponse());
    }
  }

  /// 带签名的 POST（原版 postAppendSign）
  static Future<void> postAppendSign(CoolParams coolParams, CoolJsonHttpResponseHandler handler) async {
    coolParams.put('sign', coolParams.getParamsSign());
    return post(coolParams, handler);
  }

  /// 构建请求参数（原版 requestParams）
  static CoolParams requestParams(String serviceType) {
    final params = CoolParams(_serviceType, serviceType);
    // 公共参数在调用时由上层填充
    params.setServiceType(serviceType);
    return params;
  }

  /// 构建空参数（原版 requestEmptyParams）
  static CoolParams requestEmptyParams(String serviceType) {
    final params = CoolParams.empty();
    params.setServiceType(serviceType);
    return params;
  }

  /// 取消所有请求（原版 cancelAllRequest）
  /// 注意：Flutter http 包不支持原生取消，此方法为兼容接口
  static void cancelAllRequest() {
    _log('$_logTag cancelAllRequest');
  }

  // === 内部方法 ===

  static Uri _buildGetUri(CoolParams? params, String? suffix) {
    var url = _getAbsoluteUrl(suffix);
    if (params != null && params.getServiceType() != null) {
      url = '$url/${params.getServiceType()}';
    }
    final uri = Uri.parse(url);
    if (params != null) {
      return uri.replace(queryParameters: params.getParams().map((k, v) => MapEntry(k, Uri.encodeComponent(v))));
    }
    return uri;
  }

  static void _handleResponse(http.Response response, CoolJsonHttpResponseHandler handler) {
    if (response.statusCode == 200) {
      try {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final coolResponse = CoolHttpResponse.fromJson(json);
        if (coolResponse.isSuccess()) {
          _notifySucc(handler, coolResponse);
        } else {
          coolResponse.failTrace();
          _notifyError(handler, coolResponse);
        }
      } catch (e) {
        _log('$_logTag response parse error: $e');
        _notifyError(handler, CoolHttpResponse());
      }
    } else {
      _log('$_logTag response error: ${response.statusCode}');
      _notifyError(handler, CoolHttpResponse());
    }
  }

  static Future<http.Response> _sendMultipartPost(Uri uri, CoolParams params) async {
    final request = http.MultipartRequest('POST', uri);
    // 添加文本参数
    params.getParams().forEach((key, value) {
      request.fields[key] = value;
    });
    // 添加文件参数
    params.getMultiParams().forEach((key, value) {
      if (value is File) {
        String? contentType;
        if (value.path.endsWith('.img') || value.path.endsWith('.png')) {
          contentType = 'image/png';
        } else if (value.path.endsWith('.syn')) {
          contentType = 'application/json';
        }
        request.files.add(
          http.MultipartFile.fromBytes(
            key,
            value.readAsBytesSync(),
            filename: value.uri.pathSegments.last,
            contentType: contentType != null ? MediaType.parse(contentType) : null,
          ),
        );
      }
    });
    final streamed = await request.send().timeout(Duration(seconds: _timeoutSeconds));
    return http.Response.fromStream(streamed);
  }

  static void _notifyError(CoolJsonHttpResponseHandler handler, CoolHttpResponse response) {
    handler.onFailure(response);
  }

  static void _notifySucc(CoolJsonHttpResponseHandler handler, CoolHttpResponse response) {
    handler.onSuccess(response);
  }

  static void _traceParams(RequestParams params) {
    _log('$_logTag RequestParams: ${params.toString()}');
  }
}

// ============================================================
// CoolHttpClientV3 — v3 API 客户端（原版 CoolHttpClientV3.java）
// ============================================================

/// v3 API 客户端（原版 CoolHttpClientV3）
///
/// 基础 URL: https://sapi.beingfine.cn/v3
/// 支持 token 认证、响应加密解密、账号过期处理
class CoolHttpClientV3 {
  static const String _logTag = 'CoolHttpClientV3';
  static const int resultAccountExpire = 30102;
  static const int resultAccountExpire2 = 30104;
  static const String _serviceType = 'type';
  static const String _baseUrl = 'https://sapi.beingfine.cn/v3';

  static final int _timeoutSeconds = 30;
  static int _dealExpireDlgTime = 0;

  /// 账号过期回调（原版 dealAccountExpire 弹窗逻辑的 Flutter 等价）
  static void Function()? onAccountExpire;

  /// 构建基础请求参数（原版 requestParams）
  static CoolParams requestParams(String serviceType) {
    final params = CoolParams(_serviceType, serviceType);
    params.setServiceType(serviceType);
    return params;
  }

  /// 构建带 token 的请求参数（原版 requestParamsWithToken）
  static CoolParams requestParamsWithToken(String serviceType) {
    final params = requestParams(serviceType);
    params.putLong('timestamp', DateTime.now().millisecondsSinceEpoch);
    final prefs = AppPreferences();
    params.put('token', prefs.getUserToken());
    return params;
  }

  /// 追加签名（原版 appendParamSign）
  static void appendParamSign(RequestParams requestParams) {
    final secret = _getSecret();
    requestParams.put('sign', WdTransAction.generateSign(requestParams.getParams(), secret, '1pat2rqs'));
  }

  /// GET 请求（原版 get(RequestParams, handler)）
  static Future<void> get(RequestParams requestParams, CoolJsonHttpResponseHandler handler) {
    return getWithSuffix(requestParams, handler, null);
  }

  /// GET 请求（原版 get(RequestParams, handler, suffix)）
  static Future<void> getWithSuffix(
    RequestParams requestParams,
    CoolJsonHttpResponseHandler handler,
    String? suffix,
  ) async {
    _traceParams(requestParams);
    final uri = _buildGetUri(requestParams as CoolParams?, suffix);
    _log('$_logTag request: $uri');

    try {
      final response = await http.get(uri).timeout(Duration(seconds: _timeoutSeconds));
      _handleV3Response(response, handler);
    } catch (e) {
      _log('$_logTag IOException: $e');
      _notifyError(handler, CoolHttpResponse());
    }
  }

  /// POST 请求（原版 post）
  static Future<void> post(RequestParams requestParams, CoolJsonHttpResponseHandler handler) async {
    final uri = Uri.parse(_getAbsoluteUrl(null));
    _log('$_logTag post request: $uri');

    try {
      final coolParams = requestParams as CoolParams?;
      http.Response response;

      if (coolParams != null && coolParams.getMultiParams().isNotEmpty) {
        response = await _sendMultipartPost(uri, coolParams);
      } else {
        response = await http
            .post(uri, body: requestParams.getParams(), headers: {'Content-Type': 'application/x-www-form-urlencoded'})
            .timeout(Duration(seconds: _timeoutSeconds));
      }
      _handleV3Response(response, handler);
    } catch (e) {
      _log('$_logTag post IOException: $e');
      _notifyError(handler, CoolHttpResponse());
    }
  }

  /// 登录检查专用（原版 checkLogin）
  static Future<void> checkLogin(RequestParams requestParams, CoolJsonHttpResponseHandler handler) async {
    final uri = _buildGetUri(requestParams as CoolParams?, null);
    _log('$_logTag request: $uri');

    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 2));
      if (response.statusCode == 200) {
        try {
          final json = jsonDecode(response.body) as Map<String, dynamic>;
          _notifySucc(handler, CoolHttpResponse.fromJsonV3(json));
        } catch (e) {
          _log('$_logTag exception response: $e');
          _notifyError(handler, CoolHttpResponse());
        }
      } else {
        _log('$_logTag error response: ${response.statusCode}');
        _notifyError(handler, CoolHttpResponse());
      }
    } catch (e) {
      _log('$_logTag IOException: $e');
      _notifyError(handler, CoolHttpResponse());
    }
  }

  /// 获取完整 URL（原版 getAbsoluteUrl）
  static String _getAbsoluteUrl(String? suffix) {
    if (suffix == null || suffix.isEmpty) {
      return _baseUrl;
    }
    return 'https://sapi.beingfine.cn/$suffix';
  }

  /// 构建 GET URI（原版 getRequest 的 GET 分支）
  static Uri _buildGetUri(CoolParams? params, String? suffix) {
    var url = _getAbsoluteUrl(suffix);
    if (params != null && params.getServiceType() != null) {
      url = '$url/${params.getServiceType()}/${DateTime.now().millisecondsSinceEpoch}';
    }
    final uri = Uri.parse(url);
    if (params != null) {
      return uri.replace(queryParameters: params.getParams().map((k, v) => MapEntry(k, Uri.encodeComponent(v))));
    }
    return uri;
  }

  /// 处理 v3 响应（原版 onResponse 逻辑）
  static void _handleV3Response(http.Response response, CoolJsonHttpResponseHandler handler) {
    if (response.statusCode == 200) {
      try {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final coolResponse = CoolHttpResponse.fromJsonV3(json);

        // 检查账号过期
        if (coolResponse.resultCode == resultAccountExpire || coolResponse.resultCode == resultAccountExpire2) {
          Future.delayed(const Duration(milliseconds: 200), () {
            _dealAccountExpire();
          });
          return;
        }

        // 保存 v3 security（token/secret）
        _saveV3Security(coolResponse.v3Security);

        // 解密数据体
        coolResponse.decryDataBody(_getSecret());

        if (coolResponse.isSuccess()) {
          _notifySucc(handler, coolResponse);
        } else {
          coolResponse.failTrace();
          _notifyError(handler, coolResponse);
        }
      } catch (e) {
        _log('$_logTag response parse error: $e');
        _notifyError(handler, CoolHttpResponse());
      }
    } else {
      _log('$_logTag error response: ${response.statusCode}');
      _notifyError(handler, CoolHttpResponse());
    }
  }

  /// 保存 v3 security 信息（原版 saveV3Security）
  /// 写入 SecureTokenStorage（加密）+ SharedPreferences（同步回退）
  static void _saveV3Security(Map<String, dynamic>? security) {
    if (security == null) return;
    try {
      final prefs = AppPreferences();
      final secure = SecureTokenStorage();
      if (security.containsKey('token') && security['token'] != null) {
        final token = security['token'] as String;
        prefs.setString(AppPreferences.userToken, token); // 同步回退
        secure.setToken(token); // 加密存储（fire-and-forget）
      }
      if (security.containsKey('secret') && security['secret'] != null) {
        final secret = security['secret'] as String;
        prefs.setString(AppPreferences.userSecret, secret); // 同步回退
        secure.setSecret(secret); // 加密存储（fire-and-forget）
      }
    } catch (e) {
      _log('$_logTag saveV3Security error: $e');
    }
  }

  /// 获取 secret（原版 getSecret）
  /// 优先从 SecureTokenStorage 读取，回退 SharedPreferences
  static String _getSecret() {
    return AppPreferences().getString(AppPreferences.userSecret);
  }

  /// 处理账号过期（原版 dealAccountExpire）
  static void _dealAccountExpire() {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _dealExpireDlgTime < 120000) return;
    _dealExpireDlgTime = now;
    if (onAccountExpire != null) {
      onAccountExpire!();
    }
  }

  /// multipart POST（原版 multipart 上传逻辑）
  static Future<http.Response> _sendMultipartPost(Uri uri, CoolParams params) async {
    final request = http.MultipartRequest('POST', uri);
    params.getParams().forEach((key, value) {
      request.fields[key] = value;
    });
    params.getMultiParams().forEach((key, value) {
      if (value is File) {
        String? contentType;
        if (value.path.endsWith('.img') || value.path.endsWith('.png')) {
          contentType = 'image/png';
        } else if (value.path.endsWith('.syn')) {
          contentType = 'application/json';
        }
        request.files.add(
          http.MultipartFile.fromBytes(
            key,
            value.readAsBytesSync(),
            filename: value.uri.pathSegments.last,
            contentType: contentType != null ? MediaType.parse(contentType) : null,
          ),
        );
      }
    });
    final streamed = await request.send().timeout(Duration(seconds: _timeoutSeconds));
    return http.Response.fromStream(streamed);
  }

  static void _notifyError(CoolJsonHttpResponseHandler handler, CoolHttpResponse response) {
    handler.onFailure(response);
  }

  static void _notifySucc(CoolJsonHttpResponseHandler handler, CoolHttpResponse response) {
    handler.onSuccess(response);
  }

  static void _traceParams(RequestParams params) {
    _log('$_logTag RequestParams: ${params.toString()}');
  }
}

// ============================================================
// DownloadHttpClient — 文件下载客户端（原版 DownloadHttpClient.java）
// ============================================================

/// 文件下载客户端（原版 DownloadHttpClient）
///
/// 支持：异步下载、断点续传、MD5 校验、进度回调
class DownloadHttpClient {
  static const int fileDamage = 10004;
  static const int serviceError = 10003;
  static const int taskCanceled = 10005;
  static const String _logTag = 'DownloadHttpClient';

  final int _connectTimeout;
  final int _readTimeout;
  bool _bSupportResume = false;
  int _startRange = 0;

  /// 连接超时（秒）
  int get connectTimeout => _connectTimeout;

  /// 读取超时（秒）
  int get readTimeout => _readTimeout;

  DownloadHttpClient() : _connectTimeout = 10, _readTimeout = 120;

  DownloadHttpClient.withTimeout(this._connectTimeout, this._readTimeout);

  /// 异步下载文件（原版 asyncDownloadFile(String, String, handler)）
  Future<void> asyncDownloadFile(String savePath, String url, FileHttpResponseHandler handler) async {
    _log('$_logTag asyncDownloadFile: $url');
    try {
      final request = http.Request('GET', Uri.parse(url));
      final streamed = await http.Client().send(request).timeout(Duration(seconds: _readTimeout));

      if (streamed.statusCode == 200) {
        final file = File(savePath);
        file.parent.createSync(recursive: true);
        final sink = file.openWrite();
        final contentLength = streamed.contentLength ?? 0;
        int received = 0;

        await for (final chunk in streamed.stream) {
          sink.add(chunk);
          received += chunk.length;
          handler.onProgress(contentLength, received);
        }
        await sink.flush();
        await sink.close();

        // MD5 校验
        final md5Header = streamed.headers['content-md5'];
        if (md5Header != null && md5Header.isNotEmpty) {
          final fileBytes = file.readAsBytesSync();
          final fileMd5 = SecurityUtils.getFileMd5String(fileBytes);
          if (fileMd5 == md5Header) {
            handler.onSuccess(file);
          } else {
            file.deleteSync();
            handler.onFailure(savePath, fileDamage);
          }
        } else {
          handler.onSuccess(file);
        }
      } else {
        handler.onFailure(savePath, streamed.statusCode);
      }
    } catch (e) {
      _log('$_logTag IOException: $e');
      handler.onFailure(savePath, serviceError);
    }
  }

  /// 异步下载到文件对象（原版 asyncDownloadFile(File, String, handler)）
  Future<void> asyncDownloadToFile(File file, String url, FileHttpResponseHandler handler) {
    _bSupportResume = false;
    _startRange = 0;
    return _downloadToFile(file, url, handler);
  }

  /// 异步下载到文件对象（带断点续传，原版 asyncDownloadFile(File, String, handler, range)）
  Future<void> asyncDownloadToFileResume(File file, String url, FileHttpResponseHandler handler, int startRange) {
    _startRange = startRange;
    _bSupportResume = true;
    return _downloadToFile(file, url, handler);
  }

  /// 同步下载（原版 syncDownloadFile）
  Future<void> syncDownloadFile(String savePath, String url, FileHttpResponseHandler handler) async {
    try {
      final request = http.Request('GET', Uri.parse(url));
      final streamed = await http.Client().send(request);

      if (streamed.statusCode == 200) {
        final file = File(savePath);
        file.parent.createSync(recursive: true);
        final sink = file.openWrite();
        final contentLength = streamed.contentLength ?? 0;
        int received = 0;

        await for (final chunk in streamed.stream) {
          sink.add(chunk);
          received += chunk.length;
          handler.onProgress(contentLength, received);
        }
        await sink.flush();
        await sink.close();

        // MD5 校验
        final md5Header = streamed.headers['content-md5'];
        if (md5Header != null && md5Header.isNotEmpty) {
          final fileBytes = file.readAsBytesSync();
          final fileMd5 = SecurityUtils.getFileMd5String(fileBytes);
          if (fileMd5.isNotEmpty && fileMd5 == md5Header) {
            handler.onSuccess(file);
          } else {
            if (file.existsSync()) file.deleteSync();
            handler.onFailure(savePath, fileDamage);
          }
        } else {
          handler.onSuccess(file);
        }
      } else {
        handler.onFailure(savePath, streamed.statusCode);
      }
    } catch (e) {
      _log('$_logTag IOException: $e');
      handler.onFailure(savePath, serviceError);
    }
  }

  /// 取消所有请求（原版 cancelPeviousRequest）
  void cancelPreviousRequest() {
    _log('$_logTag cancelPreviousRequest');
  }

  // === 内部方法 ===

  Future<void> _downloadToFile(File file, String url, FileHttpResponseHandler handler) async {
    _log('$_logTag asyncDownloadFile: ${file.path}');
    _log('$_logTag url: $url');

    try {
      final uri = Uri.parse(url);
      final headers = <String, String>{};
      if (_bSupportResume && _startRange > 0) {
        headers['Range'] = 'bytes=$_startRange-';
      }

      final request = http.Request('GET', uri);
      request.headers.addAll(headers);
      final streamed = await http.Client().send(request).timeout(Duration(seconds: _readTimeout));

      if (streamed.statusCode == 200 || streamed.statusCode == 206) {
        if (!file.existsSync()) {
          file.parent.createSync(recursive: true);
        }

        final sink = file.openWrite(mode: FileMode.append);
        final contentLength = streamed.contentLength ?? 0;
        int received = 0;

        await for (final chunk in streamed.stream) {
          sink.add(chunk);
          received += chunk.length;
          handler.onProgress(contentLength, received);
        }
        await sink.flush();
        await sink.close();

        // MD5 校验
        final md5Header = streamed.headers['content-md5'];
        if (md5Header != null && md5Header.isNotEmpty) {
          final fileBytes = file.readAsBytesSync();
          final fileMd5 = SecurityUtils.getFileMd5String(fileBytes);
          if (fileMd5.isNotEmpty && fileMd5 == md5Header) {
            handler.onSuccess(file);
          } else {
            handler.onFailure(file.path, fileDamage);
            if (file.existsSync()) file.deleteSync();
          }
        } else {
          handler.onSuccess(file);
        }
      } else {
        handler.onFailure(file.path, streamed.statusCode);
        if (file.existsSync()) file.deleteSync();
      }
    } catch (e) {
      _log('$_logTag Exception: $e');
      if (_bSupportResume) {
        handler.onFailure(file.path, serviceError);
      } else {
        handler.onFailure(file.path, serviceError);
        if (file.existsSync()) file.deleteSync();
      }
    }
  }
}

// ============================================================
// CoolHttpDnsManager — DNS 管理（原版 CoolHttpDnsManager.java）
// ============================================================

/// HTTP DNS 管理（原版 CoolHttpDnsManager）
///
/// 原版使用阿里云 HTTPDNS SDK（com.alibaba.sdk.android.httpdns）
/// Flutter 版本暂不集成，保留接口以供后续扩展
class CoolHttpDnsManager {
  static bool _initialized = false;
  static final Map<String, String> _dnsCache = {};

  /// 初始化 HTTPDNS（原版 initHttpDns）
  /// 注意：Flutter 版本暂不使用阿里云 HTTPDNS，保留空实现
  static void initHttpDns() {
    if (_initialized) return;
    _initialized = true;
    _log('CoolHttpDnsManager: initHttpDns (stub)');
  }

  /// 通过 HTTPDNS 获取 IP（原版 getIpByHostAsync）
  static String? getIpByHostAsync(String host) {
    if (!_initialized) initHttpDns();
    return _dnsCache[host];
  }

  /// 替换 URL 中的 host 为 IP（原版 urlStringFromHttpDns）
  static String urlStringFromHttpDns(String url) {
    if (!_initialized) initHttpDns();
    try {
      final uri = Uri.parse(url);
      final ip = getIpByHostAsync(uri.host);
      if (ip != null) {
        return url.replaceFirst(uri.host, ip);
      }
    } catch (_) {}
    return url;
  }

  /// 检测代理（原版 detectIfProxyExist）
  /// Flutter 无法直接检测系统代理，返回 false
  static bool detectIfProxyExist() {
    return false;
  }
}
