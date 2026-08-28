import 'package:flutter/foundation.dart';

import '../application/account_profile_store.dart';
import '../domain/account_profile.dart';

/// 账户功能域内的个人资料状态。
///
/// 该状态只负责可展示的资料快照和资料编辑，不承接登录、令牌或首次引导职责。
class AccountProfileState extends ChangeNotifier {
  AccountProfileState({required this._profileStore});

  final AccountProfileStore _profileStore;

  AccountProfile _profile = const AccountProfile.empty();
  bool _isLoading = true;
  Object? _loadError;

  AccountProfile get profile => _profile;
  bool get isLoading => _isLoading;
  Object? get loadError => _loadError;

  String get nickname => _profile.nickname;
  String get wechatName => _profile.wechatName;
  String get displayId => _profile.displayId;
  String get avatar => _profile.avatar;
  String get phone => _profile.phone;
  String get signature => _profile.signature;

  Future<void> refresh() async {
    _isLoading = true;
    _loadError = null;
    notifyListeners();
    try {
      _profile = await _profileStore.load();
    } catch (error) {
      _loadError = error;
      debugPrint('Account profile loading error: $error');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateNickname(String value) => _update(_profile.copyWith(nickname: value));
  Future<void> updateWechatName(String value) => _update(_profile.copyWith(wechatName: value));
  Future<void> updateDisplayId(String value) => _update(_profile.copyWith(displayId: value));
  Future<void> updateSignature(String value) => _update(_profile.copyWith(signature: value));
  Future<void> updateAvatar(String value) => _update(_profile.copyWith(avatar: value));
  Future<void> updatePhone(String value) => _update(_profile.copyWith(phone: value));

  Future<void> _update(AccountProfile next) async {
    _profile = next;
    notifyListeners();
    try {
      await _profileStore.save(next);
    } catch (error) {
      debugPrint('Account profile saving error: $error');
    }
  }
}
