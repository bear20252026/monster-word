// 由 Claude 团队生成 | Monster Word App
// UserServiceImpl — 用户服务实现

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:word_app/models/user_info_bean.dart';
import 'package:word_app/core/infrastructure/app_preferences.dart' hide UserInfoBean;
import 'package:word_app/core/repositories/user_repository.dart';
import 'package:word_app/core/repositories/note_repository.dart';
import 'package:word_app/features/account/data/user_service.dart';

/// 用户服务实现
class UserServiceImpl implements UserService {
  final UserRepository _userRepo;
  final NoteRepository _noteRepo;

  static const _userInfoKey = 'monster_word_user_info';

  UserServiceImpl({required this._userRepo, required this._noteRepo});

  @override
  Future<Map<String, dynamic>?> getUserInfo() async {
    return await _userRepo.getUserInfo();
  }

  @override
  Future<void> updateUserInfo(Map<String, dynamic> info) async {
    await _userRepo.updateUserInfo(info);
  }

  @override
  Future<UserInfoBean> getUserInfoBean() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_userInfoKey);
    if (jsonStr == null || jsonStr.isEmpty) return UserInfoBean();
    try {
      return UserInfoBean.fromJson(jsonDecode(jsonStr) as Map<String, dynamic>);
    } catch (_) {
      return UserInfoBean();
    }
  }

  @override
  Future<bool> setUserInfoBean(UserInfoBean bean) async {
    // 安全审计 S1：token/secret 只入平台安全存储，SharedPreferences 不落凭证
    if (bean.token.isNotEmpty) {
      await SecureTokenStorage().setToken(bean.token);
    }
    if (bean.secret.isNotEmpty) {
      await SecureTokenStorage().setSecret(bean.secret);
    }
    final sanitized = UserInfoBean.fromJson(bean.toJson())..token = ''..secret = '';
    final prefs = await SharedPreferences.getInstance();
    return prefs.setString(_userInfoKey, jsonEncode(sanitized.toJson()));
  }

  @override
  Future<Map<String, dynamic>> getLearningStats() async {
    return await _userRepo.getLearningStats();
  }

  @override
  Future<List<Map<String, dynamic>>> getNotes(int wordId) async {
    final notes = await _noteRepo.getNotesByWord(wordId);
    return notes.map((n) => n.toMap()).toList();
  }

  @override
  Future<void> addNote(int wordId, String content) async {
    await _noteRepo.addNote(wordId, content);
  }

  @override
  Future<void> deleteNote(int noteId) async {
    await _noteRepo.deleteNote(noteId);
  }
}
