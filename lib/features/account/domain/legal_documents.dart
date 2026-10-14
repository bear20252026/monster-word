// MW-78：用户协议与隐私政策正文（单一真相）。
//
// 背景：登录页此前只显示「用户协议 / 隐私政策」两个**不可点击**的词——用户
// 无从查看正文，也无从留痕「同意了哪一版」。本文件承载正文与版本号，配合
// LegalConsentStore 记录 policyVersion + acceptedAt。
//
// 版本口径：正文有实质修改时同步提升 [LegalDocuments.policyVersion]；届时
// 旧同意记录视为过期（`isCurrentVersionAccepted` 返回 false），可据此重新
// 征得同意。版本号用日期，便于与发版记录对照。
//
// 2026-10-14（R2-01 阶段二）：正文按**账号存放位置**分叉。装配了服务端认证
// （AUTH_BASE_URL）的构建里，账号在服务端、密码经网络提交；此前「本应用不设
// 远程账号服务器」「密码仅保存在本机」在那种构建里就是假陈述——与 R2-23 同类。
// 两种模式**共用一个版本号**：宁可让本机模式的用户多同意一次，也不要让版本号
// 相同而正文不同，那等于让用户「同意」了他没看过的文本。

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
  static const String policyVersion = '2026-10-14';

  /// 用户协议。
  ///
  /// [serverAccountMode] 为 true 时（构建时注入了 AUTH_BASE_URL），账号在服务端、
  /// 密码经加密连接提交——措辞必须跟着变，否则披露与实际行为不符。
  /// 参数是裸 `bool` 而不是 `AccountScope`：本文件属 domain 层，不得依赖 application
  /// （架构守卫 R3），由 presentation 层把 scope 翻译成 bool 传进来。
  static LegalDocument userAgreement({bool serverAccountMode = false}) => LegalDocument(
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
              '版本更新检查与崩溃诊断。',
        ],
      ),
      LegalSection(
        heading: '二、账号与登录',
        paragraphs: [
          if (serverAccountMode) '本应用使用自建账号服务器校验登录：账号由服务端保存，学习数据仍全部保存在您的本机。' else '本应用不设远程账号服务器，账号信息与学习数据均保存在您的本机。',
          if (serverAccountMode)
            '登录使用「用户名 + 密码」：密码经加密连接提交至账号服务器校验，服务端以不可逆哈希形式保存；'
                '本应用不保存明文密码，也不收集手机号用于登录。'
          else
            '登录使用「用户名 + 密码」：密码仅以「盐值 + 哈希」形式保存在本机安全存储中，本应用不保存明文密码，'
                '也不收集手机号用于登录。',
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

  /// 隐私政策。分叉口径同 [userAgreement]。
  static LegalDocument privacyPolicy({bool serverAccountMode = false}) => LegalDocument(
    id: 'privacy_policy',
    title: '隐私政策',
    version: policyVersion,
    sections: [
      LegalSection(
        heading: '一、我们收集哪些信息',
        paragraphs: [
          if (serverAccountMode)
            '登录凭证：用户名。密码经加密连接提交至账号服务器校验，服务端以不可逆哈希形式保存；'
                '本应用不保存明文密码，也不收集手机号。'
          else
            '登录凭证：用户名。密码仅以「盐值 + 哈希」形式保存在本机安全存储中，本应用不保存明文密码，'
                '也不收集手机号。',
          '账号资料：昵称、头像、个性签名。均为选填，由您主动填写。',
          '学习数据：词书进度、答题记录、记忆状态、收藏与生词、签到与虚拟道具流水。',
          '崩溃诊断信息：应用版本、系统版本与崩溃堆栈，用于定位故障。',
        ],
      ),
      LegalSection(
        heading: '二、信息保存在哪里',
        paragraphs: [
          if (serverAccountMode)
            '登录账号（用户名与服务端保存的密码哈希）保存在本应用的账号服务器。'
                '账号资料与学习数据仍全部保存在您的本机（本地数据库与本地存储），'
                '本应用不上传学习内容，也不进行云端同步。'
          else
            '上述账号资料与学习数据全部保存在您的本机（本地数据库与本地存储）。本应用不上传至任何服务器，'
                '也不进行云端同步。',
          '卸载本应用或清除应用数据会一并删除上述本地数据，且无法恢复。'
              '（账号服务器上的登录账号不随卸载删除，如需注销请联系管理员。）',
        ],
      ),
      LegalSection(
        heading: '三、第三方服务',
        paragraphs: [
          '单词发音：请求有道词典公开发音接口（dict.youdao.com），会传输被朗读的单词文本。',
          '例句音频：从音频内容分发网络（audio.beingfine.cn 及其备用域名）下载音频文件。',
          // 2026-10-13：短信登录/找回密码已移除，Spug 披露条目一并删除
          //（Spug 官方要求验证码由服务端发起，客户端不再持有任何调用凭证）。
          '崩溃诊断：使用 Sentry 收集崩溃堆栈与设备基础信息，不包含学习内容与账号资料。',
          // R2-23：此前只写了「崩溃诊断」，但「帮助与反馈」也走 Sentry
          // （Sentry.captureFeedback 会上传反馈正文与用户主动填写的联系方式），
          // 属政策文本与工程事实不一致，故按实际处理行为单独披露。
          '帮助与反馈：当您主动提交反馈时，反馈正文及您填写的联系方式（邮箱或手机号）会发送至 Sentry，用于接收与处理您的反馈。不提交反馈则不会上传这些内容。',
          '上述第三方服务仅在对应功能被使用时才会收到数据。',
        ],
      ),
      LegalSection(
        heading: '四、权限说明',
        paragraphs: ['网络访问：下载发音与例句音频、检查版本更新、提交帮助与反馈。', '通知：发送学习提醒与签到提醒，您可在系统设置中随时关闭。', '存储读写：缓存音频文件、保存头像图片。'],
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

  /// 全部协议（按当前模式生成）。
  static List<LegalDocument> all({bool serverAccountMode = false}) => [
    userAgreement(serverAccountMode: serverAccountMode),
    privacyPolicy(serverAccountMode: serverAccountMode),
  ];
}
