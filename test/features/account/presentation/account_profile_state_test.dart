import 'package:flutter_test/flutter_test.dart';
import 'package:word_app/features/account/application/account_profile_store.dart';
import 'package:word_app/features/account/data/account_profile_repository.dart';
import 'package:word_app/features/account/domain/account_profile.dart';
import 'package:word_app/features/account/presentation/account_profile_state.dart';
import 'package:word_app/models/user_info_bean.dart';
import 'package:word_app/services/user_service.dart';

void main() {
  test('账号资料状态加载无凭据展示快照并通知订阅者', () async {
    final store = _FakeAccountProfileStore(
      const AccountProfile(
        userId: 9,
        nickname: '小熊',
        avatar: 'avatar.png',
        phone: '13800000000',
        displayId: 'bear-9',
        wechatName: 'bear_wechat',
        signature: '持续学习',
      ),
    );
    final state = AccountProfileState(profileStore: store);
    var notifications = 0;
    state.addListener(() => notifications++);

    await state.refresh();

    expect(state.nickname, '小熊');
    expect(state.displayId, 'bear-9');
    expect(state.wechatName, 'bear_wechat');
    expect(state.signature, '持续学习');
    expect(state.isLoading, isFalse);
    expect(notifications, greaterThanOrEqualTo(2));
  });

  test('账号资料仓储编辑展示字段时保留认证凭据', () async {
    final service = _FakeUserService(
      UserInfoBean(nickname: '旧昵称', token: 'token', secret: 'secret', phone: '13800000000'),
    );
    final repository = AccountProfileRepository(userService: service);

    await repository.save(
      const AccountProfile(
        userId: 0,
        nickname: '新昵称',
        avatar: '',
        phone: '13900000000',
        displayId: 'new-id',
        wechatName: '新微信',
        signature: '新签名',
      ),
    );

    expect(service.bean.nickname, '新昵称');
    expect(service.bean.phone, '13900000000');
    expect(service.bean.displayId, 'new-id');
    expect(service.bean.wechatName, '新微信');
    expect(service.bean.signature, '新签名');
    expect(service.bean.token, 'token');
    expect(service.bean.secret, 'secret');
  });

  test('账号资料状态以单一快照保存所有可编辑字段', () async {
    final store = _FakeAccountProfileStore(const AccountProfile.empty());
    final state = AccountProfileState(profileStore: store);
    await state.refresh();

    await state.updateNickname('新的昵称');
    await state.updateWechatName('新的微信');
    await state.updateDisplayId('new-id');
    await state.updateSignature('新的签名');

    expect(state.nickname, '新的昵称');
    expect(state.wechatName, '新的微信');
    expect(state.displayId, 'new-id');
    expect(state.signature, '新的签名');
    expect(store.savedProfiles, hasLength(4));
    expect(store.savedProfiles.last.nickname, '新的昵称');
    expect(store.savedProfiles.last.wechatName, '新的微信');
    expect(store.savedProfiles.last.displayId, 'new-id');
    expect(store.savedProfiles.last.signature, '新的签名');
  });
}

class _FakeUserService implements UserService {
  _FakeUserService(this.bean);

  UserInfoBean bean;

  @override
  Future<UserInfoBean> getUserInfoBean() async => bean;

  @override
  Future<bool> setUserInfoBean(UserInfoBean value) async {
    bean = value;
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeAccountProfileStore implements AccountProfileStore {
  _FakeAccountProfileStore(this._profile);

  AccountProfile _profile;
  final List<AccountProfile> savedProfiles = [];

  @override
  Future<AccountProfile> load() async => _profile;

  @override
  Future<void> save(AccountProfile profile) async {
    _profile = profile;
    savedProfiles.add(profile);
  }
}
