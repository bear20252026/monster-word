// 披露文本 × 工程事实 一致性测试（R2-23 同类问题的守卫）。
//
// 为什么需要这组测试：装配了服务端认证的构建（构建时注入 AUTH_BASE_URL）里，
// 账号在服务端、密码经网络提交。若正文仍写「本应用不设远程账号服务器」，
// 那就是一句**假陈述**——用户基于它做出的判断会被误导。文本正确性靠人眼 review
// 不可靠，故把两种模式的互斥断言锁死：本机模式不得出现服务端措辞，服务端模式
// 不得出现仅本机才成立的承诺。
import 'package:flutter_test/flutter_test.dart';

import 'package:word_app/features/account/domain/legal_documents.dart';

/// 仅在本机模式下成立的表述。
const _localOnlyClaims = ['不设远程账号服务器', '本应用不上传至任何服务器', '仅以「盐值 + 哈希」形式保存在本机安全存储中'];

/// 仅在服务端模式下成立的表述。
const _serverOnlyClaims = ['账号服务器校验登录', '提交至账号服务器校验'];

void main() {
  group('两种模式的结构一致性', () {
    test('同一 id / title，且版本号都等于 policyVersion', () {
      for (final mode in [false, true]) {
        final agreement = LegalDocuments.userAgreement(serverAccountMode: mode);
        final privacy = LegalDocuments.privacyPolicy(serverAccountMode: mode);
        expect(agreement.id, 'user_agreement');
        expect(privacy.id, 'privacy_policy');
        expect(agreement.version, LegalDocuments.policyVersion);
        expect(privacy.version, LegalDocuments.policyVersion);
      }
    });

    test('两种模式共用一个版本号（避免「版本号相同但正文不同」的同意留痕漏洞）', () {
      // 若给两种模式各配一个版本号，切换模式时用户已「同意」的版本号会与新正文
      // 匹配，等于让他同意了没看过的文本。共用版本号 + 切换时重征得同意才是安全的。
      expect(
        LegalDocuments.userAgreement(serverAccountMode: true).version,
        LegalDocuments.userAgreement(serverAccountMode: false).version,
      );
    });

    test('默认参数等价于本机模式（不传参不会意外变成服务端措辞）', () {
      expect(
        LegalDocuments.userAgreement().plainText,
        LegalDocuments.userAgreement(serverAccountMode: false).plainText,
      );
      expect(
        LegalDocuments.privacyPolicy().plainText,
        LegalDocuments.privacyPolicy(serverAccountMode: false).plainText,
      );
    });

    test('all() 返回两篇，且与传入模式一致', () {
      final docs = LegalDocuments.all(serverAccountMode: true);
      expect(docs.map((d) => d.id).toList(), ['user_agreement', 'privacy_policy']);
      expect(docs.first.plainText, LegalDocuments.userAgreement(serverAccountMode: true).plainText);
    });
  });

  group('本机模式：不得出现服务端措辞', () {
    test('用户协议', () {
      final text = LegalDocuments.userAgreement().plainText;
      for (final claim in _serverOnlyClaims) {
        expect(text, isNot(contains(claim)), reason: '本机模式下不该出现「$claim」');
      }
    });

    test('隐私政策', () {
      final text = LegalDocuments.privacyPolicy().plainText;
      for (final claim in _serverOnlyClaims) {
        expect(text, isNot(contains(claim)), reason: '本机模式下不该出现「$claim」');
      }
    });
  });

  group('服务端模式：不得保留仅本机才成立的承诺', () {
    test('用户协议不得再声称「不设远程账号服务器」', () {
      final text = LegalDocuments.userAgreement(serverAccountMode: true).plainText;
      for (final claim in _localOnlyClaims) {
        expect(text, isNot(contains(claim)), reason: '服务端模式下「$claim」已是假陈述');
      }
    });

    test('隐私政策不得再声称「不上传至任何服务器」', () {
      final text = LegalDocuments.privacyPolicy(serverAccountMode: true).plainText;
      for (final claim in _localOnlyClaims) {
        expect(text, isNot(contains(claim)), reason: '服务端模式下「$claim」已是假陈述');
      }
    });

    test('必须明确告知密码会提交给服务端校验', () {
      expect(LegalDocuments.userAgreement(serverAccountMode: true).plainText, contains('提交至账号服务器校验'));
      expect(LegalDocuments.privacyPolicy(serverAccountMode: true).plainText, contains('提交至账号服务器校验'));
    });

    test('必须明确告知账号保存在服务端，而学习数据仍在本机', () {
      final text = LegalDocuments.privacyPolicy(serverAccountMode: true).plainText;
      expect(text, contains('保存在本应用的账号服务器'));
      expect(text, contains('学习数据仍全部保存在您的本机'));
    });

    test('必须告知卸载不会删除服务端账号', () {
      // 本机模式写「卸载即删除全部数据」是成立的；服务端模式下账号不随卸载消失，
      // 不说明会让用户以为卸载就等于注销。
      expect(LegalDocuments.privacyPolicy(serverAccountMode: true).plainText, contains('不随卸载删除'));
    });
  });

  group('两种模式都必须保留的共性承诺', () {
    test('不保存明文密码', () {
      for (final mode in [false, true]) {
        expect(LegalDocuments.userAgreement(serverAccountMode: mode).plainText, contains('不保存明文密码'));
        expect(LegalDocuments.privacyPolicy(serverAccountMode: mode).plainText, contains('不保存明文密码'));
      }
    });

    test('不收集手机号', () {
      for (final mode in [false, true]) {
        expect(LegalDocuments.privacyPolicy(serverAccountMode: mode).plainText, contains('也不收集手机号'));
      }
    });

    test('Sentry 反馈披露（R2-23 修复）在两种模式下都保留', () {
      for (final mode in [false, true]) {
        expect(LegalDocuments.privacyPolicy(serverAccountMode: mode).plainText, contains('帮助与反馈'));
      }
    });
  });
}
