// 由 Claude 团队生成 | Monster Word App

// 翻译自 util/SecurityUtils.java, SHA1.java, WDTransAction.java, SecurePreferences.dart
// 加密/解密/哈希工具

import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:encrypt/encrypt.dart' as encrypt_lib;

/// 加密工具（翻译自 SecurityUtils.java）
class SecurityUtils {
  static final _iv = encrypt_lib.IV(Uint8List.fromList([1, 0x70, 97, 0x74, 2, 0x72, 0x71, 0x73]));

  /// AES 加密（默认密钥 "iscooler"，原版 DES 已弃用）
  static String encryptDES(String str, {String key = 'iscooler'}) {
    final keyBytes = encrypt_lib.Key.fromUtf8(key);
    final encrypter = encrypt_lib.Encrypter(encrypt_lib.AES(keyBytes, mode: encrypt_lib.AESMode.cbc, padding: 'PKCS7'));
    return encrypter.encrypt(str, iv: _iv).base64;
  }

  /// AES 解密（默认密钥 "iscooler"，原版 DES 已弃用）
  static String decryptDES(String str, {String key = 'iscooler'}) {
    final keyBytes = encrypt_lib.Key.fromUtf8(key);
    final encrypter = encrypt_lib.Encrypter(encrypt_lib.AES(keyBytes, mode: encrypt_lib.AESMode.cbc, padding: 'PKCS7'));
    return encrypter.decrypt64(str, iv: _iv);
  }

  /// URL 编码
  static String urlEncode(String str) => Uri.encodeComponent(str);

  /// URL 解码
  static String urlDecode(String str) => Uri.decodeComponent(str);

  /// MD5 hex 字符串（字节数组版本）
  static String md5Bytes(List<int> bytes) {
    return crypto.md5.convert(bytes).toString();
  }

  /// MD5 hex 字符串（字符串 UTF-8 版本）
  static String md5StringWithUtf8(String str) {
    return md5Bytes(utf8.encode(str));
  }

  /// 兼容旧接口
  static String md5String(String input) => md5StringWithUtf8(input);

  /// 文件 MD5（返回 Base64，兼容原版 getFileMd5String）
  static String getFileMd5String(Uint8List fileBytes) {
    try {
      final digest = crypto.md5.convert(fileBytes);
      return base64Encode(digest.bytes);
    } catch (_) {
      return '';
    }
  }
}

/// SHA1 工具（翻译自 SHA1.java）
class Sha1Utils {
  /// 计算字节数组的 SHA1 hex
  static String sha1Hex(List<int> bytes) {
    return crypto.sha1.convert(bytes).toString();
  }

  /// 计算字符串的 SHA1 hex
  static String sha1String(String str) {
    return sha1Hex(utf8.encode(str));
  }

  /// 字节数组转 hex（兼容原版 byteArrayToHex）
  static String byteArrayToHex(List<int> bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}

/// AES 加解密工具（翻译自 WDTransAction.java）
class WdTransAction {
  /// AES CBC 解密
  static Uint8List transfer(Uint8List data, String key, String ivStr) {
    final keyBytes = encrypt_lib.Key.fromUtf8(key);
    final iv = encrypt_lib.IV.fromUtf8(ivStr);
    final encrypter = encrypt_lib.Encrypter(encrypt_lib.AES(keyBytes, mode: encrypt_lib.AESMode.cbc, padding: 'PKCS7'));
    // encrypt/decrypt 操作
    final encrypted = encrypt_lib.Encrypted(data);
    return encrypter.decryptBytes(encrypted, iv: iv) as Uint8List;
  }

  /// AES CBC 加密
  static Uint8List trans(Uint8List data, String key, String ivStr) {
    final keyBytes = encrypt_lib.Key.fromUtf8(key);
    final iv = encrypt_lib.IV.fromUtf8(ivStr);
    final encrypter = encrypt_lib.Encrypter(encrypt_lib.AES(keyBytes, mode: encrypt_lib.AESMode.cbc, padding: 'PKCS7'));
    return encrypter.encryptBytes(data, iv: iv).bytes;
  }

  /// 解密 Base64 编码的文本
  static String changeText(String base64Str, String key, String ivStr) {
    try {
      final data = base64.decode(base64Str);
      final decrypted = transfer(data, key, ivStr);
      return utf8.decode(decrypted);
    } catch (e) {
      return '';
    }
  }

  /// 生成签名（翻译自 generateSign）
  static String generateSign(Map<String, String> params, String key, String ivStr) {
    try {
      final content = _getContent(params);
      final encrypted = trans(Uint8List.fromList(utf8.encode(content)), key, ivStr);
      final base64Str = base64Encode(encrypted).replaceAll(' ', '');
      return SecurityUtils.md5StringWithUtf8(base64Str);
    } catch (e) {
      return '';
    }
  }

  static String _getContent(Map<String, String> map) {
    if (map.isEmpty) return '';
    final sortedKeys = map.keys.toList()..sort();
    final parts = <String>[];
    for (var i = 0; i < sortedKeys.length; i++) {
      final key = sortedKeys[i];
      final value = map[key] ?? '';
      parts.add('${i == 0 ? '' : '&'}$key=$value');
    }
    return parts.join('');
  }
}

/// Base64 编解码（翻译自 SecurityUtils.CodeDeal）
class CodeDeal {
  static String encode(List<int> bytes) => base64Encode(bytes);
  static Uint8List decode(String str) => base64Decode(str);
}
