// 「路由 → 模块标识」的映射（纯 Dart，可本机直跑断言）。
//
// 用途：`recordModuleOpen` 需要知道用户打开了哪个功能模块。模块标识是固定的白名单
// （见 UsageDailyStats.knownModules），**不是用户输入**，所以不构成内容泄露。
//
// 为什么单独成文件而不是写进 NavigatorObserver：
//   1. 本仓 `flutter test` 受 365vpn 影响不可用，只有不 import flutter 的代码能在本机
//      真跑断言（见 lib/features/telemetry/README.md）——映射表是这里最值得测的部分。
//   2. 观察者只管「取到路由名 → 查表 → 上报」，判断逻辑与副作用分离。
//
// 未收录的路由一律返回 null（不上报）。**宁可少记，也不要记错**：
// 错误归属会让「哪个模块受欢迎」这个指标失去意义，而漏记只是少一个数据点。

import 'package:word_app/app/router/route_names.dart';

/// 路由名 → 模块标识；未收录返回 null。
String? moduleForRoute(String? routeName) {
  if (routeName == null || routeName.isEmpty) return null;

  // 精确匹配优先。深链可能带查询串（如 `/dictionary/byName?word=x`），
  // 故再做一次「去掉 ? 与 # 之后的前缀匹配」兜底。
  final exact = _byRoute[routeName];
  if (exact != null) return exact;

  final cut = routeName.indexOf(RegExp(r'[?#]'));
  final path = cut >= 0 ? routeName.substring(0, cut) : routeName;
  return _byRoute[path];
}

/// 已收录的路由（供测试断言「没有重复/遗漏」用）。
Map<String, String> get moduleRoutes => Map.unmodifiable(_byRoute);

/// 映射表。
///
/// 口径说明（产品判断，改之前先想清楚指标语义）：
///   - 刷词/背词类入口（含沉浸式刷词、拼写、听写、句子测验）都归 `review`：
///     它们都是「已学词的再练」，与首次学习的 `learn` 是不同性质。
///   - `profile` 收纳个人中心与各类设置页：它们共同的语义是「用户主动去管理自己」。
///   - 登录/启动页**不收录**：那是必经流程，不是「打开了某个模块」。
const Map<String, String> _byRoute = {
  // ── learn：首次学习 ──────────────────────────────────────────
  RouteNames.learn: 'learn',
  RouteNames.learnSession: 'learn',
  RouteNames.immersiveSwipe: 'learn',

  // ── review：复习与再练 ──────────────────────────────────────
  // 注意：RouteNames.reviewSession 已 @Deprecated（旧深链会重定向到 /review），
  // 这里**刻意不引用它** —— 引用会触发 deprecated_member_use，而本仓把 analyzer 的
  // info 也当失败。重定向后观察者看到的就是 /review，本来也不需要单列。
  RouteNames.review: 'review',
  RouteNames.reviewingWords: 'review',
  RouteNames.examQuickReview: 'review',
  RouteNames.spellCheck: 'review',
  RouteNames.spellSession: 'review',
  RouteNames.quickSpell: 'review',
  RouteNames.dictationSession: 'review',
  RouteNames.sentenceQuiz: 'review',
  RouteNames.wordMachine: 'review',

  // ── listen：听音 ────────────────────────────────────────────
  RouteNames.wordListen: 'listen',
  RouteNames.listenModeSelect: 'listen',
  RouteNames.listeningPlayer: 'listen',

  // ── dict：查词 ──────────────────────────────────────────────
  RouteNames.dictionary: 'dict',
  RouteNames.dictionaryByName: 'dict',
  RouteNames.wordDetail: 'dict',

  // ── book：词书 ──────────────────────────────────────────────
  RouteNames.libSelect: 'book',
  RouteNames.bookWords: 'book',
  RouteNames.wordExport: 'book',

  // ── content：我的内容 ───────────────────────────────────────
  RouteNames.myContent: 'content',
  RouteNames.myFav: 'content',
  RouteNames.myFavSentence: 'content',
  RouteNames.sentenceDetail: 'content',
  RouteNames.messages: 'content',

  // ── profile：个人中心与设置 ─────────────────────────────────
  RouteNames.mySpace: 'profile',
  RouteNames.dashboard: 'profile',
  RouteNames.settings: 'profile',
  RouteNames.moreSettings: 'profile',
  RouteNames.accountInfo: 'profile',
  RouteNames.appearance: 'profile',
  RouteNames.themeSelect: 'profile',
  RouteNames.designLanguage: 'profile',
  RouteNames.userInfoManage: 'profile',
  RouteNames.help: 'profile',
  RouteNames.netDiagnosis: 'profile',
  RouteNames.feedback: 'profile',
  RouteNames.redemption: 'profile',
  RouteNames.myEquip: 'profile',
  RouteNames.footMark: 'profile',
  RouteNames.myWords: 'profile',
  RouteNames.newWords: 'profile',
  RouteNames.masteredWords: 'profile',
  RouteNames.notLearnedWords: 'profile',
  RouteNames.personalStereo: 'profile',
  RouteNames.playOrder: 'profile',
  RouteNames.scareCoinHistory: 'profile',
  RouteNames.checkInHistory: 'profile',
  RouteNames.treasureCheckIn: 'profile',
  RouteNames.linkedMe: 'profile',
};
