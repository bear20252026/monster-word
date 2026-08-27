// 由 Claude 团队生成 | Monster Word App
// UserServiceImpl — 用户服务实现

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../models/user_info_bean.dart';
import '../../repositories/user_repository.dart';
import '../../repositories/note_repository.dart';
import 'user_service.dart';

/// 用户服务实现
class UserServiceImpl implements UserService {
  final UserRepository _userRepo;
  final NoteRepository _noteRepo;

  static const _userInfoKey = 'monster_word_user_info';

  UserServiceImpl({required UserRepository userRepo, required NoteRepository noteRepo})
    : _userRepo = userRepo,
      _noteRepo = noteRepo;

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
    final prefs = await SharedPreferences.getInstance();
    return prefs.setString(_userInfoKey, jsonEncode(bean.toJson()));
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
