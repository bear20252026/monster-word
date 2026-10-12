// MW-78：用户协议与隐私政策正文（单一真相）。
//
// 背景：登录页此前只显示「用户协议 / 隐私政策」两个**不可点击**的词——用户
// 无从查看正文，也无从留痕「同意了哪一版」。本文件承载正文与版本号，配合
// LegalConsentStore 记录 policyVersion + acceptedAt。
//
// 版本口径：正文有实质修改时同步提升 [LegalDocuments.policyVersion]；届时
// 旧同意记录视为过期（`isCurrentVersionAccepted` 返回 false），可据此重新
// 征得同意。版本号用日期，便于与发版记录对照。

class LegalSection {
  const LegalSection({required this.heading, required this.paragraphs});

  final String heading;
  final List<String> paragraphs;
}

class LegalDocument {
  const LegalDocument({required this.id, required this.title, required this.version, required this.sections});

  /// 稳定标识（同意留痕与埋点用）。
  final String id;
  final String title;
  final String version;
  final List<LegalSection> sections;

  /// 纯文本正文（供测试断言与无障碍朗读）。
  String get plainText => [
    title,
    '版本 $version',
    for (final section in sections) ...[section.heading, ...section.paragraphs],
  ].join('\n');
}

class LegalDocuments {
  /// 当前生效的政策版本。正文实质变更时同步更新。
  static const String policyVersion = '2026-10-11';

  static const LegalDocument userAgreement = LegalDocument(
    id: 'user_agreement',
    title: '用户协议',
    version: policyVersion,
    sections: [
      LegalSection(
        heading: '一、服务说明',
        paragraphs: [
          'Monster Word（下称「本应用」）是一款以怪兽养成为激励主线的英语单词学习应用，提供词书浏览、单词学习、'
              '记忆曲线复习、生词与例句收藏、学习进度统计等功能。',
          '本应用的词库与例句随安装包离线提供，核心学习流程无需联网即可完成。联网仅用于单词与例句发音、'
              '短信验证码、版本更新检查与崩溃诊断。',
        ],
      ),
      LegalSection(
        heading: '二、账号与登录',
        paragraphs: [
          '本应用不设远程账号服务器，账号信息与学习数据均保存在您的本机。',
          '使用手机号登录时，手机号仅用于接收登录验证码与找回本机账号密码，不会用于其他用途。',
          '请妥善保管本机与登录凭证。因设备丢失、转借或系统重置导致的资料泄露或丢失，本应用无法代为找回。',
        ],
      ),
      LegalSection(
        heading: '三、虚拟道具',
        paragraphs: [
          '本应用内的尖叫币、保护卡等均为应用内虚拟道具，仅可在本应用内使用。',
          '虚拟道具不可兑换现金、不可转让、不可折现，也不构成任何财产权益。',
          '因清除应用数据、卸载重装或更换设备导致的虚拟道具丢失，无法恢复。',
        ],
      ),
      LegalSection(
        heading: '四、使用规范',
        paragraphs: ['请勿对本应用进行反向工程、反编译或修改，请勿批量抓取、复制或再分发随包词库与例句数据。', '请勿利用本应用从事任何违反法律法规的活动。'],
      ),
      LegalSection(
        heading: '五、学习内容与免责',
        paragraphs: ['词库释义、音标与例句来自公开词典资料，仅供学习参考。如与权威辞书存在差异，以权威辞书为准。', '复习安排由记忆算法自动生成，属学习建议，不构成任何学习效果或考试成绩的承诺。'],
      ),
      LegalSection(heading: '六、服务变更与终止', paragraphs: ['本应用可能随版本升级调整功能，重大变更将在应用内以显著方式提示。', '您可以随时停止使用并卸载本应用。']),
      LegalSection(heading: '七、联系我们', paragraphs: ['如对本协议有任何疑问，可通过「更多设置 → 帮助与反馈」提交反馈。']),
    ],
  );

  static const LegalDocument privacyPolicy = LegalDocument(
    id: 'privacy_policy',
    title: '隐私政策',
    version: policyVersion,
    sections: [
      LegalSection(
        heading: '一、我们收集哪些信息',
        paragraphs: [
          '登录凭证：手机号（用于发送登录验证码与找回密码）。密码仅以「盐值 + 哈希」形式保存在本机安全存储中，'
              '本应用不保存明文密码。',
          '账号资料：昵称、头像、个性签名。均为选填，由您主动填写。',
          '学习数据：词书进度、答题记录、记忆状态、收藏与生词、签到与虚拟道具流水。',
          '崩溃诊断信息：应用版本、系统版本与崩溃堆栈，用于定位故障。',
        ],
      ),
      LegalSection(
        heading: '二、信息保存在哪里',
        paragraphs: [
          '上述账号资料与学习数据全部保存在您的本机（本地数据库与本地存储）。本应用不上传至任何服务器，'
              '也不进行云端同步。',
          '卸载本应用或清除应用数据会一并删除上述本地数据，且无法恢复。',
        ],
      ),
      LegalSection(
        heading: '三、第三方服务',
        paragraphs: [
          '单词发音：请求有道词典公开发音接口（dict.youdao.com），会传输被朗读的单词文本。',
          '例句音频：从音频内容分发网络（audio.beingfine.cn 及其备用域名）下载音频文件。',
          '短信验证码：通过 Spug 推送服务（push.spug.cc）下发登录验证码，会传输接收短信的手机号。',
          '崩溃诊断：使用 Sentry 收集崩溃堆栈与设备基础信息，不包含学习内容与账号资料。',
          '上述第三方服务仅在对应功能被使用时才会收到数据。',
        ],
      ),
      LegalSection(
        heading: '四、权限说明',
        paragraphs: ['网络访问：下载发音与例句音频、发送验证码、检查版本更新。', '通知：发送学习提醒与签到提醒，您可在系统设置中随时关闭。', '存储读写：缓存音频文件、保存头像图片。'],
      ),
      LegalSection(
        heading: '五、您的权利',
        paragraphs: ['您可以在「我的」中随时查看与修改昵称、头像与个性签名。', '您可以在应用内删除收藏、生词与笔记，或通过清除应用数据一次性删除全部本地数据。'],
      ),
      LegalSection(heading: '六、未成年人保护', paragraphs: ['若您为未成年人，请在监护人指导下使用本应用。本应用不主动收集未成年人的额外个人信息。']),
      LegalSection(heading: '七、政策变更', paragraphs: ['本政策如有实质变更，将更新版本号并在应用内提示。继续使用即表示接受变更后的政策。']),
      LegalSection(heading: '八、联系我们', paragraphs: ['如对个人信息处理有任何疑问，可通过「更多设置 → 帮助与反馈」提交反馈。']),
    ],
  );

  static const List<LegalDocument> all = [userAgreement, privacyPolicy];
}
